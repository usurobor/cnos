package discover

import (
	"os"
	"path/filepath"
	"testing"

	"github.com/usurobor/cnos/src/go/internal/cli"
)

// makeTestHub creates a temporary hub directory with the given structure.
func makeTestHub(t *testing.T) string {
	t.Helper()
	dir := t.TempDir()

	// Create .cn/ structure.
	os.MkdirAll(filepath.Join(dir, ".cn", "vendor", "packages"), 0o755)
	os.MkdirAll(filepath.Join(dir, ".cn", "commands"), 0o755)

	return dir
}

// installTestPackage creates a fake installed package with a manifest and
// an entrypoint script.
func installTestPackage(t *testing.T, hubPath, pkgName, manifest string, commands map[string]string) {
	t.Helper()
	pkgDir := filepath.Join(hubPath, ".cn", "vendor", "packages", pkgName)
	os.MkdirAll(pkgDir, 0o755)
	os.WriteFile(filepath.Join(pkgDir, "cn.package.json"), []byte(manifest), 0o644)

	for relPath, content := range commands {
		full := filepath.Join(pkgDir, relPath)
		os.MkdirAll(filepath.Dir(full), 0o755)
		os.WriteFile(full, []byte(content), 0o755)
	}
}

func TestScanPackageCommands_Basic(t *testing.T) {
	hub := makeTestHub(t)

	manifest := `{
		"schema": "cn.package.v1",
		"name": "cnos.core",
		"version": "1.0.0",
		"commands": {
			"daily": {
				"entrypoint": "commands/daily/cn-daily",
				"summary": "Create or show today's daily reflection thread"
			},
			"save": {
				"entrypoint": "commands/save/cn-save",
				"summary": "Commit + push"
			}
		}
	}`
	installTestPackage(t, hub, "cnos.core", manifest, map[string]string{
		"commands/daily/cn-daily": "#!/bin/sh\necho daily",
		"commands/save/cn-save":   "#!/bin/sh\necho save",
	})

	cmds := ScanPackageCommands(hub)
	if len(cmds) != 2 {
		t.Fatalf("len = %d, want 2", len(cmds))
	}

	// Sorted by name (deterministic per pkg.CommandEntries).
	if cmds[0].Spec().Name != "daily" {
		t.Errorf("cmds[0].Name = %q, want %q", cmds[0].Spec().Name, "daily")
	}
	if cmds[1].Spec().Name != "save" {
		t.Errorf("cmds[1].Name = %q, want %q", cmds[1].Spec().Name, "save")
	}

	// Verify spec fields.
	spec := cmds[0].Spec()
	if spec.Source != cli.SourcePackage {
		t.Errorf("source = %q, want %q", spec.Source, cli.SourcePackage)
	}
	if spec.Tier != cli.TierPackage {
		t.Errorf("tier = %d, want %d", spec.Tier, cli.TierPackage)
	}
	if spec.Package != "cnos.core" {
		t.Errorf("package = %q, want %q", spec.Package, "cnos.core")
	}
	if !spec.NeedsHub {
		t.Error("expected NeedsHub = true")
	}
	if spec.Summary != "Create or show today's daily reflection thread" {
		t.Errorf("summary = %q, want daily summary", spec.Summary)
	}
}

func TestScanPackageCommands_NoVendorDir(t *testing.T) {
	// Non-existent hub path — should return nil, not panic.
	cmds := ScanPackageCommands("/nonexistent/path")
	if cmds != nil {
		t.Errorf("expected nil, got %d commands", len(cmds))
	}
}

func TestScanPackageCommands_MalformedManifest(t *testing.T) {
	hub := makeTestHub(t)

	// Package with invalid JSON.
	pkgDir := filepath.Join(hub, ".cn", "vendor", "packages", "bad-pkg")
	os.MkdirAll(pkgDir, 0o755)
	os.WriteFile(filepath.Join(pkgDir, "cn.package.json"), []byte("{invalid"), 0o644)

	// Package with valid JSON but no commands.
	manifest2 := `{"schema": "cn.package.v1", "name": "no-commands", "version": "1.0.0"}`
	installTestPackage(t, hub, "no-commands", manifest2, nil)

	cmds := ScanPackageCommands(hub)
	// bad-pkg is skipped, no-commands has zero commands.
	if len(cmds) != 0 {
		t.Errorf("expected 0 commands, got %d", len(cmds))
	}
}

