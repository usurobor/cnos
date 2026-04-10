package hubinit

import (
	"bytes"
	"context"
	"os"
	"path/filepath"
	"testing"
)

func TestRunCreatesHub(t *testing.T) {
	tmp := t.TempDir()
	origDir, _ := os.Getwd()
	t.Cleanup(func() { os.Chdir(origDir) })
	os.Chdir(tmp)

	var stdout, stderr bytes.Buffer
	if err := Run(context.Background(), "testbot", &stdout, &stderr); err != nil {
		t.Fatalf("init: %v\nstderr: %s", err, stderr.String())
	}

	hubDir := filepath.Join(tmp, "cn-testbot")
	for _, d := range []string{".cn", "spec", "state", "threads/in", "logs", "agent"} {
		if _, err := os.Stat(filepath.Join(hubDir, d)); err != nil {
			t.Errorf("missing directory: %s", d)
		}
	}

	data, err := os.ReadFile(filepath.Join(hubDir, ".cn", "config.json"))
	if err != nil {
		t.Fatalf("read config: %v", err)
	}
	if !bytes.Contains(data, []byte(`"name": "testbot"`)) {
		t.Errorf("config missing name: %s", string(data))
	}

	if !bytes.Contains(stdout.Bytes(), []byte("✓ Hub initialized")) {
		t.Error("expected success message")
	}
}

func TestRunAlreadyExists(t *testing.T) {
	tmp := t.TempDir()
	origDir, _ := os.Getwd()
	t.Cleanup(func() { os.Chdir(origDir) })
	os.Chdir(tmp)

	os.MkdirAll(filepath.Join(tmp, "cn-existing"), 0755)

	var stdout, stderr bytes.Buffer
	err := Run(context.Background(), "existing", &stdout, &stderr)
	if err == nil {
		t.Fatal("expected error")
	}
	if !bytes.Contains(stderr.Bytes(), []byte("already exists")) {
		t.Error("expected 'already exists' in stderr")
	}
}

func TestRunValidatesHubName(t *testing.T) {
	tests := []struct {
		name    string
		input   string
		wantErr bool
	}{
		{"valid", "sigma", false},
		{"hyphens", "my-agent", false},
		// Empty string now derives name from cwd — not an error.
		// Validation of the derived name still applies.
		{"path sep", "foo/bar", true},
		{"traversal", "../bad", true},
		{"space", "foo bar", true},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			tmp := t.TempDir()
			origDir, _ := os.Getwd()
			t.Cleanup(func() { os.Chdir(origDir) })
			os.Chdir(tmp)

			var stdout, stderr bytes.Buffer
			err := Run(context.Background(), tt.input, &stdout, &stderr)
			if tt.wantErr && err == nil {
				t.Errorf("expected error for %q", tt.input)
			}
			if !tt.wantErr && err != nil {
				t.Errorf("unexpected error for %q: %v", tt.input, err)
			}
		})
	}
}
