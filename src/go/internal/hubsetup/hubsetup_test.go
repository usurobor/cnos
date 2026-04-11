package hubsetup

import (
	"bytes"
	"context"
	"encoding/json"
	"os"
	"path/filepath"
	"strings"
	"testing"
)

// newTempHub returns a tmp directory that is ready to be treated as a hub.
// The caller decides which files pre-exist — only the top-level dir is
// created so each test can assert whether Run creates the expected shape.
func newTempHub(t *testing.T) string {
	t.Helper()
	return t.TempDir()
}

func TestRunEnsuresDirectories(t *testing.T) {
	hub := newTempHub(t)

	var stdout, stderr bytes.Buffer
	err := Run(context.Background(), Options{
		HubPath: hub,
		Version: "3.50.0",
		Stdout:  &stdout,
		Stderr:  &stderr,
	})
	if err != nil {
		t.Fatalf("Run: %v\nstderr: %s", err, stderr.String())
	}

	for _, d := range []string{".cn", "agent"} {
		info, err := os.Stat(filepath.Join(hub, d))
		if err != nil {
			t.Errorf("missing directory %s: %v", d, err)
			continue
		}
		if !info.IsDir() {
			t.Errorf("%s exists but is not a directory", d)
		}
	}
}

func TestRunWritesDefaultDeps(t *testing.T) {
	hub := newTempHub(t)

	var stdout, stderr bytes.Buffer
	if err := Run(context.Background(), Options{
		HubPath: hub,
		Version: "3.50.0",
		Stdout:  &stdout,
		Stderr:  &stderr,
	}); err != nil {
		t.Fatalf("Run: %v\nstderr: %s", err, stderr.String())
	}

	depsPath := filepath.Join(hub, ".cn", "deps.json")
	data, err := os.ReadFile(depsPath)
	if err != nil {
		t.Fatalf("read deps.json: %v", err)
	}

	var m struct {
		Schema   string `json:"schema"`
		Profile  string `json:"profile"`
		Packages []struct {
			Name    string `json:"name"`
			Version string `json:"version"`
		} `json:"packages"`
	}
	if err := json.Unmarshal(data, &m); err != nil {
		t.Fatalf("parse deps.json: %v\n%s", err, string(data))
	}

	if m.Schema != "cn.deps.v1" {
		t.Errorf("schema = %q, want cn.deps.v1", m.Schema)
	}
	if m.Profile != "engineer" {
		t.Errorf("profile = %q, want engineer", m.Profile)
	}
	wantPackages := map[string]bool{"cnos.core": false, "cnos.eng": false}
	for _, p := range m.Packages {
		if _, ok := wantPackages[p.Name]; !ok {
			t.Errorf("unexpected package %q", p.Name)
			continue
		}
		if p.Version != "3.50.0" {
			t.Errorf("package %s version = %q, want 3.50.0", p.Name, p.Version)
		}
		wantPackages[p.Name] = true
	}
	for name, present := range wantPackages {
		if !present {
			t.Errorf("missing default package %q", name)
		}
	}
}

func TestRunPreservesExistingDeps(t *testing.T) {
	hub := newTempHub(t)

	// Pre-create a user-authored deps.json with a custom profile.
	if err := os.MkdirAll(filepath.Join(hub, ".cn"), 0755); err != nil {
		t.Fatal(err)
	}
	existing := `{"schema":"cn.deps.v1","profile":"custom","packages":[{"name":"cnos.core","version":"9.9.9"}]}`
	depsPath := filepath.Join(hub, ".cn", "deps.json")
	if err := os.WriteFile(depsPath, []byte(existing), 0644); err != nil {
		t.Fatal(err)
	}

	var stdout, stderr bytes.Buffer
	if err := Run(context.Background(), Options{
		HubPath: hub,
		Version: "3.50.0",
		Stdout:  &stdout,
		Stderr:  &stderr,
	}); err != nil {
		t.Fatalf("Run: %v\nstderr: %s", err, stderr.String())
	}

	data, err := os.ReadFile(depsPath)
	if err != nil {
		t.Fatalf("read deps.json: %v", err)
	}
	if string(data) != existing {
		t.Errorf("deps.json was overwritten\nhad:  %s\nwant: %s", string(data), existing)
	}
}

