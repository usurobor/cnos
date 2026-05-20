// Package hubstatus implements the cn status display logic.
//
// Extracted from cli/cmd_status.go per eng/go §2.18 (INVARIANTS.md T-002).
// This package does not import cli/ — it accepts pure data types to
// avoid import cycles (eng/go §2.17).
package hubstatus

import (
	"encoding/json"
	"fmt"
	"io"
	"os"
	"path/filepath"
	"slices"
	"strings"

	"github.com/usurobor/cnos/src/go/internal/pkg"
	"github.com/usurobor/cnos/src/go/internal/pkgbuild"
)

// CommandInfo is the data hubstatus needs to display a command.
// Populated by the cli layer from the Registry — no cli/ import needed.
type CommandInfo struct {
	Name    string
	Summary string
	Tier    string // "kernel", "repo-local", "package"
	Package string // non-empty for package commands
}

// Run displays hub info, installed packages (from manifests), and
// the command registry grouped by tier.
//
// Package metadata is read from cn.package.json inside each vendor
// dir — not parsed from directory names (BUILD-AND-DIST.md: vendor
// path is name/, no @version).
//
// Version drift compares each manifest's engines.cnos against the
// running binary version.
func Run(hubPath, version string, commands []CommandInfo, stdout io.Writer) error {
	hubName := filepath.Base(hubPath)

	fmt.Fprintf(stdout, "cn hub: %s\n\n", hubName)
	fmt.Fprintf(stdout, "hub..................... %s\n", check)
	fmt.Fprintf(stdout, "name.................... %s %s\n", check, hubName)
	fmt.Fprintf(stdout, "path.................... %s %s\n", check, hubPath)

	if err := showPackages(hubPath, version, stdout); err != nil {
		return err
	}

	showMemory(hubPath, stdout)
	showCommands(commands, stdout)
	return nil
}

// showMemory renders the cognition.memory block of the runtime
// contract (#100 AC6). The OCaml emitter is the authority; this
// renderer projects the JSON shape it wrote. Absence is rendered
// as pending (the contract is generated at wake), not failure —
// fresh hubs legitimately have no contract yet.
func showMemory(hubPath string, stdout io.Writer) {
	contractPath := filepath.Join(hubPath, "state", "runtime-contract.json")
	data, err := os.ReadFile(contractPath)
	if err != nil {
		fmt.Fprintf(stdout, "\nMemory:\n  %s pending (no runtime contract; generated at wake)\n",
			cross)
		return
	}
	var doc struct {
		Cognition struct {
			Memory struct {
				Backend    string   `json:"backend"`
				Entrypoint string   `json:"entrypoint"`
				Surfaces   []string `json:"surfaces"`
				Freshness  string   `json:"freshness"`
				Scope      string   `json:"scope"`
			} `json:"memory"`
		} `json:"cognition"`
	}
	if err := json.Unmarshal(data, &doc); err != nil {
		fmt.Fprintf(stdout, "\nMemory:\n  %s pending (runtime contract unparseable)\n",
			cross)
		return
	}
	m := doc.Cognition.Memory
	if m.Backend == "" && m.Entrypoint == "" {
		fmt.Fprintf(stdout, "\nMemory:\n  %s pending (contract missing cognition.memory; regenerate at next wake)\n",
			cross)
		return
	}
	fmt.Fprintf(stdout, "\nMemory:\n")
	fmt.Fprintf(stdout, "  backend.............. %s %s\n", check, m.Backend)
	fmt.Fprintf(stdout, "  entrypoint........... %s %s\n", check, m.Entrypoint)
	if len(m.Surfaces) > 0 {
		fmt.Fprintf(stdout, "  surfaces............. %s %s\n", check,
			strings.Join(m.Surfaces, ", "))
	}
	if m.Freshness != "" {
		fmt.Fprintf(stdout, "  freshness............ %s %s\n", check, m.Freshness)
	}
	if m.Scope != "" {
		fmt.Fprintf(stdout, "  scope................ %s %s\n", check, m.Scope)
	}
}

