package cli

import (
	"context"
	"encoding/json"
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"strings"
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

// checkResult records the outcome of one health check.
type checkResult struct {
	name   string
	passed bool
	value  string
}

func (c *DoctorCmd) Run(ctx context.Context, inv Invocation) error {
	fmt.Fprintf(inv.Stdout, "cn v%s\n", c.Version)
	fmt.Fprintf(inv.Stdout, "Checking health...\n\n")

	var checks []checkResult

	// --- Prerequisites ---
	checks = append(checks, checkTool(ctx, "git", "git", "--version"))
	checks = append(checks, checkGitConfig(ctx, "git user.name", "user.name"))
	checks = append(checks, checkGitConfig(ctx, "git user.email", "user.email"))
	checks = append(checks, checkTool(ctx, "curl", "curl", "--version"))

	// --- Hub structure ---
	checks = append(checks, checkExists(inv.HubPath, "hub directory"))
	checks = append(checks, checkConfig(inv.HubPath))
	checks = append(checks, checkFileOptional(inv.HubPath, "spec/SOUL.md"))
	checks = append(checks, checkPeers(inv.HubPath))
	checks = append(checks, checkExists(filepath.Join(inv.HubPath, "agent"), "agent/"))

	// --- Package system ---
	checks = append(checks, checkFilePresent(inv.HubPath, ".cn/deps.json",
		"missing (run 'cn setup')"))
	checks = append(checks, checkFilePresent(inv.HubPath, ".cn/deps.lock.json",
		"missing (run 'cn setup')"))
	checks = append(checks, checkPackages(inv.HubPath, c.Version))

	// --- Runtime contract ---
	checks = append(checks, checkRuntimeContract(inv.HubPath))

	// --- Git remote ---
	checks = append(checks, checkGitRemote(ctx, inv.HubPath))

	// Render results.
	anyFailed := false
	for _, ch := range checks {
		symbol := "✓"
		if !ch.passed {
			symbol = "✗"
			anyFailed = true
		}
		fmt.Fprintf(inv.Stdout, "%s %-25s %s\n", symbol, ch.name, ch.value)
	}

	fmt.Fprintln(inv.Stdout)
	if anyFailed {
		fmt.Fprintf(inv.Stdout, "⚠ Some checks failed. Run the suggested fixes above.\n")
		return fmt.Errorf("doctor: some checks failed")
	}
	fmt.Fprintf(inv.Stdout, "✓ All checks passed.\n")
	return nil
}

// --- Check helpers ---

func checkTool(ctx context.Context, name string, args ...string) checkResult {
	cmd := exec.CommandContext(ctx, args[0], args[1:]...)
	out, err := cmd.Output()
	if err != nil {
		return checkResult{name: name, passed: false, value: "not installed"}
	}
	// Extract first line, trim.
	line := strings.SplitN(strings.TrimSpace(string(out)), "\n", 2)[0]
	// For git: strip "git version " prefix.
	if strings.HasPrefix(line, "git version ") {
		line = strings.TrimPrefix(line, "git version ")
	}
	// For curl: extract just the version number (second word).
	if name == "curl" {
		parts := strings.Fields(line)
		if len(parts) >= 2 {
			line = parts[1]
		}
	}
	return checkResult{name: name, passed: true, value: line}
}

func checkGitConfig(ctx context.Context, label, key string) checkResult {
	cmd := exec.CommandContext(ctx, "git", "config", key)
	out, err := cmd.Output()
	if err != nil {
		return checkResult{name: label, passed: false, value: "not set"}
	}
	return checkResult{name: label, passed: true, value: strings.TrimSpace(string(out))}
}

func checkExists(path, label string) checkResult {
	if _, err := os.Stat(path); err == nil {
		return checkResult{name: label, passed: true, value: "exists"}
	}
	return checkResult{name: label, passed: false, value: "not found"}
}

func checkConfig(hubPath string) checkResult {
	jsonPath := filepath.Join(hubPath, ".cn", "config.json")
	yamlPath := filepath.Join(hubPath, ".cn", "config.yaml")
	if _, err := os.Stat(jsonPath); err == nil {
		return checkResult{name: ".cn/config", passed: true, value: "config.json"}
	}
	if _, err := os.Stat(yamlPath); err == nil {
		return checkResult{name: ".cn/config", passed: true, value: "config.yaml"}
	}
	return checkResult{name: ".cn/config", passed: false, value: "missing"}
}

func checkFileOptional(hubPath, rel string) checkResult {
	path := filepath.Join(hubPath, rel)
	if _, err := os.Stat(path); err == nil {
		return checkResult{name: rel, passed: true, value: "exists"}
	}
	return checkResult{name: rel, passed: false, value: "missing (optional)"}
}

func checkFilePresent(hubPath, rel, missingMsg string) checkResult {
	path := filepath.Join(hubPath, rel)
	if _, err := os.Stat(path); err == nil {
		return checkResult{name: rel, passed: true, value: "present"}
	}
	return checkResult{name: rel, passed: false, value: missingMsg}
}

func checkPeers(hubPath string) checkResult {
	path := filepath.Join(hubPath, "state", "peers.md")
	data, err := os.ReadFile(path)
	if err != nil {
		return checkResult{name: "state/peers.md", passed: false, value: "missing"}
	}
	count := 0
	for _, line := range strings.Split(string(data), "\n") {
		if strings.HasPrefix(strings.TrimSpace(line), "- name:") {
			count++
		}
	}
	return checkResult{name: "state/peers.md", passed: true,
		value: fmt.Sprintf("%d peer(s)", count)}
}

func checkPackages(hubPath, version string) checkResult {
	vendorDir := filepath.Join(hubPath, ".cn", "vendor", "packages")
	entries, err := os.ReadDir(vendorDir)
	if err != nil {
		return checkResult{name: "packages", passed: false,
			value: "no vendor directory (run 'cn deps restore')"}
	}
	total := 0
	drift := 0
	for _, e := range entries {
		if !e.IsDir() {
			continue
		}
		total++
		atIdx := strings.LastIndex(e.Name(), "@")
		if atIdx >= 0 && version != "" {
			pkgVersion := e.Name()[atIdx+1:]
			if pkgVersion != version {
				drift++
			}
		}
	}
	if total == 0 {
		return checkResult{name: "packages", passed: true, value: "none installed"}
	}
	if drift > 0 {
		return checkResult{name: "packages", passed: false,
			value: fmt.Sprintf("%d installed, %d version drift (run 'cn deps restore')", total, drift)}
	}
	return checkResult{name: "packages", passed: true,
		value: fmt.Sprintf("%d installed, all current", total)}
}

func checkRuntimeContract(hubPath string) checkResult {
	path := filepath.Join(hubPath, "state", "runtime-contract.json")
	data, err := os.ReadFile(path)
	if err != nil {
		return checkResult{name: "runtime contract", passed: false,
			value: "missing (generated at wake)"}
	}
	var doc map[string]any
	if err := json.Unmarshal(data, &doc); err != nil {
		return checkResult{name: "runtime contract", passed: false, value: "invalid JSON"}
	}
	// Check for v2 four-layer structure.
	layers := []string{"identity", "cognition", "body", "medium"}
	missing := []string{}
	for _, l := range layers {
		if _, ok := doc[l]; !ok {
			missing = append(missing, l)
		}
	}
	if len(missing) > 0 {
		return checkResult{name: "runtime contract", passed: false,
			value: fmt.Sprintf("incomplete (missing: %s)", strings.Join(missing, ", "))}
	}
	return checkResult{name: "runtime contract", passed: true,
		value: "valid (identity + cognition + body + medium)"}
}

func checkGitRemote(ctx context.Context, hubPath string) checkResult {
	cmd := exec.CommandContext(ctx, "git", "remote", "get-url", "origin")
	cmd.Dir = hubPath
	if _, err := cmd.Output(); err != nil {
		return checkResult{name: "origin remote", passed: false, value: "not configured"}
	}
	return checkResult{name: "origin remote", passed: true, value: "configured"}
}
