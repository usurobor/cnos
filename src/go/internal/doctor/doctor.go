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

// CommandIssue is a command integrity problem found during validation.
// Imported from discover package for doctor reporting.
type CommandIssue struct {
	CommandName string
	Package     string
	Problem     string
}

// RunAll executes all doctor checks and returns the results.
// commandIssues is an optional list of command integrity problems
// found during command discovery (pass nil if no discovery was done).
func RunAll(ctx context.Context, hubPath, version string, commandIssues []CommandIssue) []CheckResult {
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
	// deps.lock.json and .cn/vendor/ only exist after `cn deps lock` /
	// `cn deps restore`. On a freshly-set-up hub they are legitimately
	// absent — report the state informationally rather than failing.
	checks = append(checks, checkFileInformational(hubPath, ".cn/deps.lock.json",
		"pending (run 'cn deps lock')"))
	checks = append(checks, checkPackages(hubPath, version))

	// Command integrity.
	checks = append(checks, checkCommandIntegrity(commandIssues))

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

// checkFileInformational reports a file's presence without flagging
// a missing file as a failure. Use for artifacts that are expected
// to arrive later in the hub lifecycle (e.g. deps.lock.json only
// exists after `cn deps lock`).
func checkFileInformational(hubPath, rel, missingMsg string) CheckResult {
	path := filepath.Join(hubPath, rel)
	if _, err := os.Stat(path); err == nil {
		return CheckResult{Name: rel, Passed: true, Value: "present"}
	}
	return CheckResult{Name: rel, Passed: true, Value: missingMsg}
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

func checkPackages(hubPath, _ string) CheckResult {
	vendorDir := filepath.Join(hubPath, ".cn", "vendor", "packages")
	entries, err := os.ReadDir(vendorDir)
	if err != nil {
		// No vendor directory is expected before the first restore.
		// Only flag as a failure if a lockfile exists (which implies
		// packages were locked and should have been installed).
		lockPath := filepath.Join(hubPath, ".cn", "deps.lock.json")
		if _, lockErr := os.Stat(lockPath); lockErr != nil {
			return CheckResult{Name: "packages", Passed: true,
				Value: "none installed (pending 'cn deps restore')"}
		}
		return CheckResult{Name: "packages", Passed: false,
			Value: "no vendor directory (run 'cn deps restore')"}
	}
	total := 0
	for _, e := range entries {
		if !e.IsDir() {
			continue
		}
		total++
	}
	if total == 0 {
		return CheckResult{Name: "packages", Passed: true, Value: "none installed"}
	}
	// Version drift detection: compare installed packages against the
	// lockfile. The installed path no longer carries the version
	// (BUILD-AND-DIST.md), so we read the lockfile as the expected set.
	lockPath := filepath.Join(hubPath, ".cn", "deps.lock.json")
	lockData, err := os.ReadFile(lockPath)
	if err != nil {
		// No lockfile — can't check drift, just report count.
		return CheckResult{Name: "packages", Passed: true,
			Value: fmt.Sprintf("%d installed (no lockfile for drift check)", total)}
	}
	var lf struct {
		Packages []struct {
			Name string `json:"name"`
		} `json:"packages"`
	}
	if err := json.Unmarshal(lockData, &lf); err != nil {
		return CheckResult{Name: "packages", Passed: true,
			Value: fmt.Sprintf("%d installed (lockfile parse error)", total)}
	}
	// Check each locked package is installed.
	missing := 0
	for _, dep := range lf.Packages {
		pkgDir := filepath.Join(vendorDir, dep.Name)
		if _, err := os.Stat(pkgDir); err != nil {
			missing++
		}
	}
	if missing > 0 {
		return CheckResult{Name: "packages", Passed: false,
			Value: fmt.Sprintf("%d installed, %d missing from lockfile (run 'cn deps restore')", total, missing)}
	}
	return CheckResult{Name: "packages", Passed: true,
		Value: fmt.Sprintf("%d installed, all present", total)}
}

func checkRuntimeContract(hubPath string) CheckResult {
	path := filepath.Join(hubPath, "state", "runtime-contract.json")
	data, err := os.ReadFile(path)
	if err != nil {
		// The contract is produced at wake. Before the first wake it
		// is legitimately absent on a freshly-set-up hub — reported
		// informationally. A present-but-invalid contract is a real
		// failure (handled below).
		return CheckResult{Name: "runtime contract", Passed: true,
			Value: "pending (generated at wake)"}
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
		// A hub may operate without an origin remote (offline / local).
		// Report the state without failing the check.
		return CheckResult{Name: "origin remote", Passed: true, Value: "not configured (optional)"}
	}
	return CheckResult{Name: "origin remote", Passed: true, Value: "configured"}
}

// CommandDescriptor is a plain data record describing one registered
// command. Passed from cli/ to doctor/ to avoid circular imports.
type CommandDescriptor struct {
	Name       string
	Source     string // "kernel", "repo-local", "package"
	Tier       int    // 0=kernel, 1=repo-local, 2=package
	Package    string // package name (empty for kernel/repo-local)
	Entrypoint string // absolute path to entrypoint script (empty for kernel)
}

// ValidateCommands checks command integrity from a list of descriptors:
//   - missing entrypoints
//   - non-executable entrypoints
//   - duplicate command names within a single tier
func ValidateCommands(descs []CommandDescriptor) []CommandIssue {
	var issues []CommandIssue

	tierNames := make(map[int]map[string]int)
	for _, d := range descs {
		if tierNames[d.Tier] == nil {
			tierNames[d.Tier] = make(map[string]int)
		}
		tierNames[d.Tier][d.Name]++

		if d.Entrypoint == "" {
			continue
		}

		info, err := os.Stat(d.Entrypoint)
		if err != nil {
			issues = append(issues, CommandIssue{
				CommandName: d.Name,
				Package:     d.Package,
				Problem:     "missing entrypoint: " + d.Entrypoint,
			})
			continue
		}
		if info.Mode()&0111 == 0 {
			issues = append(issues, CommandIssue{
				CommandName: d.Name,
				Package:     d.Package,
				Problem:     "entrypoint not executable: " + d.Entrypoint,
			})
		}
	}

	for tier, names := range tierNames {
		for name, count := range names {
			if count > 1 {
				tierLabel := "unknown"
				switch tier {
				case 0:
					tierLabel = "kernel"
				case 1:
					tierLabel = "repo-local"
				case 2:
					tierLabel = "package"
				}
				issues = append(issues, CommandIssue{
					CommandName: name,
					Problem:     fmt.Sprintf("duplicate in %s tier (%d definitions)", tierLabel, count),
				})
			}
		}
	}

	return issues
}

func checkCommandIntegrity(issues []CommandIssue) CheckResult {
	if len(issues) == 0 {
		return CheckResult{Name: "command integrity", Passed: true, Value: "all commands valid"}
	}
	msgs := make([]string, len(issues))
	for i, iss := range issues {
		if iss.Package != "" {
			msgs[i] = fmt.Sprintf("%s (%s): %s", iss.CommandName, iss.Package, iss.Problem)
		} else {
			msgs[i] = fmt.Sprintf("%s: %s", iss.CommandName, iss.Problem)
		}
	}
	return CheckResult{
		Name:   "command integrity",
		Passed: false,
		Value:  fmt.Sprintf("%d issue(s): %s", len(issues), strings.Join(msgs, "; ")),
	}
}