const (
	check = "\u2713" // ✓
	cross = "\u2717" // ✗
)

// installedPackage holds parsed manifest data for one installed package.
type installedPackage struct {
	name           string
	version        string
	enginesCnos    string
	contentClasses []string
}

// showPackages lists installed packages with name, version, content
// summary, and version drift detection.
func showPackages(hubPath, version string, stdout io.Writer) error {
	vendorDir := filepath.Join(hubPath, ".cn", "vendor", "packages")
	entries, err := os.ReadDir(vendorDir)
	if err != nil {
		if os.IsNotExist(err) {
			fmt.Fprintf(stdout, "\nNo packages installed.\n")
			return nil
		}
		return fmt.Errorf("status: read vendor dir: %w", err)
	}

	var packages []installedPackage
	for _, entry := range entries {
		if !entry.IsDir() {
			continue
		}
		dirName := entry.Name()
		pkgDir := filepath.Join(vendorDir, dirName)
		manifestPath := filepath.Join(pkgDir, "cn.package.json")
		data, err := os.ReadFile(manifestPath)
		if err != nil {
			// Skip dirs without a manifest — not a valid package.
			continue
		}
		manifest, err := pkg.ParseFullManifestData(data)
		if err != nil {
			continue
		}
		// Content classes are discovered from filesystem presence, not
		// manifest JSON fields (PACKAGE-SYSTEM.md §3). This is the same
		// authority used by `cn build --check` via pkgbuild.FindContentClasses.
		packages = append(packages, installedPackage{
			name:           manifest.Name,
			version:        manifest.Version,
			enginesCnos:    manifest.Engines.Cnos,
			contentClasses: pkgbuild.FindContentClasses(pkgDir),
		})
	}

	if len(packages) == 0 {
		fmt.Fprintf(stdout, "\nNo packages installed.\n")
		return nil
	}

	// Sort by name for deterministic output (eng/go §2.13).
	slices.SortFunc(packages, func(a, b installedPackage) int {
		return strings.Compare(a.name, b.name)
	})

	fmt.Fprintf(stdout, "\nInstalled packages:\n")
	hasDrift := false
	for _, p := range packages {
		content := ""
		if len(p.contentClasses) > 0 {
			content = " [" + strings.Join(p.contentClasses, ", ") + "]"
		}

		// Version drift: compare engines.cnos from manifest against
		// the running binary version. If engines.cnos is set and does
		// not match, flag drift.
		if version != "" && p.enginesCnos != "" && p.enginesCnos != version {
			hasDrift = true
			fmt.Fprintf(stdout, "  %s %s %s (engines.cnos %s, running %s)%s\n",
				cross, p.name, p.version, p.enginesCnos, version, content)
		} else {
			fmt.Fprintf(stdout, "  %s %s %s%s\n", check, p.name, p.version, content)
		}
	}

	fmt.Fprintln(stdout)
	if hasDrift {
		fmt.Fprintf(stdout, "%s version_drift version=%s\n", "\u26a0", version)
	} else {
		fmt.Fprintf(stdout, "ok version=%s\n", version)
	}

	return nil
}

// showCommands lists all registered commands grouped by tier.
func showCommands(commands []CommandInfo, stdout io.Writer) {
	if len(commands) == 0 {
		return
	}

	// Group by tier. Tier strings are stable: "kernel", "repo-local", "package".
	groups := map[string][]CommandInfo{}
	for _, c := range commands {
		groups[c.Tier] = append(groups[c.Tier], c)
	}

	tierOrder := []string{"kernel", "repo-local", "package"}

	fmt.Fprintf(stdout, "\nCommands:\n")
	for _, tier := range tierOrder {
		items, ok := groups[tier]
		if !ok || len(items) == 0 {
			continue
		}
		fmt.Fprintf(stdout, "  %s:\n", tier)
		for _, c := range items {
			suffix := ""
			if c.Package != "" {
				suffix = fmt.Sprintf(" (%s)", c.Package)
			}
			fmt.Fprintf(stdout, "    %-16s %s%s\n", c.Name, c.Summary, suffix)
		}
	}
}
