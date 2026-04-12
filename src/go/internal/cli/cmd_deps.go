package cli

import (
	"context"
	"fmt"
	"path/filepath"

	"github.com/usurobor/cnos/src/go/internal/pkgbuild"
	"github.com/usurobor/cnos/src/go/internal/restore"
)

// DepsCmd implements the "deps" command with subcommands:
//   - deps restore — install packages from lockfile
//   - deps lock    — generate lockfile from package index
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
		fmt.Fprintf(inv.Stderr, "  lock      Generate lockfile from package index\n")
		return fmt.Errorf("deps: subcommand required")
	}

	switch inv.Args[0] {
	case "restore":
		return c.runRestore(ctx, inv)
	case "lock":
		return c.runLock(ctx, inv)
	default:
		return fmt.Errorf("deps: unknown subcommand %q", inv.Args[0])
	}
}

func (c *DepsCmd) runRestore(ctx context.Context, inv Invocation) error {
	indexPath := restore.FindIndexPath(inv.HubPath)

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

func (c *DepsCmd) runLock(ctx context.Context, inv Invocation) error {
	// Find the package index. cn deps lock reads the index produced by
	// cn build and generates a lockfile for all packages in it.
	indexPath := restore.FindIndexPath(inv.HubPath)

	idx, err := restore.ReadPackageIndex(indexPath)
	if err != nil {
		return fmt.Errorf("deps lock: read index: %w", err)
	}

	// Convert index entries to build results for lockfile generation.
	var results []pkgbuild.BuildResult
	for name, versions := range idx.Packages {
		for version, entry := range versions {
			results = append(results, pkgbuild.BuildResult{
				Name:    name,
				Version: version,
				SHA256:  entry.SHA256,
			})
		}
	}

	lockPath := filepath.Join(inv.HubPath, ".cn", "deps.lock.json")
	if err := pkgbuild.GenerateLockfile(lockPath, results); err != nil {
		return fmt.Errorf("deps lock: %w", err)
	}

	fmt.Fprintf(inv.Stdout, "✓ Lockfile written: %s (%d package(s))\n", lockPath, len(results))
	return nil
}
