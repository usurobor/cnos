// Package doctor implements hub health validation checks.
//
// Each check returns a CheckResult. The caller (cli/cmd_doctor.go)
// collects results and renders them. This separation keeps cli/
// as a thin dispatch layer per eng/go §2.18 (INVARIANTS.md T-002).
package doctor

import (
	"context"
	"encoding/json"
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"strings"
)

// CheckResult records the outcome of one health check.
type CheckResult struct {
	Name   string
	Passed bool
	Value  string
}

// RunAll executes all doctor checks and returns the results.
func RunAll(ctx context.Context, hubPath, version string) []CheckResult {
	var checks []CheckResult

	// Prerequisites.
	checks = append(checks, checkTool(ctx, "git", "git", "--version"))
	checks = append(checks, checkGitConfig(ctx, "git user.name", "user.name"))
	checks = append(checks, checkGitConfig(ctx, "git user.email", "user.email"))
	checks = append(checks, checkTool(ctx, "curl", "curl", "--version"))

	// Hub structure.
	checks = append(checks, checkExists(hubPath, "hub directory"))
	checks = append(checks, checkConfig(hubPath))
	checks = append(checks, checkFileOptional(hubPath, "spec/SOUL.md"))
	checks = append(checks, checkPeers(hubPath))
	checks = append(checks, checkExists(filepath.Join(hubPath, "agent"), "agent/"))

	// Package system.
	checks = append(checks, checkFilePresent(hubPath, ".cn/deps.json",
		"missing (run 'cn setup')"))
	checks = append(checks, checkFilePresent(hubPath, ".cn/deps.lock.json",
		"missing (run 'cn setup')"))
	checks = append(checks, checkPackages(hubPath, version))

	// Runtime contract.
	checks = append(checks, checkRuntimeContract(hubPath))

	// Git remote.
	checks = append(checks, checkGitRemote(ctx, hubPath))

	return checks
}

// HasFailures returns true if any check failed.
func HasFailures(checks []CheckResult) bool {
	for _, ch := range checks {
		if !ch.Passed {
			return true
		}
	}
	return false
}

// --- Check implementations ---

func checkTool(ctx context.Context, name string, args ...string) CheckResult {
	cmd := exec.CommandContext(ctx, args[0], args[1:]...)
	out, err := cmd.Output()
	if err != nil {
		return CheckResult{Name: name, Passed: false, Value: "not installed"}
	}
	line := strings.SplitN(strings.TrimSpace(string(out)), "\n", 2)[0]
	if strings.HasPrefix(line, "git version ") {
		line = strings.TrimPrefix(line, "git version ")
	}
	if name == "curl" {
		parts := strings.Fields(line)
		if len(parts) >= 2 {
			line = parts[1]
		}
	}
	return CheckResult{Name: name, Passed: true, Value: line}
}

func checkGitConfig(ctx context.Context, label, key string) CheckResult {
	cmd := exec.CommandContext(ctx, "git", "config", key)
	out, err := cmd.Output()
	if err != nil {
		return CheckResult{Name: label, Passed: false, Value: "not set"}
	}
	return CheckResult{Name: label, Passed: true, Value: strings.TrimSpace(string(out))}
}

func checkExists(path, label string) CheckResult {
	if _, err := os.Stat(path); err == nil {
		return CheckResult{Name: label, Passed: true, Value: "exists"}
	}
	return CheckResult{Name: label, Passed: false, Value: "not found"}
}

func checkConfig(hubPath string) CheckResult {
	jsonPath := filepath.Join(hubPath, ".cn", "config.json")
	yamlPath := filepath.Join(hubPath, ".cn", "config.yaml")
	if _, err := os.Stat(jsonPath); err == nil {
		return CheckResult{Name: ".cn/config", Passed: true, Value: "config.json"}
	}
	if _, err := os.Stat(yamlPath); err == nil {
		return CheckResult{Name: ".cn/config", Passed: true, Value: "config.yaml"}
	}
	return CheckResult{Name: ".cn/config", Passed: false, Value: "missing"}
}

func checkFileOptional(hubPath, rel string) CheckResult {
	path := filepath.Join(hubPath, rel)
	if _, err := os.Stat(path); err == nil {
		return CheckResult{Name: rel, Passed: true, Value: "exists"}
	}
	return CheckResult{Name: rel, Passed: true, Value: "missing (optional)"}
}

func checkFilePresent(hubPath, rel, missingMsg string) CheckResult {
	path := filepath.Join(hubPath, rel)
	if _, err := os.Stat(path); err == nil {
		return CheckResult{Name: rel, Passed: true, Value: "present"}
	}
	return CheckResult{Name: rel, Passed: false, Value: missingMsg}
}

func checkPeers(hubPath string) CheckResult {
	path := filepath.Join(hubPath, "state", "peers.md")
	data, err := os.ReadFile(path)
	if err != nil {
		return CheckResult{Name: "state/peers.md", Passed: false, Value: "missing"}
	}
	count := 0
	for _, line := range strings.Split(string(data), "\n") {
		if strings.HasPrefix(strings.TrimSpace(line), "- name:") {
			count++
		}
	}
	return CheckResult{Name: "state/peers.md", Passed: true,
		Value: fmt.Sprintf("%d peer(s)", count)}
}

func checkPackages(hubPath, version string) CheckResult {
	vendorDir := filepath.Join(hubPath, ".cn", "vendor", "packages")
	entries, err := os.ReadDir(vendorDir)
	if err != nil {
		return CheckResult{Name: "packages", Passed: false,
			Value: "no vendor directory (run 'cn deps restore')"}
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
		return CheckResult{Name: "packages", Passed: true, Value: "none installed"}
	}
	if drift > 0 {
		return CheckResult{Name: "packages", Passed: false,
			Value: fmt.Sprintf("%d installed, %d version drift (run 'cn deps restore')", total, drift)}
	}
	return CheckResult{Name: "packages", Passed: true,
		Value: fmt.Sprintf("%d installed, all current", total)}
}

func checkRuntimeContract(hubPath string) CheckResult {
	path := filepath.Join(hubPath, "state", "runtime-contract.json")
	data, err := os.ReadFile(path)
	if err != nil {
		return CheckResult{Name: "runtime contract", Passed: false,
			Value: "missing (generated at wake)"}
	}
	var doc map[string]any
	if err := json.Unmarshal(data, &doc); err != nil {
		return CheckResult{Name: "runtime contract", Passed: false, Value: "invalid JSON"}
	}
	layers := []string{"identity", "cognition", "body", "medium"}
	var missing []string
	for _, l := range layers {
		if _, ok := doc[l]; !ok {
			missing = append(missing, l)
		}
	}
	if len(missing) > 0 {
		return CheckResult{Name: "runtime contract", Passed: false,
			Value: fmt.Sprintf("incomplete (missing: %s)", strings.Join(missing, ", "))}
	}
	return CheckResult{Name: "runtime contract", Passed: true,
		Value: "valid (identity + cognition + body + medium)"}
}

func checkGitRemote(ctx context.Context, hubPath string) CheckResult {
	cmd := exec.CommandContext(ctx, "git", "remote", "get-url", "origin")
	cmd.Dir = hubPath
	if _, err := cmd.Output(); err != nil {
		return CheckResult{Name: "origin remote", Passed: false, Value: "not configured"}
	}
	return CheckResult{Name: "origin remote", Passed: true, Value: "configured"}
}
