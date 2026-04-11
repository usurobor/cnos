package pkgbuild

import (
	"encoding/json"
	"os"
	"path/filepath"
	"strings"
	"testing"
)

func TestBuildOneProducesTarball(t *testing.T) {
	repoRoot := t.TempDir()
	setupTestRepo(t, repoRoot)

	packages, err := DiscoverPackages(repoRoot)
	if err != nil {
		t.Fatalf("discover: %v", err)
	}
	if len(packages) != 1 {
		t.Fatalf("expected 1 package, got %d", len(packages))
	}

	result := BuildOne(repoRoot, packages[0])
	if result.Err != nil {
		t.Fatalf("build: %v", result.Err)
	}
	if result.SHA256 == "" {
		t.Error("expected non-empty SHA256")
	}

	tarball := filepath.Join(repoRoot, "dist", "packages", "test.pkg-1.0.0.tar.gz")
	if _, err := os.Stat(tarball); err != nil {
		t.Errorf("expected tarball at %s", tarball)
	}
}

func TestBuildOneUpdateIndex(t *testing.T) {
	repoRoot := t.TempDir()
	setupTestRepo(t, repoRoot)

	packages, _ := DiscoverPackages(repoRoot)
	result := BuildOne(repoRoot, packages[0])

	if err := UpdateIndex(repoRoot, []BuildResult{result}); err != nil {
		t.Fatalf("update index: %v", err)
	}

	indexPath := filepath.Join(repoRoot, "dist", "packages", "index.json")
	data, err := os.ReadFile(indexPath)
	if err != nil {
		t.Fatalf("read index: %v", err)
	}

	if !strings.Contains(string(data), "test.pkg") {
		t.Error("expected test.pkg in index")
	}
	if !strings.Contains(string(data), "1.0.0") {
		t.Error("expected version 1.0.0 in index")
	}
	if !strings.Contains(string(data), result.SHA256) {
		t.Error("expected SHA256 in index")
	}
}

func TestCheckOneValid(t *testing.T) {
	repoRoot := t.TempDir()
	setupTestRepo(t, repoRoot)

	packages, _ := DiscoverPackages(repoRoot)
	result := CheckOne(packages[0])

	if len(result.Issues) > 0 {
		t.Errorf("expected 0 issues for valid package, got %v", result.Issues)
	}
}

func TestCheckOneMissingContent(t *testing.T) {
	repoRoot := t.TempDir()
	pkgDir := filepath.Join(repoRoot, "src", "packages", "empty.pkg")
	os.MkdirAll(pkgDir, 0755)
	writeManifest(t, pkgDir, "empty.pkg", "1.0.0")

	packages, _ := DiscoverPackages(repoRoot)
	result := CheckOne(packages[0])

	if len(result.Issues) == 0 {
		t.Fatal("expected issues for package with no content")
	}

	found := false
	for _, issue := range result.Issues {
		if strings.Contains(issue, "no content class") {
			found = true
		}
	}
	if !found {
		t.Errorf("expected 'no content class' issue, got %v", result.Issues)
	}
}

func TestClean(t *testing.T) {
	repoRoot := t.TempDir()
	setupTestRepo(t, repoRoot)

	packages, _ := DiscoverPackages(repoRoot)
	BuildOne(repoRoot, packages[0])

	distDir := filepath.Join(repoRoot, "dist", "packages")
	if _, err := os.Stat(distDir); err != nil {
		t.Fatal("dist/packages should exist after build")
	}

	if err := Clean(repoRoot); err != nil {
		t.Fatalf("clean: %v", err)
	}

	if _, err := os.Stat(distDir); !os.IsNotExist(err) {
		t.Error("dist/packages should be removed after clean")
	}
}

func TestDiscoverPackagesEmpty(t *testing.T) {
	repoRoot := t.TempDir()
	os.MkdirAll(filepath.Join(repoRoot, "src", "packages"), 0755)

	packages, err := DiscoverPackages(repoRoot)
	if err != nil {
		t.Fatalf("discover: %v", err)
	}
	if len(packages) != 0 {
		t.Errorf("expected 0 packages, got %d", len(packages))
	}
}

func TestUpdateChecksums(t *testing.T) {
	repoRoot := t.TempDir()
	results := []BuildResult{
		{Name: "a.pkg", Version: "1.0.0", SHA256: "aaa111"},
		{Name: "b.pkg", Version: "2.0.0", SHA256: "bbb222"},
	}

	if err := UpdateChecksums(repoRoot, results); err != nil {
		t.Fatalf("update checksums: %v", err)
	}

	data, err := os.ReadFile(filepath.Join(repoRoot, "dist", "packages", "checksums.txt"))
	if err != nil {
		t.Fatalf("read checksums: %v", err)
	}

	content := string(data)
	if !strings.Contains(content, "aaa111  a.pkg-1.0.0.tar.gz") {
		t.Error("expected a.pkg checksum entry")
	}
	if !strings.Contains(content, "bbb222  b.pkg-2.0.0.tar.gz") {
		t.Error("expected b.pkg checksum entry")
	}
}

// --- helpers ---

func setupTestRepo(t *testing.T, repoRoot string) {
	t.Helper()
	pkgDir := filepath.Join(repoRoot, "src", "packages", "test.pkg")
	skillDir := filepath.Join(pkgDir, "skills", "test-skill")
	os.MkdirAll(skillDir, 0755)
	os.WriteFile(filepath.Join(skillDir, "SKILL.md"), []byte("# Test Skill\n"), 0644)
	writeManifest(t, pkgDir, "test.pkg", "1.0.0")
}

func writeManifest(t *testing.T, pkgDir, name, version string) {
	t.Helper()
	manifest := PackageManifest{Name: name, Version: version}
	data, _ := json.MarshalIndent(manifest, "", "  ")
	os.WriteFile(filepath.Join(pkgDir, "cn.package.json"), data, 0644)
}
