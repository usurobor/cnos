// Package pkg defines the pure types for cnos package management:
// manifest, lockfile, package index, and their JSON serialization.
//
// This is the Go equivalent of src/ocaml/lib/cn_package.ml — no IO, only
// types + JSON + pure helpers. The types and field names match the
// OCaml definitions so Go and OCaml produce structurally identical
// JSON for the same data.
//
// Discipline: this package imports only encoding/json and fmt.
// No os, no net, no io — file reading lives in internal/restore/,
// mirroring the OCaml split (src/ocaml/lib/ = pure, src/ocaml/cmd/ = IO).
package pkg

import (
	"encoding/json"
	"fmt"
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

// --- Package Index (packages/index.json) ---

// IndexEntry maps a package version to its download URL and expected SHA-256.
type IndexEntry struct {
	URL    string `json:"url"`
	SHA256 string `json:"sha256"`
}

// PackageIndex is the parsed packages/index.json.
// Schema: cn.package-index.v1.
type PackageIndex struct {
	Schema   string                           `json:"schema"`
	Packages map[string]map[string]IndexEntry `json:"packages"`
}

// ParseLockfile parses a lockfile from raw JSON bytes.
func ParseLockfile(data []byte) (*Lockfile, error) {
	var lf Lockfile
	if err := json.Unmarshal(data, &lf); err != nil {
		return nil, fmt.Errorf("parse lockfile: %w", err)
	}
	return &lf, nil
}

// ParsePackageIndex parses a package index from raw JSON bytes.
func ParsePackageIndex(data []byte) (*PackageIndex, error) {
	var idx PackageIndex
	if err := json.Unmarshal(data, &idx); err != nil {
		return nil, fmt.Errorf("parse package index: %w", err)
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

// ValidatePackageManifestData checks that raw cn.package.json bytes
// parse as JSON and declare a name matching expectedName. The caller
// is responsible for reading the file from disk (IO lives in
// internal/restore/, not here).
func ValidatePackageManifestData(data []byte, expectedName string) error {
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

