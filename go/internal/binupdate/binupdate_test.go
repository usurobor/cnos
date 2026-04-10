package binupdate

import (
	"bytes"
	"context"
	"crypto/sha256"
	"encoding/hex"
	"fmt"
	"net/http"
	"net/http/httptest"
	"os"
	"path/filepath"
	"strings"
	"testing"
)

// --- IsNewerVersion ---

func TestIsNewerVersion(t *testing.T) {
	tests := []struct {
		a, b  string
		newer bool
	}{
		{"3.50.0", "3.49.0", true},
		{"3.50.1", "3.50.0", true},
		{"4.0.0", "3.99.0", true},
		{"3.50.0", "3.50.0", false},
		{"3.49.0", "3.50.0", false},
		{"3.9.0", "3.10.0", false}, // semver: 3.10.0 > 3.9.0
		{"3.10.0", "3.9.0", true},
		{"dev", "3.50.0", false}, // unparseable treated as older
		{"3.50.0", "dev", true},
		{"", "3.50.0", false},
	}
	for _, tt := range tests {
		t.Run(fmt.Sprintf("%s vs %s", tt.a, tt.b), func(t *testing.T) {
			got := IsNewerVersion(tt.a, tt.b)
			if got != tt.newer {
				t.Errorf("IsNewerVersion(%q, %q) = %v, want %v", tt.a, tt.b, got, tt.newer)
			}
		})
	}
}

// --- platformBinaryName (pure helper over an OS/arch pair) ---

func TestPlatformBinaryName(t *testing.T) {
	tests := []struct {
		os, arch string
		want     string
		wantErr  bool
	}{
		{"linux", "amd64", "cn-linux-x64", false},
		{"linux", "arm64", "cn-linux-arm64", false},
		{"darwin", "amd64", "cn-macos-x64", false},
		{"darwin", "arm64", "cn-macos-arm64", false},
		{"windows", "amd64", "", true},
		{"linux", "386", "", true},
		{"", "", "", true},
	}
	for _, tt := range tests {
		t.Run(tt.os+"/"+tt.arch, func(t *testing.T) {
			got, err := platformBinaryName(tt.os, tt.arch)
			if tt.wantErr {
				if err == nil {
					t.Errorf("want error, got %q", got)
				}
				return
			}
			if err != nil {
				t.Errorf("unexpected error: %v", err)
			}
			if got != tt.want {
				t.Errorf("got %q, want %q", got, tt.want)
			}
		})
	}
}

// --- FetchLatestRelease against an httptest server ---

func TestFetchLatestReleaseParsesTagAndCommit(t *testing.T) {
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if r.URL.Path != "/repos/owner/repo/releases/latest" {
			http.NotFound(w, r)
			return
		}
		w.Header().Set("Content-Type", "application/json")
		fmt.Fprint(w, `{
			"tag_name": "3.50.0",
			"target_commitish": "abc1234def5678901234567890abcdef12345678"
		}`)
	}))
	defer srv.Close()

	rel, err := FetchLatestRelease(context.Background(), srv.Client(), srv.URL, "owner/repo")
	if err != nil {
		t.Fatalf("FetchLatestRelease: %v", err)
	}
	if rel.Tag != "3.50.0" {
		t.Errorf("Tag = %q, want 3.50.0", rel.Tag)
	}
	// Commit is truncated to 7 characters when it looks like a hex SHA.
	if rel.Commit != "abc1234" {
		t.Errorf("Commit = %q, want abc1234", rel.Commit)
	}
}

func TestFetchLatestReleaseIgnoresNonSHACommitish(t *testing.T) {
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		fmt.Fprint(w, `{"tag_name": "3.50.0", "target_commitish": "main"}`)
	}))
	defer srv.Close()

	rel, err := FetchLatestRelease(context.Background(), srv.Client(), srv.URL, "owner/repo")
	if err != nil {
		t.Fatalf("FetchLatestRelease: %v", err)
	}
	if rel.Commit != "" {
		t.Errorf("Commit = %q, want empty (branch name, not SHA)", rel.Commit)
	}
}

func TestFetchLatestReleaseHTTPError(t *testing.T) {
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		http.Error(w, "rate limited", http.StatusTooManyRequests)
	}))
	defer srv.Close()

	_, err := FetchLatestRelease(context.Background(), srv.Client(), srv.URL, "owner/repo")
	if err == nil {
		t.Fatal("expected error on 429 response")
	}
}