func TestRunAddsGitignoreEntry(t *testing.T) {
	hub := newTempHub(t)

	var stdout, stderr bytes.Buffer
	if err := Run(context.Background(), Options{
		HubPath: hub,
		Version: "3.50.0",
		Stdout:  &stdout,
		Stderr:  &stderr,
	}); err != nil {
		t.Fatalf("Run: %v\nstderr: %s", err, stderr.String())
	}

	data, err := os.ReadFile(filepath.Join(hub, ".gitignore"))
	if err != nil {
		t.Fatalf("read .gitignore: %v", err)
	}
	if !strings.Contains(string(data), ".cn/vendor/") {
		t.Errorf(".gitignore missing .cn/vendor/ entry:\n%s", string(data))
	}
}

func TestRunPreservesExistingGitignore(t *testing.T) {
	hub := newTempHub(t)

	// Pre-existing .gitignore with its own content.
	original := "node_modules/\ndist/\n"
	if err := os.WriteFile(filepath.Join(hub, ".gitignore"), []byte(original), 0644); err != nil {
		t.Fatal(err)
	}

	var stdout, stderr bytes.Buffer
	if err := Run(context.Background(), Options{
		HubPath: hub,
		Version: "3.50.0",
		Stdout:  &stdout,
		Stderr:  &stderr,
	}); err != nil {
		t.Fatalf("Run: %v\nstderr: %s", err, stderr.String())
	}

	data, err := os.ReadFile(filepath.Join(hub, ".gitignore"))
	if err != nil {
		t.Fatalf("read .gitignore: %v", err)
	}
	content := string(data)
	if !strings.Contains(content, "node_modules/") {
		t.Error(".gitignore lost prior entry: node_modules/")
	}
	if !strings.Contains(content, "dist/") {
		t.Error(".gitignore lost prior entry: dist/")
	}
	if !strings.Contains(content, ".cn/vendor/") {
		t.Error(".gitignore missing new entry: .cn/vendor/")
	}
}

func TestRunGitignoreIdempotent(t *testing.T) {
	hub := newTempHub(t)

	// Second run should not duplicate the .cn/vendor/ line.
	var stdout1, stderr1 bytes.Buffer
	if err := Run(context.Background(), Options{
		HubPath: hub,
		Version: "3.50.0",
		Stdout:  &stdout1,
		Stderr:  &stderr1,
	}); err != nil {
		t.Fatalf("Run (first): %v", err)
	}

	var stdout2, stderr2 bytes.Buffer
	if err := Run(context.Background(), Options{
		HubPath: hub,
		Version: "3.50.0",
		Stdout:  &stdout2,
		Stderr:  &stderr2,
	}); err != nil {
		t.Fatalf("Run (second): %v", err)
	}

	data, _ := os.ReadFile(filepath.Join(hub, ".gitignore"))
	count := strings.Count(string(data), ".cn/vendor/")
	if count != 1 {
		t.Errorf(".cn/vendor/ appeared %d time(s) in .gitignore, want 1:\n%s", count, string(data))
	}
}

func TestRunMissingHubPath(t *testing.T) {
	var stdout, stderr bytes.Buffer
	err := Run(context.Background(), Options{
		HubPath: "",
		Version: "3.50.0",
		Stdout:  &stdout,
		Stderr:  &stderr,
	})
	if err == nil {
		t.Fatal("expected error when HubPath is empty")
	}
	if !strings.Contains(err.Error(), "hub") {
		t.Errorf("error should mention hub: %v", err)
	}
}

func TestRunPrintsNextSteps(t *testing.T) {
	hub := newTempHub(t)

	var stdout, stderr bytes.Buffer
	if err := Run(context.Background(), Options{
		HubPath: hub,
		Version: "3.50.0",
		Stdout:  &stdout,
		Stderr:  &stderr,
	}); err != nil {
		t.Fatalf("Run: %v", err)
	}

	out := stdout.String()
	if !strings.Contains(out, "cn deps restore") {
		t.Errorf("expected guidance to run 'cn deps restore':\n%s", out)
	}
}
