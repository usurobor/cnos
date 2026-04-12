package restore

import (
	"archive/tar"
	"compress/gzip"
	"context"
	"crypto/sha256"
	"encoding/hex"
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"os"
	"path/filepath"
	"strings"
	"testing"

	"github.com/usurobor/cnos/src/go/internal/pkg"
	"github.com/usurobor/cnos/src/go/internal/pkgbuild"
)

// makeTarGz creates a .tar.gz in memory containing the given files
// (map of relative-path → content). Returns the bytes + the SHA-256 hex.
func makeTarGz(t *testing.T, files map[string]string) ([]byte, string) {
	t.Helper()
	tmpFile := filepath.Join(t.TempDir(), "test.tar.gz")
	f, err := os.Create(tmpFile)
	if err != nil {
		t.Fatal(err)
	}
	gw := gzip.NewWriter(f)
	tw := tar.NewWriter(gw)
	for name, content := range files {
		hdr := &tar.Header{
			Name: name,
			Mode: 0644,
			Size: int64(len(content)),
		}
		if err := tw.WriteHeader(hdr); err != nil {
			t.Fatal(err)
		}
		if _, err := tw.Write([]byte(content)); err != nil {
			t.Fatal(err)
		}
	}
	tw.Close()
	gw.Close()
	f.Close()

	data, err := os.ReadFile(tmpFile)
	if err != nil {
		t.Fatal(err)
	}
	h := sha256.Sum256(data)
	return data, hex.EncodeToString(h[:])
}

func TestRestoreEndToEnd(t *testing.T) {
	manifest := `{"name": "cnos.core", "version": "3.42.0"}`
	tarData, tarSHA := makeTarGz(t, map[string]string{
		"cn.package.json": manifest,
		"doctrine/SOUL.md": "# Soul\n",
	})

	// Serve the tarball via httptest.
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("Content-Type", "application/gzip")
		w.Write(tarData)
	}))
	defer srv.Close()

	// Create a hub + index + lockfile.
	hub := t.TempDir()
	indexPath := filepath.Join(hub, "index.json")

	idx := pkg.PackageIndex{
		Schema: "cn.package-index.v1",
		Packages: map[string]map[string]pkg.IndexEntry{
			"cnos.core": {
				"3.42.0": {URL: srv.URL + "/cnos.core-3.42.0.tar.gz", SHA256: tarSHA},
			},
		},
	}
	writeJSON(t, indexPath, idx)

	lockPath := filepath.Join(hub, ".cn", "deps.lock.json")
	os.MkdirAll(filepath.Dir(lockPath), 0755)
	lf := pkg.Lockfile{
		Schema: "cn.lock.v2",
		Packages: []pkg.LockedDep{
			{Name: "cnos.core", Version: "3.42.0", SHA256: tarSHA},
		},
	}
	writeJSON(t, lockPath, lf)

	// Run restore.
	results, err := Restore(context.Background(), hub, indexPath)
	if err != nil {
		t.Fatalf("Restore: %v", err)
	}
	if HasErrors(results) {
		for _, r := range Errors(results) {
			t.Errorf("  %s@%s: %v", r.Name, r.Version, r.Err)
		}
		t.Fatal("restore had errors")
	}

	// Verify package was installed.
	pkgDir := pkg.VendorPath(hub, "cnos.core", "3.42.0")
	if _, err := os.Stat(filepath.Join(pkgDir, "cn.package.json")); err != nil {
		t.Errorf("cn.package.json not found in vendor: %v", err)
	}
	if _, err := os.Stat(filepath.Join(pkgDir, "doctrine", "SOUL.md")); err != nil {
		t.Errorf("doctrine/SOUL.md not found in vendor: %v", err)
	}
}