func TestFetchLatestReleaseMalformedJSON(t *testing.T) {
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		fmt.Fprint(w, `{not json`)
	}))
	defer srv.Close()

	_, err := FetchLatestRelease(context.Background(), srv.Client(), srv.URL, "owner/repo")
	if err == nil {
		t.Fatal("expected error on malformed JSON")
	}
}

func TestFetchLatestReleaseMissingTag(t *testing.T) {
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		fmt.Fprint(w, `{"target_commitish": "abc1234def5678901234567890abcdef12345678"}`)
	}))
	defer srv.Close()

	_, err := FetchLatestRelease(context.Background(), srv.Client(), srv.URL, "owner/repo")
	if err == nil {
		t.Fatal("expected error on missing tag_name")
	}
}

// --- downloadBinary atomic flow ---

func TestDownloadBinary(t *testing.T) {
	content := []byte("fake-binary-bytes-0123456789")
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.Write(content)
	}))
	defer srv.Close()

	dest := filepath.Join(t.TempDir(), "cn.new")
	if err := downloadBinary(context.Background(), srv.Client(), srv.URL, dest); err != nil {
		t.Fatalf("downloadBinary: %v", err)
	}

	got, err := os.ReadFile(dest)
	if err != nil {
		t.Fatalf("read downloaded file: %v", err)
	}
	if !bytes.Equal(got, content) {
		t.Errorf("downloaded bytes mismatch")
	}

	// File should be executable.
	info, err := os.Stat(dest)
	if err != nil {
		t.Fatal(err)
	}
	if info.Mode()&0100 == 0 {
		t.Errorf("downloaded binary is not executable: mode=%v", info.Mode())
	}
}

func TestDownloadBinaryHTTPError(t *testing.T) {
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		http.Error(w, "not found", http.StatusNotFound)
	}))
	defer srv.Close()

	dest := filepath.Join(t.TempDir(), "cn.new")
	err := downloadBinary(context.Background(), srv.Client(), srv.URL, dest)
	if err == nil {
		t.Fatal("expected error on 404")
	}
	// Temp file should not be left behind on failure.
	if _, statErr := os.Stat(dest); statErr == nil {
		t.Errorf("partial download file was left behind: %s", dest)
	}
}

// --- verifyChecksum against a synthesized checksums.txt ---

func TestVerifyChecksumMatch(t *testing.T) {
	// Create a real file, compute its SHA, and construct a checksums body.
	content := []byte("binary payload")
	path := filepath.Join(t.TempDir(), "cn-linux-x64")
	if err := os.WriteFile(path, content, 0755); err != nil {
		t.Fatal(err)
	}
	sum := sha256.Sum256(content)
	hexSum := hex.EncodeToString(sum[:])
	body := fmt.Sprintf("%s  cn-linux-x64\n%s  cn-macos-x64\n", hexSum, strings.Repeat("0", 64))

	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		fmt.Fprint(w, body)
	}))
	defer srv.Close()

	err := verifyChecksum(context.Background(), srv.Client(), srv.URL, "cn-linux-x64", path)
	if err != nil {
		t.Errorf("verifyChecksum: %v", err)
	}
}

func TestVerifyChecksumMismatch(t *testing.T) {
	path := filepath.Join(t.TempDir(), "cn-linux-x64")
	if err := os.WriteFile(path, []byte("binary payload"), 0755); err != nil {
		t.Fatal(err)
	}
	// Wrong expected hash.
	body := strings.Repeat("0", 64) + "  cn-linux-x64\n"
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		fmt.Fprint(w, body)
	}))
	defer srv.Close()

	err := verifyChecksum(context.Background(), srv.Client(), srv.URL, "cn-linux-x64", path)
	if err == nil {
		t.Fatal("expected checksum mismatch error")
	}
	if !strings.Contains(err.Error(), "mismatch") {
		t.Errorf("error should mention mismatch: %v", err)
	}
}

func TestVerifyChecksumMissingEntry(t *testing.T) {
	path := filepath.Join(t.TempDir(), "cn-linux-x64")
	if err := os.WriteFile(path, []byte("binary payload"), 0755); err != nil {
		t.Fatal(err)
	}
	// checksums.txt does not mention our binary.
	body := strings.Repeat("0", 64) + "  other-binary\n"
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		fmt.Fprint(w, body)
	}))
	defer srv.Close()

	err := verifyChecksum(context.Background(), srv.Client(), srv.URL, "cn-linux-x64", path)
	if err == nil {
		t.Fatal("expected error when checksum entry is missing")
	}
}

