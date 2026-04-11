package pkg

import (
	"encoding/json"
	"os"
	"path/filepath"
	"testing"
)

func TestIndexLookupHit(t *testing.T) {
	idx := &PackageIndex{
		Schema: "cn.package-index.v1",
		Packages: map[string]map[string]IndexEntry{
			"cnos.core": {
				"3.42.0": {URL: "https://example.com/core.tar.gz", SHA256: "abc123"},
			},
		},
	}
	entry := idx.Lookup("cnos.core", "3.42.0")
	if entry == nil {
		t.Fatal("expected hit, got nil")
	}
	if entry.URL != "https://example.com/core.tar.gz" {
		t.Errorf("url = %q, want %q", entry.URL, "https://example.com/core.tar.gz")
	}
	if entry.SHA256 != "abc123" {
		t.Errorf("sha256 = %q, want %q", entry.SHA256, "abc123")
	}
}

func TestIndexLookupMiss(t *testing.T) {
	idx := &PackageIndex{
		Schema:   "cn.package-index.v1",
		Packages: map[string]map[string]IndexEntry{},
	}
	if entry := idx.Lookup("cnos.core", "9.9.9"); entry != nil {
		t.Errorf("expected nil, got %+v", entry)
	}
}

func TestLockfileRoundTrip(t *testing.T) {
	lf := Lockfile{
		Schema: "cn.lock.v2",
		Packages: []LockedDep{
			{Name: "cnos.core", Version: "3.42.0", SHA256: "deadbeef"},
			{Name: "cnos.eng", Version: "3.42.0", SHA256: "cafef00d"},
		},
	}
	data, err := json.Marshal(lf)
	if err != nil {
		t.Fatalf("marshal: %v", err)
	}
	var got Lockfile
	if err := json.Unmarshal(data, &got); err != nil {
		t.Fatalf("unmarshal: %v", err)
	}
	if got.Schema != lf.Schema {
		t.Errorf("schema = %q, want %q", got.Schema, lf.Schema)
	}
	if len(got.Packages) != 2 {
		t.Fatalf("packages len = %d, want 2", len(got.Packages))
	}
	if got.Packages[0].Name != "cnos.core" {
		t.Errorf("packages[0].name = %q, want %q", got.Packages[0].Name, "cnos.core")
	}
	if got.Packages[1].SHA256 != "cafef00d" {
		t.Errorf("packages[1].sha256 = %q, want %q", got.Packages[1].SHA256, "cafef00d")
	}
}

func TestParsePackageIndex(t *testing.T) {
	// Use the live index from the repo root.
	repoRoot := findRepoRoot(t)
	data, err := os.ReadFile(filepath.Join(repoRoot, "packages", "index.json"))
	if err != nil {
		t.Fatalf("read live index: %v", err)
	}
	idx, err := ParsePackageIndex(data)
	if err != nil {
		t.Fatalf("ParsePackageIndex: %v", err)
	}
	if idx.Schema != "cn.package-index.v1" {
		t.Errorf("schema = %q, want %q", idx.Schema, "cn.package-index.v1")
	}
	// Should have at least cnos.core
	// Find any cnos.core version in the live index rather than
	// hardcoding a specific version (the index is bumped on every release).
	coreVersions, ok := idx.Packages["cnos.core"]
	if !ok || len(coreVersions) == 0 {
		t.Fatal("expected cnos.core in live index with at least one version")
	}
	for _, entry := range coreVersions {
		if entry.SHA256 == "" {
			t.Error("expected non-empty sha256 for cnos.core entry")
		}
		break // just need to verify one entry has a sha256
	}
}

func TestIsFirstParty(t *testing.T) {
	tests := []struct {
		name string
		want bool
	}{
		{"cnos.core", true},
		{"cnos.eng", true},
		{"cnos.pm", true},
		{"cnos.", true}, // bare prefix, matches OCaml semantics (>= 5)
		{"cnos", false},
		{"other.pkg", false},
		{"", false},
		{"c", false},
	}
	for _, tt := range tests {
		if got := IsFirstParty(tt.name); got != tt.want {
			t.Errorf("IsFirstParty(%q) = %v, want %v", tt.name, got, tt.want)
		}
	}
}

func TestValidatePackageManifestData(t *testing.T) {
	t.Run("valid", func(t *testing.T) {
		data := []byte(`{"name": "cnos.core"}`)
		if err := ValidatePackageManifestData(data, "cnos.core"); err != nil {
			t.Errorf("expected nil, got %v", err)
		}
	})
	t.Run("name mismatch", func(t *testing.T) {
		data := []byte(`{"name": "cnos.wrong"}`)
		err := ValidatePackageManifestData(data, "cnos.core")
		if err == nil {
			t.Fatal("expected error for name mismatch")
		}
	})
	t.Run("invalid json", func(t *testing.T) {
		data := []byte(`not json`)
		err := ValidatePackageManifestData(data, "cnos.core")
		if err == nil {
			t.Fatal("expected error for invalid json")
		}
	})
	t.Run("missing name field", func(t *testing.T) {
		data := []byte(`{"version": "1.0.0"}`)
		err := ValidatePackageManifestData(data, "cnos.core")
		if err == nil {
			t.Fatal("expected error for missing name")
		}
	})
}

func TestVendorPath(t *testing.T) {
	got := VendorPath("/home/hub", "cnos.core", "3.42.0")
	want := "/home/hub/.cn/vendor/packages/cnos.core@3.42.0"
	if got != want {
		t.Errorf("VendorPath = %q, want %q", got, want)
	}
}

// --- helpers ---

func findRepoRoot(t *testing.T) string {
	t.Helper()
	// Walk up from the test file's directory to find go.mod, then
	// the repo root is one level above go/.
	dir, err := os.Getwd()
	if err != nil {
		t.Fatalf("getwd: %v", err)
	}
	for {
		if _, err := os.Stat(filepath.Join(dir, "go.mod")); err == nil {
			// dir is go/; repo root is parent
			return filepath.Dir(dir)
		}
		parent := filepath.Dir(dir)
		if parent == dir {
			t.Fatal("could not find repo root (no go.mod found walking up)")
		}
		dir = parent
	}
}