func TestScanPackageCommands_MultiplePackages(t *testing.T) {
	hub := makeTestHub(t)

	installTestPackage(t, hub, "cnos.core", `{
		"schema": "cn.package.v1",
		"name": "cnos.core",
		"version": "1.0.0",
		"commands": {
			"daily": {"entrypoint": "commands/daily/cn-daily", "summary": "Daily reflection"}
		}
	}`, map[string]string{
		"commands/daily/cn-daily": "#!/bin/sh\necho daily",
	})

	installTestPackage(t, hub, "cnos.extra", `{
		"schema": "cn.package.v1",
		"name": "cnos.extra",
		"version": "1.0.0",
		"commands": {
			"foo": {"entrypoint": "commands/foo/cn-foo", "summary": "Foo command"}
		}
	}`, map[string]string{
		"commands/foo/cn-foo": "#!/bin/sh\necho foo",
	})

	cmds := ScanPackageCommands(hub)
	if len(cmds) != 2 {
		t.Fatalf("len = %d, want 2", len(cmds))
	}
}

func TestScanRepoLocalCommands_Basic(t *testing.T) {
	hub := makeTestHub(t)

	// Create repo-local commands.
	cmdDir := filepath.Join(hub, ".cn", "commands")
	os.WriteFile(filepath.Join(cmdDir, "cn-deploy"), []byte("#!/bin/sh\necho deploy"), 0o755)
	os.WriteFile(filepath.Join(cmdDir, "cn-lint"), []byte("#!/bin/sh\necho lint"), 0o755)
	// Not a command (no cn- prefix).
	os.WriteFile(filepath.Join(cmdDir, "README.md"), []byte("docs"), 0o644)

	cmds := ScanRepoLocalCommands(hub)
	if len(cmds) != 2 {
		t.Fatalf("len = %d, want 2", len(cmds))
	}

	// Verify spec.
	names := map[string]bool{}
	for _, cmd := range cmds {
		spec := cmd.Spec()
		names[spec.Name] = true
		if spec.Source != cli.SourceRepoLocal {
			t.Errorf("cmd %q source = %q, want %q", spec.Name, spec.Source, cli.SourceRepoLocal)
		}
		if spec.Tier != cli.TierRepoLocal {
			t.Errorf("cmd %q tier = %d, want %d", spec.Name, spec.Tier, cli.TierRepoLocal)
		}
		if !spec.NeedsHub {
			t.Errorf("cmd %q NeedsHub = false, want true", spec.Name)
		}
	}
	if !names["deploy"] || !names["lint"] {
		t.Errorf("expected deploy and lint, got %v", names)
	}
}

func TestScanRepoLocalCommands_NoDir(t *testing.T) {
	cmds := ScanRepoLocalCommands("/nonexistent/path")
	if cmds != nil {
		t.Errorf("expected nil, got %d commands", len(cmds))
	}
}

func TestScanRepoLocalCommands_SkipsDirectories(t *testing.T) {
	hub := makeTestHub(t)

	cmdDir := filepath.Join(hub, ".cn", "commands")
	os.MkdirAll(filepath.Join(cmdDir, "cn-subdir"), 0o755) // directory, not a file
	os.WriteFile(filepath.Join(cmdDir, "cn-real"), []byte("#!/bin/sh"), 0o755)

	cmds := ScanRepoLocalCommands(hub)
	if len(cmds) != 1 {
		t.Fatalf("len = %d, want 1", len(cmds))
	}
	if cmds[0].Spec().Name != "real" {
		t.Errorf("name = %q, want %q", cmds[0].Spec().Name, "real")
	}
}

func TestScanPackageCommands_PathTraversal(t *testing.T) {
	hub := makeTestHub(t)

	// Manifest with entrypoint that attempts path traversal.
	manifest := `{
		"schema": "cn.package.v1",
		"name": "evil-pkg",
		"version": "1.0.0",
		"commands": {
			"escape": {
				"entrypoint": "../../etc/malicious",
				"summary": "Should be rejected"
			},
			"good": {
				"entrypoint": "commands/good/cn-good",
				"summary": "Legit command"
			}
		}
	}`
	installTestPackage(t, hub, "evil-pkg", manifest, map[string]string{
		"commands/good/cn-good": "#!/bin/sh\necho good",
	})

	cmds := ScanPackageCommands(hub)
	// Only the "good" command should be discovered; "escape" is rejected.
	if len(cmds) != 1 {
		t.Fatalf("len = %d, want 1 (path traversal command should be rejected)", len(cmds))
	}
	if cmds[0].Spec().Name != "good" {
		t.Errorf("name = %q, want %q", cmds[0].Spec().Name, "good")
	}
}
