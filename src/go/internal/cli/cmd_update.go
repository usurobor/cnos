package cli

import (
	"context"
	"fmt"

	"github.com/usurobor/cnos/src/go/internal/binupdate"
)

// UpdateCmd implements the "update" command — checks GitHub Releases
// and replaces the running binary when a newer version is available.
// Uses "--check" to report without downloading.
type UpdateCmd struct {
	Version string
	Commit  string
}

func (c *UpdateCmd) Spec() CommandSpec {
	return CommandSpec{
		Name:     "update",
		Summary:  "Update cnos binary",
		Source:   SourceKernel,
		Tier:     TierKernel,
		NeedsHub: false,
	}
}

func (c *UpdateCmd) Run(ctx context.Context, inv Invocation) error {
	opts := binupdate.Options{
		Version: c.Version,
		Commit:  c.Commit,
		Stdout:  inv.Stdout,
		Stderr:  inv.Stderr,
	}

	for _, arg := range inv.Args {
		switch arg {
		case "--check":
			opts.CheckOnly = true
		default:
			return fmt.Errorf("update: unknown argument %q (use --check)", arg)
		}
	}

	return binupdate.Run(ctx, opts)
}
