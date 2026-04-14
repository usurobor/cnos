package cli

import (
	"context"
	"fmt"

	"github.com/usurobor/cnos/src/go/internal/doctor"
)

// DoctorCmd implements the "doctor" command — validates hub health.
type DoctorCmd struct {
	Version  string
	Registry *Registry // set by main.go so doctor can validate discovered commands
}

func (c *DoctorCmd) Spec() CommandSpec {
	return CommandSpec{
		Name:     "doctor",
		Summary:  "Validate hub health",
		Source:   SourceKernel,
		Tier:     TierKernel,
		NeedsHub: true,
	}
}

func (c *DoctorCmd) Run(ctx context.Context, inv Invocation) error {
	fmt.Fprintf(inv.Stdout, "cn v%s\n", c.Version)
	fmt.Fprintf(inv.Stdout, "Checking health...\n\n")

	// Collect command integrity issues from the full registry.
	var cmdIssues []doctor.CommandIssue
	if c.Registry != nil {
		cmdIssues = validateRegisteredCommands(c.Registry)
	}

	checks := doctor.RunAll(ctx, inv.HubPath, c.Version, cmdIssues)

	// Three-way glyph: ✓ validated, ○ pending/optional, ✗ broken.
	// Only ✗ drives the exit code — see doctor.HasFailures.
	for _, ch := range checks {
		symbol := "✓"
		switch ch.Status {
		case doctor.StatusInfo:
			symbol = "○"
		case doctor.StatusFail:
			symbol = "✗"
		}
		fmt.Fprintf(inv.Stdout, "%s %-25s %s\n", symbol, ch.Name, ch.Value)
	}

	fmt.Fprintln(inv.Stdout)
	if doctor.HasFailures(checks) {
		fmt.Fprintf(inv.Stdout, "⚠ Some checks failed. Run the suggested fixes above.\n")
		return fmt.Errorf("doctor: some checks failed")
	}
	fmt.Fprintf(inv.Stdout, "✓ All checks passed.\n")
	return nil
}

// validateRegisteredCommands extracts command descriptors from the
// registry and passes them to doctor for integrity validation.
// No os/filepath imports here — doctor owns the actual checks.
func validateRegisteredCommands(reg *Registry) []doctor.CommandIssue {
	var descs []doctor.CommandDescriptor
	for _, cmd := range reg.All() {
		spec := cmd.Spec()
		desc := doctor.CommandDescriptor{
			Name:    spec.Name,
			Source:  string(spec.Source),
			Tier:    int(spec.Tier),
			Package: spec.Package,
		}
		// If the command has an entrypoint (exec-backed), extract it.
		if v, ok := cmd.(interface{ Entrypoint() string }); ok {
			desc.Entrypoint = v.Entrypoint()
		}
		descs = append(descs, desc)
	}
	return doctor.ValidateCommands(descs)
}
