package cli

import (
	"context"

	"github.com/usurobor/cnos/src/go/internal/hubinit"
)

// InitCmd implements the "init" command — creates a new hub.
type InitCmd struct{}

func (c *InitCmd) Spec() CommandSpec {
	return CommandSpec{
		Name:     "init",
		Summary:  "Initialize a new hub",
		Source:   SourceKernel,
		Tier:     TierKernel,
		NeedsHub: false,
	}
}

func (c *InitCmd) Run(ctx context.Context, inv Invocation) error {
	var hubName string
	if len(inv.Args) > 0 {
		hubName = inv.Args[0]
	}
	// If no name given, hubinit.Run derives it from cwd.
	return hubinit.Run(ctx, hubName, inv.Stdout, inv.Stderr)
}
