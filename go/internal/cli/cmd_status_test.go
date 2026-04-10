package cli

import (
	"bytes"
	"context"
	"os"
	"path/filepath"
	"strings"
	"testing"
)

func TestStatusShowsPackages(t *testing.T) {
	hub := t.TempDir()

	// Create fake installed packages.
	for _, pkg := range []string{"cnos.core@3.45.0", "cnos.eng@3.45.0"} {
		os.MkdirAll(filepath.Join(hub, ".cn", "vendor", "packages", pkg), 0755)
	}

	var stdout bytes.Buffer
	inv := Invocation{
		HubPath: hub,
		Stdout:  &stdout,
		Stderr:  &bytes.Buffer{},
	}

	cmd := &StatusCmd{Version: "3.45.0"}
	if err := cmd.Run(context.Background(), inv); err != nil {
		t.Fatalf("status: %v", err)
	}

	out := stdout.String()
	if !strings.Contains(out, "cnos.core") {
		t.Error("expected cnos.core in output")
	}
	if !strings.Contains(out, "cnos.eng") {
		t.Error("expected cnos.eng in output")
	}
	if !strings.Contains(out, "✓ 3.45.0") {
		t.Error("expected ✓ for matching version")
	}
	if strings.Contains(out, "version_drift") {
		t.Error("should not show drift when versions match")
	}
}

func TestStatusVersionDrift(t *testing.T) {
	hub := t.TempDir()
	os.MkdirAll(filepath.Join(hub, ".cn", "vendor", "packages", "cnos.core@3.42.0"), 0755)

	var stdout bytes.Buffer
	inv := Invocation{
		HubPath: hub,
		Stdout:  &stdout,
		Stderr:  &bytes.Buffer{},
	}

	cmd := &StatusCmd{Version: "3.45.0"}
	cmd.Run(context.Background(), inv)

	out := stdout.String()
	if !strings.Contains(out, "✗ 3.42.0") {
		t.Error("expected ✗ for version mismatch")
	}
	if !strings.Contains(out, "expected 3.45.0") {
		t.Error("expected drift message")
	}
	if !strings.Contains(out, "version_drift") {
		t.Error("expected version_drift warning")
	}
}

func TestStatusNoPackages(t *testing.T) {
	hub := t.TempDir()
	// No .cn/vendor/packages/ dir at all.

	var stdout bytes.Buffer
	inv := Invocation{
		HubPath: hub,
		Stdout:  &stdout,
		Stderr:  &bytes.Buffer{},
	}

	cmd := &StatusCmd{Version: "3.45.0"}
	if err := cmd.Run(context.Background(), inv); err != nil {
		t.Fatalf("status: %v", err)
	}

	if !strings.Contains(stdout.String(), "No packages installed") {
		t.Error("expected 'No packages installed' message")
	}
}