func TestRestoreSHA256Mismatch(t *testing.T) {
	tarData, _ := makeTarGz(t, map[string]string{
		"cn.package.json": `{"name": "cnos.core"}`,
	})

	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.Write(tarData)
	}))
	defer srv.Close()

	hub := t.TempDir()
	indexPath := filepath.Join(hub, "index.json")

	idx := pkg.PackageIndex{
		Schema: "cn.package-index.v1",
		Packages: map[string]map[string]pkg.IndexEntry{
			"cnos.core": {
				"3.42.0": {URL: srv.URL + "/core.tar.gz", SHA256: "wrong-sha256"},
			},
		},
	}
	writeJSON(t, indexPath, idx)

	lockPath := filepath.Join(hub, ".cn", "deps.lock.json")
	os.MkdirAll(filepath.Dir(lockPath), 0755)
	lf := pkg.Lockfile{
		Schema: "cn.lock.v2",
		Packages: []pkg.LockedDep{
			{Name: "cnos.core", Version: "3.42.0", SHA256: "wrong-sha256"},
		},
	}
	writeJSON(t, lockPath, lf)

	results, err := Restore(context.Background(), hub, indexPath)
	if err != nil {
		t.Fatalf("Restore: %v", err)
	}
	if !HasErrors(results) {
		t.Fatal("expected SHA-256 mismatch error")
	}
	errMsg := results[0].Err.Error()
	if !strings.Contains(errMsg, "sha256 mismatch") {
		t.Errorf("expected 'sha256 mismatch' in error, got: %s", errMsg)
	}

	// Verify package was NOT installed.
	pkgDir := pkg.VendorPath(hub, "cnos.core", "3.42.0")
	if _, err := os.Stat(pkgDir); !os.IsNotExist(err) {
		t.Error("vendor dir should not exist after sha256 mismatch")
	}
}

func TestRestoreAlreadyInstalled(t *testing.T) {
	hub := t.TempDir()
	indexPath := filepath.Join(hub, "index.json")

	// Create an empty index (won't be needed — package already installed).
	idx := pkg.PackageIndex{Schema: "cn.package-index.v1", Packages: map[string]map[string]pkg.IndexEntry{}}
	writeJSON(t, indexPath, idx)

	// Pre-install the package.
	pkgDir := pkg.VendorPath(hub, "cnos.core", "3.42.0")
	os.MkdirAll(pkgDir, 0755)
	writeJSON(t, filepath.Join(pkgDir, "cn.package.json"), map[string]any{"name": "cnos.core"})

	lockPath := filepath.Join(hub, ".cn", "deps.lock.json")
	os.MkdirAll(filepath.Dir(lockPath), 0755)
	lf := pkg.Lockfile{
		Schema: "cn.lock.v2",
		Packages: []pkg.LockedDep{
			{Name: "cnos.core", Version: "3.42.0", SHA256: "whatever"},
		},
	}
	writeJSON(t, lockPath, lf)

	results, err := Restore(context.Background(), hub, indexPath)
	if err != nil {
		t.Fatalf("Restore: %v", err)
	}
	if HasErrors(results) {
		t.Fatal("expected no errors for already-installed package")
	}
}

func TestRestoreNoLockfile(t *testing.T) {
	hub := t.TempDir()
	results, err := Restore(context.Background(), hub, "/nonexistent/index.json")
	if err != nil {
		t.Fatalf("expected nil error for missing lockfile, got: %v", err)
	}
	if results != nil {
		t.Errorf("expected nil results for missing lockfile, got: %v", results)
	}
}

func TestRestoreNotInIndex(t *testing.T) {
	hub := t.TempDir()
	indexPath := filepath.Join(hub, "index.json")

	// Empty index.
	idx := pkg.PackageIndex{Schema: "cn.package-index.v1", Packages: map[string]map[string]pkg.IndexEntry{}}
	writeJSON(t, indexPath, idx)

	lockPath := filepath.Join(hub, ".cn", "deps.lock.json")
	os.MkdirAll(filepath.Dir(lockPath), 0755)
	lf := pkg.Lockfile{
		Schema: "cn.lock.v2",
		Packages: []pkg.LockedDep{
			{Name: "cnos.core", Version: "9.9.9", SHA256: "abc"},
		},
	}
	writeJSON(t, lockPath, lf)

	results, err := Restore(context.Background(), hub, indexPath)
	if err != nil {
		t.Fatalf("Restore: %v", err)
	}
	if !HasErrors(results) {
		t.Fatal("expected error for package not in index")
	}
	if !strings.Contains(results[0].Err.Error(), "not in index") {
		t.Errorf("expected 'not in index' error, got: %v", results[0].Err)
	}
}

