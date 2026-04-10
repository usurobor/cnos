package cli

import (
	"bytes"
	"context"
	"encoding/json"
	"os"
	"path/filepath"
	"strings"
	"testing"
)

func TestDoctorHealthyHub(t *testing.T) {
	hub := makeTestHub(t)

	var stdout bytes.Buffer
	inv := Invocation{HubPath: hub, Stdout: &stdout, Stderr: &bytes.Buffer{}}
	cmd := &DoctorCmd{Version: "3.46.0"}

	// Doctor may return error (git remote, missing packages, etc.)
	// but should not panic.
	cmd.Run(context.Background(), inv)

	out := stdout.String()
	if !strings.Contains(out, "Checking health") {
		t.Error("expected 'Checking health' header")
	}
	if !strings.Contains(out, ".cn/config") {
		t.Error("expected .cn/config check")
	}
}

func TestDoctorMissingConfig(t *testing.T) {
	hub := t.TempDir()
	os.MkdirAll(filepath.Join(hub, ".cn"), 0755)
	// No config.json — doctor should report it.

	var stdout bytes.Buffer
	inv := Invocation{HubPath: hub, Stdout: &stdout, Stderr: &bytes.Buffer{}}
	cmd := &DoctorCmd{Version: "3.46.0"}

	cmd.Run(context.Background(), inv)

	out := stdout.String()
	if !strings.Contains(out, "✗") {
		t.Error("expected at least one ✗ for missing config")
	}
	if !strings.Contains(out, "missing") {
		t.Error("expected 'missing' in output for absent config")
	}
}

func TestDoctorPackageDrift(t *testing.T) {
	hub := makeTestHub(t)
	// Install a package with old version.
	os.MkdirAll(filepath.Join(hub, ".cn", "vendor", "packages", "cnos.core@3.40.0"), 0755)

	var stdout bytes.Buffer
	inv := Invocation{HubPath: hub, Stdout: &stdout, Stderr: &bytes.Buffer{}}
	cmd := &DoctorCmd{Version: "3.46.0"}

	cmd.Run(context.Background(), inv)

	out := stdout.String()
	if !strings.Contains(out, "version drift") {
		t.Error("expected 'version drift' for outdated package")
	}
}

func TestDoctorRuntimeContract(t *testing.T) {
	hub := makeTestHub(t)

	// Write a valid runtime contract.
	contract := map[string]any{
		"schema":    "cn.runtime_contract.v2",
		"identity":  map[string]any{"cn_version": "3.46.0"},
		"cognition": map[string]any{},
		"body":      map[string]any{},
		"medium":    map[string]any{},
	}
	contractDir := filepath.Join(hub, "state")
	os.MkdirAll(contractDir, 0755)
	data, _ := json.MarshalIndent(contract, "", "  ")
	os.WriteFile(filepath.Join(contractDir, "runtime-contract.json"), data, 0644)

	var stdout bytes.Buffer
	inv := Invocation{HubPath: hub, Stdout: &stdout, Stderr: &bytes.Buffer{}}
	cmd := &DoctorCmd{Version: "3.46.0"}

	cmd.Run(context.Background(), inv)

	out := stdout.String()
	if !strings.Contains(out, "identity + cognition + body + medium") {
		t.Error("expected valid runtime contract check")
	}
}

func TestDoctorIncompleteContract(t *testing.T) {
	hub := makeTestHub(t)

	// Write an incomplete runtime contract (missing medium).
	contract := map[string]any{
		"schema":    "cn.runtime_contract.v2",
		"identity":  map[string]any{},
		"cognition": map[string]any{},
		"body":      map[string]any{},
	}
	contractDir := filepath.Join(hub, "state")
	os.MkdirAll(contractDir, 0755)
	data, _ := json.MarshalIndent(contract, "", "  ")
	os.WriteFile(filepath.Join(contractDir, "runtime-contract.json"), data, 0644)

	var stdout bytes.Buffer
	inv := Invocation{HubPath: hub, Stdout: &stdout, Stderr: &bytes.Buffer{}}
	cmd := &DoctorCmd{Version: "3.46.0"}

	cmd.Run(context.Background(), inv)

	out := stdout.String()
	if !strings.Contains(out, "incomplete") {
		t.Error("expected 'incomplete' for missing medium layer")
	}
	if !strings.Contains(out, "medium") {
		t.Error("expected 'medium' named as missing")
	}
}

// makeTestHub creates a minimal hub structure for doctor tests.
func makeTestHub(t *testing.T) string {
	t.Helper()
	hub := t.TempDir()
	for _, d := range []string{
		".cn", "spec", "state", "agent",
	} {
		os.MkdirAll(filepath.Join(hub, d), 0755)
	}
	// config.json
	os.WriteFile(filepath.Join(hub, ".cn", "config.json"),
		[]byte(`{"name":"test","version":"1.0.0"}`), 0644)
	// SOUL.md
	os.WriteFile(filepath.Join(hub, "spec", "SOUL.md"),
		[]byte("# SOUL\n"), 0644)
	// peers.md
	os.WriteFile(filepath.Join(hub, "state", "peers.md"),
		[]byte("# Peers\n"), 0644)
	return hub
}
