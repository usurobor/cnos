package cli

import (
	"context"
	"fmt"

	"github.com/usurobor/cnos/go/internal/doctor"
)

// DoctorCmd implements the "doctor" command — validates hub health.
type DoctorCmd struct {
	Version string
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

	checks := doctor.RunAll(ctx, inv.HubPath, c.Version)

	for _, ch := range checks {
		symbol := "✓"
		if !ch.Passed {
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
