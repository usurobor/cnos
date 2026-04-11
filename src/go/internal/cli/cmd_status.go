package cli

import (
	"context"

	"github.com/usurobor/cnos/src/go/internal/hubstatus"
)

// StatusCmd implements the "status" command — shows hub info + installed packages.
type StatusCmd struct {
	Version string
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
	return hubstatus.Run(inv.HubPath, c.Version, inv.Stdout)
}
