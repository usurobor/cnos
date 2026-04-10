// Command cn is the cnos kernel binary.
//
// It discovers the hub, registers kernel commands, and dispatches
// based on the first argument. See GO-KERNEL-COMMANDS.md for the
// full architecture.
package main

import (
	"context"
	"fmt"
	"os"
	"path/filepath"
	"strings"

	"github.com/usurobor/cnos/go/internal/cli"
)

// version is set at build time via -ldflags or defaults to "dev".
var version = "dev"

func main() {
	ctx := context.Background()

	// Build the kernel command registry.
	reg := cli.NewRegistry()
	helpCmd := &cli.HelpCmd{Registry: reg}
	reg.Register(helpCmd)
	reg.Register(&cli.InitCmd{})
	reg.Register(&cli.DepsCmd{})
	reg.Register(&cli.StatusCmd{Version: version})
	reg.Register(&cli.DoctorCmd{Version: version})
	reg.Register(&cli.BuildCmd{})

	// Discover hub: walk up from cwd to find .cn/.
	hubPath := discoverHub()

	// No args → help.
	if len(os.Args) < 2 {
		inv := makeInvocation(hubPath, nil)
		helpCmd.Run(ctx, inv)
		os.Exit(0)
	}

	cmdName := os.Args[1]
	args := os.Args[2:]

	cmd, ok := reg.Lookup(cmdName)
	if !ok {
		fmt.Fprintf(os.Stderr, "✗ Unknown command: %s\n\n", cmdName)
		fmt.Fprintf(os.Stderr, "Run 'cn help' to see available commands.\n")
		os.Exit(1)
	}

	// Check hub requirement.
	spec := cmd.Spec()
	if spec.NeedsHub && hubPath == "" {
		fmt.Fprintf(os.Stderr, "✗ Command '%s' requires a hub, but no hub found.\n\n", cmdName)
		fmt.Fprintf(os.Stderr, "Fix by running:\n")
		fmt.Fprintf(os.Stderr, "  1) cn init    (to create a new hub)\n")
		fmt.Fprintf(os.Stderr, "  2) cd <hub>   (to enter an existing hub)\n\n")
		fmt.Fprintf(os.Stderr, "Then rerun: cn %s %s\n", cmdName, strings.Join(args, " "))
		os.Exit(1)
	}

	inv := makeInvocation(hubPath, args)
	if err := cmd.Run(ctx, inv); err != nil {
		// The command already printed user-facing output to stderr.
		os.Exit(1)
	}
}

// discoverHub walks up from cwd looking for a .cn/ directory.
// Returns "" if no hub is found (not an error — some commands
// work without a hub).
func discoverHub() string {
	dir, err := os.Getwd()
	if err != nil {
		return ""
	}
	for {
		if info, err := os.Stat(filepath.Join(dir, ".cn")); err == nil && info.IsDir() {
			return dir
		}
		parent := filepath.Dir(dir)
		if parent == dir {
			return ""
		}
		dir = parent
	}
}

func makeInvocation(hubPath string, args []string) cli.Invocation {
	return cli.Invocation{
		HubPath: hubPath,
		Args:    args,
		Stdin:   os.Stdin,
		Stdout:  os.Stdout,
		Stderr:  os.Stderr,
		// Env left nil — commands use os.Getenv directly when needed.
		// Copying the entire env on every invocation was wasteful (F2).
	}
}
