// Package discover scans installed packages and repo-local conventions
// for commands and returns them as cli.Command implementations.
//
// Scanning and exec logic live here — not in cli/cmd_*.go — per
// eng/go §2.18 (INVARIANTS.md T-002: kernel dispatch boundary).
//
// Two scan functions:
//   - ScanPackageCommands: walks .cn/vendor/packages/*/cn.package.json
//   - ScanRepoLocalCommands: walks .cn/commands/cn-*
//
// Both return []cli.Command ready for registry registration.
package discover

import (
	"context"
	"fmt"
	"io"
	"log/slog"
	"os"
	"os/exec"
	"path/filepath"
	"strings"

	"github.com/usurobor/cnos/src/go/internal/cli"
	"github.com/usurobor/cnos/src/go/internal/pkg"
)

// ScanPackageCommands walks .cn/vendor/packages/ and returns a Command
// for every command declared in installed package manifests.
//
// Errors in individual packages are logged and skipped — a malformed
// manifest does not prevent other packages from loading. Doctor checks
// will report these separately.
func ScanPackageCommands(hubPath string) []cli.Command {
	vendorDir := filepath.Join(hubPath, ".cn", "vendor", "packages")
	entries, err := os.ReadDir(vendorDir)
	if err != nil {
		slog.Debug("scan package commands: cannot read vendor dir",
			slog.String("path", vendorDir),
			slog.String("err", err.Error()))
		return nil
	}

	var cmds []cli.Command
	for _, entry := range entries {
		if !entry.IsDir() {
			continue
		}
		pkgName := entry.Name()
		pkgDir := filepath.Join(vendorDir, pkgName)
		manifestPath := filepath.Join(pkgDir, "cn.package.json")

		data, err := os.ReadFile(manifestPath)
		if err != nil {
			slog.Debug("scan package commands: cannot read manifest",
				slog.String("package", pkgName),
				slog.String("err", err.Error()))
			continue
		}

		manifest, err := pkg.ParseFullManifestData(data)
		if err != nil {
			slog.Debug("scan package commands: malformed manifest",
				slog.String("package", pkgName),
				slog.String("err", err.Error()))
			continue
		}

		for _, ce := range manifest.CommandEntries() {
			entrypointPath := filepath.Join(pkgDir, ce.Entrypoint)
			cmds = append(cmds, &ExecCommand{
				spec: cli.CommandSpec{
					Name:     ce.Name,
					Summary:  ce.Summary,
					Source:   cli.SourcePackage,
					Tier:     cli.TierPackage,
					Package:  pkgName,
					NeedsHub: true, // package commands require a hub
				},
				entrypoint: entrypointPath,
				packageDir: pkgDir,
			})
		}
	}
	return cmds
}

// ScanRepoLocalCommands walks .cn/commands/ for executable files
// matching the cn-<name> naming convention and returns a Command
// for each one.
func ScanRepoLocalCommands(hubPath string) []cli.Command {
	cmdDir := filepath.Join(hubPath, ".cn", "commands")
	entries, err := os.ReadDir(cmdDir)
	if err != nil {
		slog.Debug("scan repo-local commands: cannot read commands dir",
			slog.String("path", cmdDir),
			slog.String("err", err.Error()))
		return nil
	}

	var cmds []cli.Command
	for _, entry := range entries {
		if entry.IsDir() {
			continue
		}
		name := entry.Name()
		if !strings.HasPrefix(name, "cn-") {
			continue
		}
		cmdName := strings.TrimPrefix(name, "cn-")
		if cmdName == "" {
			continue
		}
		entrypointPath := filepath.Join(cmdDir, name)
		cmds = append(cmds, &ExecCommand{
			spec: cli.CommandSpec{
				Name:     cmdName,
				Summary:  "(repo-local command)",
				Source:   cli.SourceRepoLocal,
				Tier:     cli.TierRepoLocal,
				NeedsHub: true,
			},
			entrypoint: entrypointPath,
			packageDir: "",
		})
	}
	return cmds
}

// ExecCommand is a cli.Command backed by an external entrypoint script.
// Used for both package-vendored and repo-local commands.
type ExecCommand struct {
	spec       cli.CommandSpec
	entrypoint string // absolute path to the entrypoint script
	packageDir string // package root dir (empty for repo-local)
}

func (c *ExecCommand) Spec() cli.CommandSpec { return c.spec }

