package cli

import (
	"context"
	"fmt"

	"github.com/usurobor/cnos/src/go/internal/pkgbuild"
)

// BuildCmd implements the "build" command per BUILD-AND-DIST.md:
// validate + package src/packages/ → dist/packages/ as tarballs.
type BuildCmd struct{}

func (c *BuildCmd) Spec() CommandSpec {
	return CommandSpec{
		Name:     "build",
		Summary:  "Build packages from source",
		Source:   SourceKernel,
		Tier:     TierKernel,
		NeedsHub: false, // build operates on repo root (.git), not hub (.cn/)

	}
}

func (c *BuildCmd) Run(ctx context.Context, inv Invocation) error {
	repoRoot, err := pkgbuild.FindRepoRoot()
	if err != nil {
		return fmt.Errorf("build: %w", err)
	}

	mode := "build"
	if len(inv.Args) > 0 {
		switch inv.Args[0] {
		case "--check":
			mode = "check"
		case "clean":
			mode = "clean"
		default:
			return fmt.Errorf("build: unknown argument %q (use --check or clean)", inv.Args[0])
		}
	}

	if mode == "clean" {
		if err := pkgbuild.Clean(repoRoot); err != nil {
			return fmt.Errorf("build clean: %w", err)
		}
		fmt.Fprintf(inv.Stdout, "✓ dist/packages/ cleaned.\n")
		return nil
	}

	packages, err := pkgbuild.DiscoverPackages(repoRoot)
	if err != nil {
		return fmt.Errorf("build: %w", err)
	}
	if len(packages) == 0 {
		fmt.Fprintf(inv.Stdout, "✓ No packages found in src/packages/.\n")
		return nil
	}

	switch mode {
	case "build":
		return c.runBuild(inv, repoRoot, packages)
	case "check":
		return c.runCheck(inv, packages)
	}
	return nil
}

func (c *BuildCmd) runBuild(inv Invocation, repoRoot string, packages []pkgbuild.DiscoveredPackage) error {
	var results []pkgbuild.BuildResult
	anyErr := false

	for _, pkg := range packages {
		result := pkgbuild.BuildOne(repoRoot, pkg)
		results = append(results, result)
		if result.Err != nil {
			fmt.Fprintf(inv.Stderr, "✗ %s@%s: %v\n", result.Name, result.Version, result.Err)
			anyErr = true
		} else {
			fmt.Fprintf(inv.Stdout, "✓ %s@%s → %s (sha256:%s)\n",
				result.Name, result.Version,
				result.Name+"-"+result.Version+".tar.gz",
				result.SHA256[:12]+"…")
		}
	}

	if anyErr {
		return fmt.Errorf("build: some packages failed")
	}

	// Update index + checksums.
	if err := pkgbuild.UpdateIndex(repoRoot, results); err != nil {
		return fmt.Errorf("build: update index: %w", err)
	}
	if err := pkgbuild.UpdateChecksums(repoRoot, results); err != nil {
		return fmt.Errorf("build: update checksums: %w", err)
	}

	fmt.Fprintf(inv.Stdout, "✓ %d package(s) built → dist/packages/\n", len(results))
	return nil
}

func (c *BuildCmd) runCheck(inv Invocation, packages []pkgbuild.DiscoveredPackage) error {
	anyIssue := false
	for _, pkg := range packages {
		result := pkgbuild.CheckOne(pkg)
		if len(result.Issues) > 0 {
			anyIssue = true
			fmt.Fprintf(inv.Stderr, "✗ %s: %d issue(s)\n", result.Name, len(result.Issues))
			for _, iss := range result.Issues {
				fmt.Fprintf(inv.Stderr, "  %s\n", iss)
			}
		} else {
			fmt.Fprintf(inv.Stdout, "✓ %s: valid\n", result.Name)
		}
	}
	if anyIssue {
		fmt.Fprintf(inv.Stderr, "\n⚠ Some packages have issues. Fix source in src/packages/ and rerun.\n")
		return fmt.Errorf("build --check: issues found")
	}
	fmt.Fprintf(inv.Stdout, "✓ All packages valid.\n")
	return nil
}
