// Package hubinit implements hub creation logic for cn init.
//
// Extracted from cli/cmd_init.go per eng/go §2.18 (INVARIANTS.md T-002).
package hubinit

import (
	"context"
	"encoding/json"
	"fmt"
	"io"
	"os"
	"os/exec"
	"path/filepath"
	"time"
)

// Run creates a new hub at cn-<hubName>/ in the current directory.
// If hubName is empty, derives it from the current directory name.
func Run(ctx context.Context, hubName string, stdout, stderr io.Writer) error {
	if hubName == "" {
		cwd, err := os.Getwd()
		if err != nil {
			return fmt.Errorf("init: cannot determine current directory: %w", err)
		}
		hubName = filepath.Base(cwd)
	}

	if !validHubName(hubName) {
		fmt.Fprintf(stderr, "✗ Invalid hub name: %q\n\n", hubName)
		fmt.Fprintf(stderr, "Hub names must contain only letters, digits, hyphens, underscores, or dots.\n")
		return fmt.Errorf("init: invalid hub name %q", hubName)
	}

	// Hub directory uses the "cn-" prefix convention, matching OCaml
	// cn_system.ml::run_init. Standard cnos hub naming:
	// cn-<agent-name> (e.g., cn-sigma, cn-omega).
	hubDir := "cn-" + hubName

	if _, err := os.Stat(hubDir); err == nil {
		fmt.Fprintf(stderr, "✗ Directory %s already exists\n", hubDir)
		return fmt.Errorf("init: directory %s already exists", hubDir)
	}

	fmt.Fprintf(stdout, "→ Initializing hub: %s\n", hubName)

	dirs := []string{
		".cn", "spec", "state",
		"threads/in", "threads/mail/inbox", "threads/mail/outbox", "threads/mail/sent",
		"threads/reflections/daily", "threads/reflections/weekly", "threads/reflections/monthly",
		"threads/adhoc", "threads/archived",
		"logs", "agent",
	}
	for _, d := range dirs {
		if err := os.MkdirAll(filepath.Join(hubDir, d), 0755); err != nil {
			return fmt.Errorf("init: create %s: %w", d, err)
		}
	}

	config := map[string]string{
		"name":    hubName,
		"version": "1.0.0",
		"created": time.Now().UTC().Format(time.RFC3339),
	}
	configData, err := json.MarshalIndent(config, "", "  ")
	if err != nil {
		return fmt.Errorf("init: marshal config: %w", err)
	}
	if err := os.WriteFile(filepath.Join(hubDir, ".cn", "config.json"), append(configData, '\n'), 0644); err != nil {
		return fmt.Errorf("init: write config: %w", err)
	}

	peersContent := `# Peers

Agents and repos this hub communicates with.
Add entries in the form:

  - name: <agent-name>
    hub: <repo-url>
    kind: peer
`
	if err := os.WriteFile(filepath.Join(hubDir, "state", "peers.md"), []byte(peersContent), 0644); err != nil {
		return fmt.Errorf("init: write peers: %w", err)
	}

	soulContent := fmt.Sprintf(`# SOUL.md - Core Contract

*%s is an agent on the Coherent Network.*

## Identity

- **Name:** %s
- **Role:** (define your role)
- **Mode:** Collaborative

## Conduct

- Be genuinely helpful
`, hubName, hubName)
	if err := os.WriteFile(filepath.Join(hubDir, "spec", "SOUL.md"), []byte(soulContent), 0644); err != nil {
		return fmt.Errorf("init: write SOUL.md: %w", err)
	}

	gitCmd := exec.CommandContext(ctx, "git", "init", "-b", "main")
	gitCmd.Dir = hubDir
	if out, err := gitCmd.CombinedOutput(); err != nil {
		fmt.Fprintf(stderr, "⚠ git init failed: %s\n", string(out))
	}

	fmt.Fprintf(stdout, "✓ Hub initialized at %s\n", hubDir)
	return nil
}

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