// Run executes the entrypoint script, passing hub path and package root
// as environment variables per the cnos command dispatch contract.
func (c *ExecCommand) Run(ctx context.Context, inv cli.Invocation) error {
	if _, err := os.Stat(c.entrypoint); err != nil {
		return fmt.Errorf("command %q: entrypoint not found: %s", c.spec.Name, c.entrypoint)
	}

	cmd := exec.CommandContext(ctx, c.entrypoint, inv.Args...)
	cmd.Stdin = inv.Stdin
	cmd.Stdout = inv.Stdout
	cmd.Stderr = inv.Stderr

	// Build environment: inherit current env + dispatch vars.
	cmd.Env = os.Environ()
	cmd.Env = append(cmd.Env, "CN_HUB_PATH="+inv.HubPath)
	cmd.Env = append(cmd.Env, "CN_COMMAND_NAME="+c.spec.Name)
	if c.packageDir != "" {
		cmd.Env = append(cmd.Env, "CN_PACKAGE_ROOT="+c.packageDir)
	}

	// Merge any extra env from invocation.
	for k, v := range inv.Env {
		cmd.Env = append(cmd.Env, k+"="+v)
	}

	if err := cmd.Run(); err != nil {
		// If the command exited with a non-zero status, surface that.
		if exitErr, ok := err.(*exec.ExitError); ok {
			return fmt.Errorf("command %q exited with status %d", c.spec.Name, exitErr.ExitCode())
		}
		return fmt.Errorf("command %q: %w", c.spec.Name, err)
	}
	return nil
}

// CommandIssue records a problem found during command integrity validation.
type CommandIssue struct {
	CommandName string
	Package     string
	Problem     string
}

func (i CommandIssue) String() string {
	if i.Package != "" {
		return fmt.Sprintf("%s (%s): %s", i.CommandName, i.Package, i.Problem)
	}
	return fmt.Sprintf("%s: %s", i.CommandName, i.Problem)
}

// ValidateCommands checks command integrity after discovery:
//   - missing entrypoints
//   - non-executable entrypoints
//   - duplicate command names within a single tier
func ValidateCommands(cmds []cli.Command) []CommandIssue {
	var issues []CommandIssue

	// Track names per tier for duplicate detection.
	tierNames := make(map[cli.CommandTier]map[string]int)

	for _, cmd := range cmds {
		spec := cmd.Spec()
		tier := spec.Tier

		// Duplicate detection within same tier.
		if tierNames[tier] == nil {
			tierNames[tier] = make(map[string]int)
		}
		tierNames[tier][spec.Name]++

		// Entrypoint checks only apply to exec-backed commands.
		ec, ok := cmd.(*ExecCommand)
		if !ok {
			continue
		}

		info, err := os.Stat(ec.entrypoint)
		if err != nil {
			issues = append(issues, CommandIssue{
				CommandName: spec.Name,
				Package:     spec.Package,
				Problem:     "missing entrypoint: " + ec.entrypoint,
			})
			continue
		}

		// Check executable bit (Unix).
		if info.Mode()&0111 == 0 {
			issues = append(issues, CommandIssue{
				CommandName: spec.Name,
				Package:     spec.Package,
				Problem:     "entrypoint not executable: " + ec.entrypoint,
			})
		}
	}

	// Report duplicates within same tier.
	for tier, names := range tierNames {
		for name, count := range names {
			if count > 1 {
				tierLabel := "unknown"
				switch tier {
				case cli.TierKernel:
					tierLabel = "kernel"
				case cli.TierRepoLocal:
					tierLabel = "repo-local"
				case cli.TierPackage:
					tierLabel = "package"
				}
				issues = append(issues, CommandIssue{
					CommandName: name,
					Problem:     fmt.Sprintf("duplicate command name in %s tier (%d definitions)", tierLabel, count),
				})
			}
		}
	}

	return issues
}

// Entrypoint returns the entrypoint path for an ExecCommand.
// Used by doctor checks to inspect command integrity.
func (c *ExecCommand) Entrypoint() string { return c.entrypoint }

// FormatIssues renders a slice of CommandIssues for output. Pure function.
func FormatIssues(issues []CommandIssue, w io.Writer) {
	for _, iss := range issues {
		fmt.Fprintf(w, "  ✗ %s\n", iss)
	}
}
