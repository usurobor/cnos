// Package hubstatus implements the cn status display logic.
//
// Extracted from cli/cmd_status.go per eng/go §2.18 (INVARIANTS.md T-002).
package hubstatus

import (
	"fmt"
	"io"
	"os"
	"path/filepath"
	"strings"
)

// Run displays hub info + installed packages with version drift detection.
func Run(hubPath, version string, stdout io.Writer) error {
	hubName := filepath.Base(hubPath)

	fmt.Fprintf(stdout, "cn hub: %s\n\n", hubName)
	fmt.Fprintf(stdout, "hub..................... ✓\n")
	fmt.Fprintf(stdout, "name.................... ✓ %s\n", hubName)
	fmt.Fprintf(stdout, "path.................... ✓ %s\n", hubPath)

	// List installed packages with version drift detection.
	// Note: drift detection assumes all installed packages are first-party
	// (version should match the binary version). This matches OCaml behavior
	// in cn_system.ml::run_status. Third-party packages would need their
	// own version authority — not yet supported.
	vendorDir := filepath.Join(hubPath, ".cn", "vendor", "packages")
	entries, err := os.ReadDir(vendorDir)
	if err != nil {
		if os.IsNotExist(err) {
			fmt.Fprintf(stdout, "\nNo packages installed.\n")
			return nil
		}
		return fmt.Errorf("status: read vendor dir: %w", err)
	}

	hasDrift := false
	for _, entry := range entries {
		if !entry.IsDir() {
			continue
		}
		name := entry.Name()
		atIdx := strings.LastIndex(name, "@")
		if atIdx < 0 {
			continue
		}
		pkgName := name[:atIdx]
		pkgVersion := name[atIdx+1:]

		if version != "" && pkgVersion != version {
			hasDrift = true
			fmt.Fprintf(stdout, "%s................. ✗ %s (expected %s)\n",
				pkgName, pkgVersion, version)
		} else {
			fmt.Fprintf(stdout, "%s................. ✓ %s\n",
				pkgName, pkgVersion)
		}
	}

	fmt.Fprintln(stdout)
	if hasDrift {
		fmt.Fprintf(stdout, "⚠ version_drift version=%s\n", version)
	} else {
		fmt.Fprintf(stdout, "ok version=%s\n", version)
	}

	return nil
}
