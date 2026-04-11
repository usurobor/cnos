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

	"github.com/usurobor/cnos/go/internal/pkg"
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