func TestFileSHA256(t *testing.T) {
	tmp := filepath.Join(t.TempDir(), "test.txt")
	os.WriteFile(tmp, []byte("hello world\n"), 0644)

	got, err := fileSHA256(tmp)
	if err != nil {
		t.Fatalf("fileSHA256: %v", err)
	}

	h := sha256.Sum256([]byte("hello world\n"))
	want := hex.EncodeToString(h[:])
	if got != want {
		t.Errorf("sha256 = %s, want %s", got, want)
	}
}

// TestRestoreLocalFile verifies that restore works with local file paths
// (relative URLs in the index, resolved against the index directory).
func TestRestoreLocalFile(t *testing.T) {
	// Build a test tarball manually and place it in a "dist" directory.
	manifest := `{"name": "test.local", "version": "1.0.0"}`
	tarData, tarSHA := makeTarGz(t, map[string]string{
		"cn.package.json": manifest,
		"skills/test/SKILL.md": "# Test\n",
	})

	distDir := filepath.Join(t.TempDir(), "dist", "packages")
	os.MkdirAll(distDir, 0755)
	tarballName := "test.local-1.0.0.tar.gz"
	os.WriteFile(filepath.Join(distDir, tarballName), tarData, 0644)

	// Write index with relative URL (what cn build produces).
	indexPath := filepath.Join(distDir, "index.json")
	idx := pkg.PackageIndex{
		Schema: "cn.package-index.v1",
		Packages: map[string]map[string]pkg.IndexEntry{
			"test.local": {
				"1.0.0": {URL: tarballName, SHA256: tarSHA},
			},
		},
	}
	writeJSON(t, indexPath, idx)

	// Create hub with lockfile.
	hub := t.TempDir()
	lockPath := filepath.Join(hub, ".cn", "deps.lock.json")
	os.MkdirAll(filepath.Dir(lockPath), 0755)
	lf := pkg.Lockfile{
		Schema: "cn.lock.v2",
		Packages: []pkg.LockedDep{
			{Name: "test.local", Version: "1.0.0", SHA256: tarSHA},
		},
	}
	writeJSON(t, lockPath, lf)

	// Restore using local index.
	results, err := Restore(context.Background(), hub, indexPath)
	if err != nil {
		t.Fatalf("Restore: %v", err)
	}
	if HasErrors(results) {
		for _, r := range Errors(results) {
			t.Errorf("  %s@%s: %v", r.Name, r.Version, r.Err)
		}
		t.Fatal("local restore had errors")
	}

	// Verify installed.
	pkgDir := pkg.VendorPath(hub, "test.local", "1.0.0")
	if _, err := os.Stat(filepath.Join(pkgDir, "cn.package.json")); err != nil {
		t.Errorf("cn.package.json not found: %v", err)
	}
	if _, err := os.Stat(filepath.Join(pkgDir, "skills", "test", "SKILL.md")); err != nil {
		t.Errorf("skills/test/SKILL.md not found: %v", err)
	}
}

