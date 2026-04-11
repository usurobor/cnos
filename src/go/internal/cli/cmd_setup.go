package cli

import (
	"context"

	"github.com/usurobor/cnos/src/go/internal/hubsetup"
)

// SetupCmd implements the "setup" command — makes a hub wake-ready.
//
// Per GO-KERNEL-COMMANDS.md §2.8, setup is listed as needs_hub=false
// (available without a hub) because it is a bootstrap-tier command.
// Operationally it still requires a hub path — hubsetup.Run rejects
// the empty path cleanly so help can list setup before a hub exists
// without hiding the hard requirement.
type SetupCmd struct {
	Version string
}

func (c *SetupCmd) Spec() CommandSpec {
	return CommandSpec{
		Name:     "setup",
		Summary:  "Configure cnos hub",
		Source:   SourceKernel,
		Tier:     TierKernel,
		NeedsHub: false,
	}
}

func (c *SetupCmd) Run(ctx context.Context, inv Invocation) error {
	return hubsetup.Run(ctx, hubsetup.Options{
		HubPath: inv.HubPath,
		Version: c.Version,
		Stdout:  inv.Stdout,
		Stderr:  inv.Stderr,
	})
}
