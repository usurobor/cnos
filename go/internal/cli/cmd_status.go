package cli

import (
	"context"
	"fmt"
	"os"
	"path/filepath"
	"strings"
)

// StatusCmd implements the "status" command — shows hub info + installed packages.
type StatusCmd struct {
	Version string // cnos version for drift detection
}

func (c *StatusCmd) Spec() CommandSpec {
	return CommandSpec{
		Name:     "status",
		Summary:  "Show hub status",
		Source:   SourceKernel,
		Tier:     TierKernel,
		NeedsHub: true,
	}
}

func (c *StatusCmd) Run(_ context.Context, inv Invocation) error {
	hubName := filepath.Base(inv.HubPath)

	fmt.Fprintf(inv.Stdout, "cn hub: %s\n\n", hubName)
	fmt.Fprintf(inv.Stdout, "hub..................... ✓\n")
	fmt.Fprintf(inv.Stdout, "name.................... ✓ %s\n", hubName)
	fmt.Fprintf(inv.Stdout, "path.................... ✓ %s\n", inv.HubPath)

	// List installed packages with version drift detection.
	// Note: drift detection assumes all installed packages are first-party
	// (version should match the binary version). This matches OCaml behavior
	// in cn_system.ml::run_status. Third-party packages would need their
	// own version authority — not yet supported.
	vendorDir := filepath.Join(inv.HubPath, ".cn", "vendor", "packages")
	entries, err := os.ReadDir(vendorDir)
	if err != nil {
		if os.IsNotExist(err) {
			fmt.Fprintf(inv.Stdout, "\nNo packages installed.\n")
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

		if c.Version != "" && pkgVersion != c.Version {
			hasDrift = true
			fmt.Fprintf(inv.Stdout, "%s................. ✗ %s (expected %s)\n",
				pkgName, pkgVersion, c.Version)
		} else {
			fmt.Fprintf(inv.Stdout, "%s................. ✓ %s\n",
				pkgName, pkgVersion)
		}
	}

	fmt.Fprintln(inv.Stdout)
	if hasDrift {
		fmt.Fprintf(inv.Stdout, "⚠ version_drift version=%s\n", c.Version)
	} else {
		fmt.Fprintf(inv.Stdout, "ok version=%s\n", c.Version)
	}

	return nil
}
