// Package pkg defines the pure types for cnos package management:
// manifest, lockfile, package index, and their JSON serialization.
//
// This is the Go equivalent of src/lib/cn_package.ml — no IO, only
// types + JSON + pure helpers. The types and field names match the
// OCaml definitions so Go and OCaml produce structurally identical
// JSON for the same data.
package pkg

import (
	"encoding/json"
	"fmt"
	"os"
)

// --- Manifest (deps.json) ---

// ManifestDep is one entry in the operator's desired package list.
type ManifestDep struct {
	Name    string `json:"name"`
	Version string `json:"version"`
}

// Manifest is the parsed .cn/deps.json.
type Manifest struct {
	Schema   string        `json:"schema"`
	Profile  string        `json:"profile"`
	Packages []ManifestDep `json:"packages"`
}

// --- Lockfile (deps.lock.json) ---

// LockedDep pins a package to a specific version + tarball SHA-256.
type LockedDep struct {
	Name    string `json:"name"`
	Version string `json:"version"`
	SHA256  string `json:"sha256"`
}

// Lockfile is the parsed .cn/deps.lock.json.
type Lockfile struct {
	Schema   string      `json:"schema"`
	Packages []LockedDep `json:"packages"`
}

// ReadLockfile reads and parses a lockfile from disk.
func ReadLockfile(path string) (*Lockfile, error) {
	data, err := os.ReadFile(path)
	if err != nil {
		return nil, fmt.Errorf("read lockfile %s: %w", path, err)
	}
	var lf Lockfile
	if err := json.Unmarshal(data, &lf); err != nil {
		return nil, fmt.Errorf("parse lockfile %s: %w", path, err)
	}
	return &lf, nil
}

// --- Package Index (packages/index.json) ---

// IndexEntry maps a package version to its download URL and expected SHA-256.
type IndexEntry struct {
	URL    string `json:"url"`
	SHA256 string `json:"sha256"`
}

// PackageIndex is the parsed packages/index.json.
// Schema: cn.package-index.v1.
type PackageIndex struct {
	Schema   string                                `json:"schema"`
	Packages map[string]map[string]IndexEntry `json:"packages"`
}

// ReadPackageIndex reads and parses a package index from disk.
func ReadPackageIndex(path string) (*PackageIndex, error) {
	data, err := os.ReadFile(path)
	if err != nil {
		return nil, fmt.Errorf("read package index %s: %w", path, err)
	}
	var idx PackageIndex
	if err := json.Unmarshal(data, &idx); err != nil {
		return nil, fmt.Errorf("parse package index %s: %w", path, err)
	}
	return &idx, nil
}

// Lookup finds an index entry by name and version.
// Returns nil if the pair is not in the index.
func (idx *PackageIndex) Lookup(name, version string) *IndexEntry {
	versions, ok := idx.Packages[name]
	if !ok {
		return nil
	}
	entry, ok := versions[version]
	if !ok {
		return nil
	}
	return &entry
}

// --- Helpers ---

// IsFirstParty returns true iff name starts with "cnos.".
func IsFirstParty(name string) bool {
	return len(name) >= 5 && name[:5] == "cnos."
}

// --- Package manifest validation ---

// PackageManifest is the minimal shape of cn.package.json that we
// validate after extraction. Only the name field is checked.
type PackageManifest struct {
	Name string `json:"name"`
}

// ValidatePackageManifest checks that cn.package.json exists in
// pkgDir, parses as JSON, and declares a name matching expectedName.
func ValidatePackageManifest(pkgDir, expectedName string) error {
	path := pkgDir + "/cn.package.json"
	data, err := os.ReadFile(path)
	if err != nil {
		return fmt.Errorf("missing cn.package.json: %w", err)
	}
	var m PackageManifest
	if err := json.Unmarshal(data, &m); err != nil {
		return fmt.Errorf("invalid cn.package.json: %w", err)
	}
	if m.Name == "" {
		return fmt.Errorf("cn.package.json missing 'name' field")
	}
	if m.Name != expectedName {
		return fmt.Errorf("cn.package.json name %q does not match expected %q", m.Name, expectedName)
	}
	return nil
}

// VendorPath returns the install path for a package in the vendor tree.
// Format: <hubPath>/.cn/vendor/packages/<name>@<version>/
func VendorPath(hubPath, name, version string) string {
	return hubPath + "/.cn/vendor/packages/" + name + "@" + version
}

// TmpTarballPath returns the temp download path for a package tarball.
func TmpTarballPath(hubPath, name, version string) string {
	return hubPath + "/.cn/tmp/" + name + "-" + version + ".tar.gz"
}

