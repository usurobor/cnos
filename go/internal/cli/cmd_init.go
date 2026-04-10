package cli

import (
	"context"
	"encoding/json"
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"time"
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
	// Determine hub name from args or cwd.
	var hubName string
	if len(inv.Args) > 0 {
		hubName = inv.Args[0]
	} else {
		cwd, err := os.Getwd()
		if err != nil {
			return fmt.Errorf("init: cannot determine current directory: %w", err)
		}
		hubName = filepath.Base(cwd)
	}

	// Validate hub name: bare names only (alphanumeric, hyphens,
	// underscores, dots). Reject path separators, "..", or empty
	// to prevent directory traversal or unexpected paths.
	if !validHubName(hubName) {
		fmt.Fprintf(inv.Stderr, "✗ Invalid hub name: %q\n\n", hubName)
		fmt.Fprintf(inv.Stderr, "Hub names must contain only letters, digits, hyphens, underscores, or dots.\n")
		return fmt.Errorf("init: invalid hub name %q", hubName)
	}

	// Hub directory uses the "cn-" prefix convention, matching OCaml
	// cn_system.ml::run_init. This is the standard cnos hub naming:
	// cn-<agent-name> (e.g., cn-sigma, cn-omega).
	hubDir := "cn-" + hubName

	// Check if directory already exists.
	if _, err := os.Stat(hubDir); err == nil {
		fmt.Fprintf(inv.Stderr, "✗ Directory %s already exists\n", hubDir)
		return fmt.Errorf("init: directory %s already exists", hubDir)
	}

	fmt.Fprintf(inv.Stdout, "→ Initializing hub: %s\n", hubName)

	// Create directory structure mirroring OCaml cn_system.ml::run_init.
	dirs := []string{
		".cn",
		"spec",
		"state",
		"threads/in",
		"threads/mail/inbox",
		"threads/mail/outbox",
		"threads/mail/sent",
		"threads/reflections/daily",
		"threads/reflections/weekly",
		"threads/reflections/monthly",
		"threads/adhoc",
		"threads/archived",
		"logs",
		"agent",
	}
	for _, d := range dirs {
		if err := os.MkdirAll(filepath.Join(hubDir, d), 0755); err != nil {
			return fmt.Errorf("init: create %s: %w", d, err)
		}
	}

	// Write .cn/config.json.
	config := map[string]string{
		"name":    hubName,
		"version": "1.0.0",
		"created": time.Now().UTC().Format(time.RFC3339),
	}
	configData, err := json.MarshalIndent(config, "", "  ")
	if err != nil {
		return fmt.Errorf("init: marshal config: %w", err)
	}
	configPath := filepath.Join(hubDir, ".cn", "config.json")
	if err := os.WriteFile(configPath, append(configData, '\n'), 0644); err != nil {
		return fmt.Errorf("init: write config: %w", err)
	}

	// Write state/peers.md — minimal scaffold. Operators add peers
	// manually; no hardcoded template peers that may not exist.
	peersContent := `# Peers

Agents and repos this hub communicates with.
Add entries in the form:

  - name: <agent-name>
    hub: <repo-url>
    kind: peer
`
	peersPath := filepath.Join(hubDir, "state", "peers.md")
	if err := os.WriteFile(peersPath, []byte(peersContent), 0644); err != nil {
		return fmt.Errorf("init: write peers: %w", err)
	}

	// Write spec/SOUL.md stub.
	soulContent := fmt.Sprintf(`# SOUL.md - Core Contract

*%s is an agent on the Coherent Network.*

## Identity

- **Name:** %s
- **Role:** (define your role)
- **Mode:** Collaborative

## Conduct

- Be genuinely helpful
`, hubName, hubName)
	soulPath := filepath.Join(hubDir, "spec", "SOUL.md")
	if err := os.WriteFile(soulPath, []byte(soulContent), 0644); err != nil {
		return fmt.Errorf("init: write SOUL.md: %w", err)
	}

	// Initialize git repo.
	gitCmd := exec.CommandContext(ctx, "git", "init", "-b", "main")
	gitCmd.Dir = hubDir
	if out, err := gitCmd.CombinedOutput(); err != nil {
		fmt.Fprintf(inv.Stderr, "⚠ git init failed: %s\n", string(out))
		// Non-fatal — hub is usable without git.
	}

	fmt.Fprintf(inv.Stdout, "✓ Hub initialized at %s\n", hubDir)
	return nil
}

// validHubName returns true iff name is a bare name suitable for use
// as a directory component: non-empty, contains only alphanumeric
// characters, hyphens, underscores, and dots.
func validHubName(name string) bool {
	if name == "" {
		return false
	}
	for _, r := range name {
		if !((r >= 'a' && r <= 'z') || (r >= 'A' && r <= 'Z') || (r >= '0' && r <= '9') || r == '-' || r == '_' || r == '.') {
			return false
		}
	}
	return true
}