// --- installBinary atomic rename ---

func TestInstallBinaryAtomicReplace(t *testing.T) {
	dir := t.TempDir()
	dest := filepath.Join(dir, "cn")
	src := filepath.Join(dir, "cn.new")

	// Pre-existing "installed" binary.
	if err := os.WriteFile(dest, []byte("old"), 0755); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(src, []byte("new"), 0755); err != nil {
		t.Fatal(err)
	}

	if err := installBinary(src, dest); err != nil {
		t.Fatalf("installBinary: %v", err)
	}

	got, err := os.ReadFile(dest)
	if err != nil {
		t.Fatal(err)
	}
	if string(got) != "new" {
		t.Errorf("dest = %q, want %q", string(got), "new")
	}

	// src should be gone after atomic rename.
	if _, err := os.Stat(src); err == nil {
		t.Error("src file still exists after rename")
	}
}

// --- Run (check-only mode) ---

func TestRunCheckOnlyUpToDate(t *testing.T) {
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		fmt.Fprint(w, `{"tag_name": "3.50.0", "target_commitish": "abc1234def5678901234567890abcdef12345678"}`)
	}))
	defer srv.Close()

	var stdout, stderr bytes.Buffer
	err := Run(context.Background(), Options{
		Version:    "3.50.0",
		Commit:     "abc1234",
		Repo:       "owner/repo",
		CheckOnly:  true,
		Stdout:     &stdout,
		Stderr:     &stderr,
		HTTPClient: srv.Client(),
		BaseURL:    srv.URL,
	})
	if err != nil {
		t.Fatalf("Run: %v\nstderr: %s", err, stderr.String())
	}
	if !strings.Contains(stdout.String(), "up to date") {
		t.Errorf("expected 'up to date' in stdout:\n%s", stdout.String())
	}
}

func TestRunCheckOnlyAvailable(t *testing.T) {
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		fmt.Fprint(w, `{"tag_name": "3.51.0", "target_commitish": "fedcba9876543210fedcba9876543210fedcba98"}`)
	}))
	defer srv.Close()

	var stdout, stderr bytes.Buffer
	err := Run(context.Background(), Options{
		Version:    "3.50.0",
		Commit:     "abc1234",
		Repo:       "owner/repo",
		CheckOnly:  true,
		Stdout:     &stdout,
		Stderr:     &stderr,
		HTTPClient: srv.Client(),
		BaseURL:    srv.URL,
	})
	if err != nil {
		t.Fatalf("Run: %v\nstderr: %s", err, stderr.String())
	}
	out := stdout.String()
	if !strings.Contains(out, "3.51.0") {
		t.Errorf("expected new version in stdout:\n%s", out)
	}
	if !strings.Contains(out, "available") {
		t.Errorf("expected 'available' in stdout:\n%s", out)
	}
}

func TestRunCheckOnlySameVersionPatch(t *testing.T) {
	// Same tag, different commit hash — OCaml treats this as a patch.
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		fmt.Fprint(w, `{"tag_name": "3.50.0", "target_commitish": "fedcba9876543210fedcba9876543210fedcba98"}`)
	}))
	defer srv.Close()

	var stdout, stderr bytes.Buffer
	err := Run(context.Background(), Options{
		Version:    "3.50.0",
		Commit:     "abc1234",
		Repo:       "owner/repo",
		CheckOnly:  true,
		Stdout:     &stdout,
		Stderr:     &stderr,
		HTTPClient: srv.Client(),
		BaseURL:    srv.URL,
	})
	if err != nil {
		t.Fatalf("Run: %v", err)
	}
	out := strings.ToLower(stdout.String())
	if !strings.Contains(out, "patch") {
		t.Errorf("expected 'patch' in stdout:\n%s", stdout.String())
	}
}

func TestRunCheckOnlyFetchError(t *testing.T) {
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		http.Error(w, "down", http.StatusInternalServerError)
	}))
	defer srv.Close()

	var stdout, stderr bytes.Buffer
	err := Run(context.Background(), Options{
		Version:    "3.50.0",
		Commit:     "abc1234",
		Repo:       "owner/repo",
		CheckOnly:  true,
		Stdout:     &stdout,
		Stderr:     &stderr,
		HTTPClient: srv.Client(),
		BaseURL:    srv.URL,
	})
	if err == nil {
		t.Fatal("expected error on fetch failure")
	}
}
