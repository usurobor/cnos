package cli

import (
	"bytes"
	"context"
	"os"
	"path/filepath"
	"testing"
)

func TestInitCreatesHub(t *testing.T) {
	// Run init in a temp dir.
	// Note: os.Chdir mutates global state and is not parallel-safe.
	// These tests must not use t.Parallel(). Acceptable because init
	// is inherently a cwd-relative operation.
	tmp := t.TempDir()
	origDir, _ := os.Getwd()
	t.Cleanup(func() { os.Chdir(origDir) })
	os.Chdir(tmp)

	var stdout, stderr bytes.Buffer
	inv := Invocation{
		Args:   []string{"testbot"},
		Stdout: &stdout,
		Stderr: &stderr,
	}

	cmd := &InitCmd{}
	if err := cmd.Run(context.Background(), inv); err != nil {
		t.Fatalf("init: %v\nstderr: %s", err, stderr.String())
	}

	hubDir := filepath.Join(tmp, "cn-testbot")

	// Check directory structure.
	for _, d := range []string{".cn", "spec", "state", "threads/in", "logs", "agent"} {
		if _, err := os.Stat(filepath.Join(hubDir, d)); err != nil {
			t.Errorf("missing directory: %s", d)
		}
	}

	// Check config.json.
	configPath := filepath.Join(hubDir, ".cn", "config.json")
	data, err := os.ReadFile(configPath)
	if err != nil {
		t.Fatalf("read config: %v", err)
	}
	if !bytes.Contains(data, []byte(`"name": "testbot"`)) {
		t.Errorf("config missing name: %s", string(data))
	}

	// Check SOUL.md.
	soul, err := os.ReadFile(filepath.Join(hubDir, "spec", "SOUL.md"))
	if err != nil {
		t.Fatalf("read SOUL.md: %v", err)
	}
	if !bytes.Contains(soul, []byte("testbot")) {
		t.Error("SOUL.md missing hub name")
	}

	// Check success message.
	if !bytes.Contains(stdout.Bytes(), []byte("✓ Hub initialized")) {
		t.Error("expected success message in stdout")
	}
}

func TestInitAlreadyExists(t *testing.T) {
	tmp := t.TempDir()
	origDir, _ := os.Getwd()
	t.Cleanup(func() { os.Chdir(origDir) })
	os.Chdir(tmp)

	// Pre-create the directory.
	os.MkdirAll(filepath.Join(tmp, "cn-existing"), 0755)

	var stdout, stderr bytes.Buffer
	inv := Invocation{
		Args:   []string{"existing"},
		Stdout: &stdout,
		Stderr: &stderr,
	}

	cmd := &InitCmd{}
	err := cmd.Run(context.Background(), inv)
	if err == nil {
		t.Fatal("expected error for existing directory")
	}
	if !bytes.Contains(stderr.Bytes(), []byte("already exists")) {
		t.Error("expected 'already exists' in stderr")
	}
}
