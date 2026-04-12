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

	// Group commands by source for clear tier attribution.
	var kernelCmds, repoLocalCmds, packageCmds []Command
	for _, cmd := range cmds {
		switch cmd.Spec().Source {
		case SourceKernel:
			kernelCmds = append(kernelCmds, cmd)
		case SourceRepoLocal:
			repoLocalCmds = append(repoLocalCmds, cmd)
		case SourcePackage:
			packageCmds = append(packageCmds, cmd)
		}
	}

	if len(kernelCmds) > 0 {
		fmt.Fprintf(inv.Stdout, "Kernel commands:\n")
		for _, cmd := range kernelCmds {
			spec := cmd.Spec()
			fmt.Fprintf(inv.Stdout, "  %-12s %s\n", spec.Name, spec.Summary)
		}
	}

	if len(repoLocalCmds) > 0 {
		fmt.Fprintf(inv.Stdout, "\nRepo-local commands:\n")
		for _, cmd := range repoLocalCmds {
			spec := cmd.Spec()
			fmt.Fprintf(inv.Stdout, "  %-12s %s\n", spec.Name, spec.Summary)
		}
	}

	if len(packageCmds) > 0 {
		fmt.Fprintf(inv.Stdout, "\nPackage commands:\n")
		for _, cmd := range packageCmds {
			spec := cmd.Spec()
			fmt.Fprintf(inv.Stdout, "  %-12s %s", spec.Name, spec.Summary)
			if spec.Package != "" {
				fmt.Fprintf(inv.Stdout, "  [%s]", spec.Package)
			}
			fmt.Fprintln(inv.Stdout)
		}
	}

	if !hasHub {
		fmt.Fprintf(inv.Stdout, "\n⚠ No hub found — commands requiring a hub are hidden.\n")
		fmt.Fprintf(inv.Stdout, "  Run 'cn init' to create a hub, or cd into an existing one.\n")
	}

	return nil
}