// TestBuildRestoreRoundTrip proves the full pipeline:
// src/packages/ → cn build → dist/packages/ → cn deps restore → .cn/vendor/packages/
// This is the primary test for issue #227.
func TestBuildRestoreRoundTrip(t *testing.T) {
	// 1. Set up a mock repo with packages in src/packages/.
	repoRoot := t.TempDir()
	setupTestPackages(t, repoRoot)

	// 2. Build: discover + build all packages.
	packages, err := pkgbuild.DiscoverPackages(repoRoot)
	if err != nil {
		t.Fatalf("discover: %v", err)
	}
	if len(packages) != 2 {
		t.Fatalf("expected 2 packages, got %d", len(packages))
	}

	var results []pkgbuild.BuildResult
	for _, p := range packages {
		r := pkgbuild.BuildOne(repoRoot, p)
		if r.Err != nil {
			t.Fatalf("build %s: %v", r.Name, r.Err)
		}
		results = append(results, r)
	}

	// 3. Update index + checksums.
	if err := pkgbuild.UpdateIndex(repoRoot, results); err != nil {
		t.Fatalf("update index: %v", err)
	}
	if err := pkgbuild.UpdateChecksums(repoRoot, results); err != nil {
		t.Fatalf("update checksums: %v", err)
	}

	// 4. Generate lockfile in a hub.
	hub := t.TempDir()
	lockPath := filepath.Join(hub, ".cn", "deps.lock.json")
	if err := pkgbuild.GenerateLockfile(lockPath, results); err != nil {
		t.Fatalf("generate lockfile: %v", err)
	}

	// 5. Restore from local dist.
	indexPath := filepath.Join(repoRoot, "dist", "packages", "index.json")
	restoreResults, err := Restore(context.Background(), hub, indexPath)
	if err != nil {
		t.Fatalf("restore: %v", err)
	}
	if HasErrors(restoreResults) {
		for _, r := range Errors(restoreResults) {
			t.Errorf("  %s@%s: %v", r.Name, r.Version, r.Err)
		}
		t.Fatal("restore had errors")
	}

	// 6. Verify round-trip for each package.
	for _, br := range results {
		pkgDir := pkg.VendorPath(hub, br.Name, br.Version)

		// cn.package.json must exist and parse.
		manifestPath := filepath.Join(pkgDir, "cn.package.json")
		data, err := os.ReadFile(manifestPath)
		if err != nil {
			t.Errorf("%s: cn.package.json not found: %v", br.Name, err)
			continue
		}
		if err := pkg.ValidatePackageManifestData(data, br.Name); err != nil {
			t.Errorf("%s: manifest validation failed: %v", br.Name, err)
		}
	}

	// 7. Verify specific content survived the round-trip.
	alphaSkill := filepath.Join(
		pkg.VendorPath(hub, "alpha.pkg", "1.0.0"),
		"skills", "alpha-skill", "SKILL.md")
	if _, err := os.Stat(alphaSkill); err != nil {
		t.Errorf("alpha skill not found after round-trip: %v", err)
	}

	betaDoctrine := filepath.Join(
		pkg.VendorPath(hub, "beta.pkg", "0.5.0"),
		"doctrine", "CORE.md")
	if _, err := os.Stat(betaDoctrine); err != nil {
		t.Errorf("beta doctrine not found after round-trip: %v", err)
	}

	// 8. Verify SHA-256: compute hash of installed tarball and compare with build result.
	for _, br := range results {
		tarballPath := filepath.Join(repoRoot, "dist", "packages",
			br.Name+"-"+br.Version+".tar.gz")
		actual, err := fileSHA256(tarballPath)
		if err != nil {
			t.Errorf("%s: compute tarball sha256: %v", br.Name, err)
			continue
		}
		if actual != br.SHA256 {
			t.Errorf("%s: tarball sha256 mismatch: build=%s, file=%s", br.Name, br.SHA256, actual)
		}
	}
}

// setupTestPackages creates two test packages under src/packages/.
func setupTestPackages(t *testing.T, repoRoot string) {
	t.Helper()

	// Package 1: alpha.pkg with skills
	alphaDir := filepath.Join(repoRoot, "src", "packages", "alpha.pkg")
	alphaSkillDir := filepath.Join(alphaDir, "skills", "alpha-skill")
	os.MkdirAll(alphaSkillDir, 0755)
	os.WriteFile(filepath.Join(alphaSkillDir, "SKILL.md"), []byte("# Alpha Skill\n"), 0644)
	writeJSON(t, filepath.Join(alphaDir, "cn.package.json"),
		map[string]string{"name": "alpha.pkg", "version": "1.0.0"})

	// Package 2: beta.pkg with doctrine
	betaDir := filepath.Join(repoRoot, "src", "packages", "beta.pkg")
	betaDocDir := filepath.Join(betaDir, "doctrine")
	os.MkdirAll(betaDocDir, 0755)
	os.WriteFile(filepath.Join(betaDocDir, "CORE.md"), []byte("# Core Doctrine\n"), 0644)
	writeJSON(t, filepath.Join(betaDir, "cn.package.json"),
		map[string]string{"name": "beta.pkg", "version": "0.5.0"})
}

// --- helpers ---

func writeJSON(t *testing.T, path string, v any) {
	t.Helper()
	data, err := json.MarshalIndent(v, "", "  ")
	if err != nil {
		t.Fatal(err)
	}
	os.MkdirAll(filepath.Dir(path), 0755)
	if err := os.WriteFile(path, data, 0644); err != nil {
		t.Fatal(err)
	}
}

