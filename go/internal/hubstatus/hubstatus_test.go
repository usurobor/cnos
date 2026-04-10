package hubstatus

import (
	"bytes"
	"os"
	"path/filepath"
	"strings"
	"testing"
)

func TestRunShowsPackages(t *testing.T) {
	hub := t.TempDir()
	for _, pkg := range []string{"cnos.core@3.48.0", "cnos.eng@3.48.0"} {
		os.MkdirAll(filepath.Join(hub, ".cn", "vendor", "packages", pkg), 0755)
	}

	var stdout bytes.Buffer
	if err := Run(hub, "3.48.0", &stdout); err != nil {
		t.Fatalf("status: %v", err)
	}

	out := stdout.String()
	if !strings.Contains(out, "cnos.core") {
		t.Error("expected cnos.core")
	}
	if !strings.Contains(out, "✓ 3.48.0") {
		t.Error("expected ✓ for matching version")
	}
}

func TestRunVersionDrift(t *testing.T) {
	hub := t.TempDir()
	os.MkdirAll(filepath.Join(hub, ".cn", "vendor", "packages", "cnos.core@3.42.0"), 0755)

	var stdout bytes.Buffer
	Run(hub, "3.48.0", &stdout)

	out := stdout.String()
	if !strings.Contains(out, "✗ 3.42.0") {
		t.Error("expected ✗ for mismatch")
	}
	if !strings.Contains(out, "version_drift") {
		t.Error("expected version_drift warning")
	}
}

func TestRunNoPackages(t *testing.T) {
	hub := t.TempDir()

	var stdout bytes.Buffer
	if err := Run(hub, "3.48.0", &stdout); err != nil {
		t.Fatalf("status: %v", err)
	}

	if !strings.Contains(stdout.String(), "No packages installed") {
		t.Error("expected 'No packages installed'")
	}
}
