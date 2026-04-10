package doctor

import (
	"context"
	"encoding/json"
	"os"
	"path/filepath"
	"strings"
	"testing"
)

func TestRunAllHealthyHub(t *testing.T) {
	hub := makeTestHub(t)
	checks := RunAll(context.Background(), hub, "3.48.0")

	if len(checks) == 0 {
		t.Fatal("expected checks")
	}

	// Hub-structure checks should pass for makeTestHub.
	for _, ch := range checks {
		if ch.Name == ".cn/config" && !ch.Passed {
			t.Error(".cn/config should pass")
		}
		if ch.Name == "spec/SOUL.md" && !ch.Passed {
			t.Error("spec/SOUL.md should pass")
		}
	}
}

func TestRunAllMissingConfig(t *testing.T) {
	hub := t.TempDir()
	os.MkdirAll(filepath.Join(hub, ".cn"), 0755)

	checks := RunAll(context.Background(), hub, "3.48.0")

	found := false
	for _, ch := range checks {
		if ch.Name == ".cn/config" && !ch.Passed {
			found = true
		}
	}
	if !found {
		t.Error("expected .cn/config check to fail")
	}
}

func TestRunAllPackageDrift(t *testing.T) {
	hub := makeTestHub(t)
	os.MkdirAll(filepath.Join(hub, ".cn", "vendor", "packages", "cnos.core@3.40.0"), 0755)

	checks := RunAll(context.Background(), hub, "3.48.0")

	found := false
	for _, ch := range checks {
		if ch.Name == "packages" && strings.Contains(ch.Value, "version drift") {
			found = true
		}
	}
	if !found {
		t.Error("expected version drift in packages check")
	}
}

func TestRunAllRuntimeContract(t *testing.T) {
	hub := makeTestHub(t)
	contract := map[string]any{
		"schema":    "cn.runtime_contract.v2",
		"identity":  map[string]any{"cn_version": "3.48.0"},
		"cognition": map[string]any{},
		"body":      map[string]any{},
		"medium":    map[string]any{},
	}
	contractDir := filepath.Join(hub, "state")
	os.MkdirAll(contractDir, 0755)
	data, _ := json.MarshalIndent(contract, "", "  ")
	os.WriteFile(filepath.Join(contractDir, "runtime-contract.json"), data, 0644)

	checks := RunAll(context.Background(), hub, "3.48.0")

	found := false
	for _, ch := range checks {
		if ch.Name == "runtime contract" && ch.Passed && strings.Contains(ch.Value, "identity") {
			found = true
		}
	}
	if !found {
		t.Error("expected valid runtime contract check")
	}
}

func TestRunAllIncompleteContract(t *testing.T) {
	hub := makeTestHub(t)
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

	checks := RunAll(context.Background(), hub, "3.48.0")

	found := false
	for _, ch := range checks {
		if ch.Name == "runtime contract" && !ch.Passed && strings.Contains(ch.Value, "medium") {
			found = true
		}
	}
	if !found {
		t.Error("expected incomplete contract with missing medium")
	}
}

func makeTestHub(t *testing.T) string {
	t.Helper()
	hub := t.TempDir()
	for _, d := range []string{".cn", "spec", "state", "agent"} {
		os.MkdirAll(filepath.Join(hub, d), 0755)
	}
	os.WriteFile(filepath.Join(hub, ".cn", "config.json"),
		[]byte(`{"name":"test","version":"1.0.0"}`), 0644)
	os.WriteFile(filepath.Join(hub, "spec", "SOUL.md"),
		[]byte("# SOUL\n"), 0644)
	os.WriteFile(filepath.Join(hub, "state", "peers.md"),
		[]byte("# Peers\n"), 0644)
	return hub
}
