package cli

import (
	"context"
	"fmt"
	"os"
	"path/filepath"

	"github.com/usurobor/cnos/go/internal/restore"
)

// DepsCmd implements the "deps" command with subcommands:
//   - deps restore — install packages from lockfile
type DepsCmd struct{}

func (c *DepsCmd) Spec() CommandSpec {
	return CommandSpec{
		Name:     "deps",
		Summary:  "Manage package dependencies",
		Source:   SourceKernel,
		Tier:     TierKernel,
		NeedsHub: true,
	}
}

func (c *DepsCmd) Run(ctx context.Context, inv Invocation) error {
	if len(inv.Args) == 0 {
		fmt.Fprintf(inv.Stderr, "✗ deps: subcommand required\n\n")
		fmt.Fprintf(inv.Stderr, "Usage: cn deps <subcommand>\n\n")
		fmt.Fprintf(inv.Stderr, "Subcommands:\n")
		fmt.Fprintf(inv.Stderr, "  restore   Install packages from lockfile\n")
		return fmt.Errorf("deps: subcommand required")
	}

	switch inv.Args[0] {
	case "restore":
		return c.runRestore(ctx, inv)
	default:
		return fmt.Errorf("deps: unknown subcommand %q", inv.Args[0])
	}
}

func (c *DepsCmd) runRestore(ctx context.Context, inv Invocation) error {
	indexPath := FindIndexPath(inv.HubPath)

	results, err := restore.Restore(ctx, inv.HubPath, indexPath)
	if err != nil {
		return fmt.Errorf("deps restore: %w", err)
	}

	if results == nil {
		fmt.Fprintf(inv.Stdout, "✓ No packages to restore (no lockfile or empty lockfile)\n")
		return nil
	}

	errs := restore.Errors(results)
	ok := len(results) - len(errs)

	if len(errs) == 0 {
		fmt.Fprintf(inv.Stdout, "✓ Restored %d package(s)\n", ok)
		return nil
	}

	for _, r := range errs {
		fmt.Fprintf(inv.Stderr, "✗ %s@%s: %v\n", r.Name, r.Version, r.Err)
	}
	fmt.Fprintf(inv.Stderr, "\n%d restored, %d failed\n", ok, len(errs))
	return fmt.Errorf("deps restore: %d package(s) failed", len(errs))
}

// FindIndexPath walks up from hubPath looking for packages/index.json.
// Used by deps restore to locate the package index in the repo tree.
func FindIndexPath(hubPath string) string {
	dir := hubPath
	for {
		candidate := filepath.Join(dir, "packages", "index.json")
		if _, err := os.Stat(candidate); err == nil {
			return candidate
		}
		parent := filepath.Dir(dir)
		if parent == dir {
			return filepath.Join(hubPath, "packages", "index.json")
		}
		dir = parent
	}
}
