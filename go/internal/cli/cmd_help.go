package cli

import (
	"context"
	"fmt"
)

// HelpCmd implements the "help" command.
// It lists all available commands with their summaries.
type HelpCmd struct {
	Registry *Registry
}

func (c *HelpCmd) Spec() CommandSpec {
	return CommandSpec{
		Name:     "help",
		Summary:  "Show available commands",
		Source:   SourceKernel,
		Tier:     TierKernel,
		NeedsHub: false, // help is always available
	}
}

func (c *HelpCmd) Run(_ context.Context, inv Invocation) error {
	hasHub := inv.HubPath != ""
	cmds := c.Registry.Available(hasHub)

	fmt.Fprintf(inv.Stdout, "cn — cnos kernel\n\n")
	fmt.Fprintf(inv.Stdout, "Usage: cn <command> [args...]\n\n")
	fmt.Fprintf(inv.Stdout, "Commands:\n")
	for _, cmd := range cmds {
		spec := cmd.Spec()
		fmt.Fprintf(inv.Stdout, "  %-12s %s\n", spec.Name, spec.Summary)
	}

	if !hasHub {
		fmt.Fprintf(inv.Stdout, "\n⚠ No hub found — commands requiring a hub are hidden.\n")
		fmt.Fprintf(inv.Stdout, "  Run 'cn init' to create a hub, or cd into an existing one.\n")
	}

	return nil
}
