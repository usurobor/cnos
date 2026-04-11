// Package binupdate implements `cn update` — check GitHub Releases
// for a newer cnos binary, download it, verify it, and replace the
// running binary on disk.
//
// Scope (Phase 3 Slice D):
//
//   - fetch latest release metadata from the GitHub API
//   - compare version + commit against the current binary
//   - download the platform binary to <bin>.new
//   - verify SHA-256 against checksums.txt from the release
//   - atomic rename into place
//
// Explicitly out of scope for this slice (mirrors OCaml Phase 5
// territory):
//
//   - re-exec into the new binary (requires platform-specific execve)
//   - package reconciliation after binary replace (requires
//     default_manifest_for_profile in Go, not yet ported)
//   - auto-update cooldown + background self-update checks
//   - runtime.md / state auto-update + git auto-commit
//
// These belong to a later slice. The user is told to restart cn
// after a successful update.
//
// This package is cli/-boundary compliant per eng/go §2.18: all
// logic lives here, and cli/cmd_update.go is a thin wrapper.
package binupdate

import (
	"context"
	"crypto/sha256"
	"encoding/hex"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"net/http"
	"os"
	"runtime"
	"strconv"
	"strings"
	"time"
)

// defaultBaseURL is the GitHub API base for releases.
const defaultBaseURL = "https://api.github.com"

// defaultDownloadBase is the GitHub releases download base.
const defaultDownloadBase = "https://github.com"

// defaultHTTPClient matches the timeout from internal/restore/restore.go
// (mirrors OCaml curl flags: --connect-timeout 10 --max-time 300).
var defaultHTTPClient = &http.Client{Timeout: 300 * time.Second}

// Release is the minimal subset of the GitHub release payload we need.
type Release struct {
	Tag    string // version tag, e.g. "3.50.0"
	Commit string // first 7 chars of the target SHA, or "" if not a SHA
}

// Options carries runtime context for an update run.
type Options struct {
	// Version is the currently running cnos version.
	Version string
	// Commit is the currently running cnos commit short hash ("" if unknown).
	Commit string
	// Repo is the GitHub "owner/repo" — defaults to "usurobor/cnos".
	Repo string

	// CheckOnly reports the result without downloading or installing.
	CheckOnly bool

	// BinPath overrides the target binary path. If empty, the path is
	// derived from os.Executable(). Tests set this to a temp file.
	BinPath string

	Stdout io.Writer
	Stderr io.Writer

	// HTTPClient and BaseURL allow tests to point at an httptest.Server.
	// When nil/empty, real defaults are used.
	HTTPClient *http.Client
	BaseURL    string
	// DownloadBase overrides the releases download base URL (GitHub by default).
	DownloadBase string
}

// Run executes the update flow.
func Run(ctx context.Context, opts Options) error {
	if opts.Repo == "" {
		opts.Repo = "usurobor/cnos"
	}
	if opts.BaseURL == "" {
		opts.BaseURL = defaultBaseURL
	}
	if opts.DownloadBase == "" {
		opts.DownloadBase = defaultDownloadBase
	}
	client := opts.HTTPClient
	if client == nil {
		client = defaultHTTPClient
	}

	fmt.Fprintf(opts.Stdout, "→ Checking for updates...\n")
	fmt.Fprintf(opts.Stdout, "  Current version: %s", opts.Version)
	if opts.Commit != "" {
		fmt.Fprintf(opts.Stdout, " (%s)", opts.Commit)
	}
	fmt.Fprintln(opts.Stdout)

	rel, err := FetchLatestRelease(ctx, client, opts.BaseURL, opts.Repo)
	if err != nil {
		return fmt.Errorf("update: fetch latest release: %w", err)
	}

	decision := classify(opts.Version, opts.Commit, rel)
	switch decision.kind {
	case decisionUpToDate:
		fmt.Fprintf(opts.Stdout, "✓ Already up to date (%s", opts.Version)
		if opts.Commit != "" {
			fmt.Fprintf(opts.Stdout, " %s", opts.Commit)
		}
		fmt.Fprintln(opts.Stdout, ")")
		return nil

	case decisionVersionBump:
		fmt.Fprintf(opts.Stdout, "→ New version available: %s\n", rel.Tag)

	case decisionPatch:
		fmt.Fprintf(opts.Stdout, "→ Patch available: %s (commit %s → %s)\n",
			rel.Tag, opts.Commit, rel.Commit)
	}

	if opts.CheckOnly {
		fmt.Fprintln(opts.Stdout, "  (--check: skipping download)")
		return nil
	}

	return applyUpdate(ctx, client, opts, rel)
}

// applyUpdate downloads, verifies, and installs the new binary.
func applyUpdate(ctx context.Context, client *http.Client, opts Options, rel *Release) error {
	binName, err := platformBinaryName(runtime.GOOS, runtime.GOARCH)
	if err != nil {
		return fmt.Errorf("update: %w", err)
	}

	target, err := resolveBinPath(opts.BinPath)
	if err != nil {
		return fmt.Errorf("update: resolve binary path: %w", err)
	}

	// Writability check — fail fast if we cannot replace the binary.
	// Uses access on the parent directory, matching the OCaml check.
	if !dirWritable(target) {
		return fmt.Errorf("update: %s is not writable (try sudo or reinstall)", target)
	}

	downloadURL := fmt.Sprintf("%s/%s/releases/download/%s/%s",
		opts.DownloadBase, opts.Repo, rel.Tag, binName)
	tmpPath := target + ".new"

	fmt.Fprintf(opts.Stdout, "→ Downloading %s...\n", binName)
	if err := downloadBinary(ctx, client, downloadURL, tmpPath); err != nil {
		return fmt.Errorf("update: download: %w", err)
	}
	// cleanup on failure — successful install removes the tmp file via rename.
	defer os.Remove(tmpPath)

	checksumURL := fmt.Sprintf("%s/%s/releases/download/%s/checksums.txt",
		opts.DownloadBase, opts.Repo, rel.Tag)
	fmt.Fprintf(opts.Stdout, "→ Verifying checksum...\n")
	if err := verifyChecksum(ctx, client, checksumURL, binName, tmpPath); err != nil {
		return fmt.Errorf("update: %w", err)
	}

	fmt.Fprintf(opts.Stdout, "→ Installing to %s...\n", target)
	if err := installBinary(tmpPath, target); err != nil {
		return fmt.Errorf("update: install: %w", err)
	}

	fmt.Fprintf(opts.Stdout, "✓ Updated to %s\n", rel.Tag)
	fmt.Fprintln(opts.Stdout, "  Restart cn to use the new version.")
	return nil
}

// --- Decision model ---

type decisionKind int

const (
	decisionUpToDate decisionKind = iota
	decisionVersionBump
	decisionPatch
)

type updateDecision struct {
	kind decisionKind
}

// classify compares the current version/commit against the latest
// release and returns the update decision. Mirrors OCaml
// check_for_update semantics (#37: same-version patch detection).
func classify(currentVersion, currentCommit string, rel *Release) updateDecision {
	if IsNewerVersion(rel.Tag, currentVersion) {
		return updateDecision{kind: decisionVersionBump}
	}
	if rel.Commit != "" && currentCommit != "" && rel.Commit != currentCommit {
		return updateDecision{kind: decisionPatch}
	}
	return updateDecision{kind: decisionUpToDate}
}

// --- GitHub API ---

// FetchLatestRelease calls the GitHub releases/latest endpoint and
// returns the parsed tag + commit. Commit is truncated to 7 chars
// when it looks like a hex SHA; otherwise it is left empty (the
// target_commitish can be a branch name for manual releases).
func FetchLatestRelease(ctx context.Context, client *http.Client, baseURL, repo string) (*Release, error) {
	url := fmt.Sprintf("%s/repos/%s/releases/latest", baseURL, repo)
	req, err := http.NewRequestWithContext(ctx, http.MethodGet, url, nil)
	if err != nil {
		return nil, fmt.Errorf("create request: %w", err)
	}
	req.Header.Set("Accept", "application/vnd.github+json")

	resp, err := client.Do(req)
	if err != nil {
		return nil, fmt.Errorf("http get: %w", err)
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		return nil, fmt.Errorf("http status %d", resp.StatusCode)
	}

	body, err := io.ReadAll(resp.Body)
	if err != nil {
		return nil, fmt.Errorf("read body: %w", err)
	}

	var payload struct {
		TagName         string `json:"tag_name"`
		TargetCommitish string `json:"target_commitish"`
	}
	if err := json.Unmarshal(body, &payload); err != nil {
		return nil, fmt.Errorf("parse release json: %w", err)
	}
	if payload.TagName == "" {
		return nil, errors.New("release response missing tag_name")
	}

	commit := ""
	if isHexSHA(payload.TargetCommitish) {
		commit = payload.TargetCommitish[:7]
	}
	return &Release{
		Tag:    strings.TrimSpace(payload.TagName),
		Commit: commit,
	}, nil
}

// isHexSHA returns true if s looks like a full Git SHA (>= 40 hex chars).
func isHexSHA(s string) bool {
	if len(s) < 40 {
		return false
	}
	for _, c := range s {
		if !(c >= '0' && c <= '9') && !(c >= 'a' && c <= 'f') && !(c >= 'A' && c <= 'F') {
			return false
		}
	}
	return true
}

// --- Version comparison ---

// IsNewerVersion reports whether a is strictly newer than b under
// dot-separated numeric semver. Non-numeric components sort as 0.
// An unparseable or empty version is treated as older than any
// parseable one (matches OCaml Cn_lib.is_newer_version).
func IsNewerVersion(a, b string) bool {
	ta := parseVersion(a)
	tb := parseVersion(b)
	for i := 0; i < 3; i++ {
		if ta[i] > tb[i] {
			return true
		}
		if ta[i] < tb[i] {
			return false
		}
	}
	return false
}

// parseVersion returns the (major, minor, patch) tuple of a
// dot-separated version string, padding missing components with 0.
// Unparseable components become 0.
func parseVersion(v string) [3]int {
	var out [3]int
	parts := strings.Split(v, ".")
	for i := 0; i < 3 && i < len(parts); i++ {
		n, err := strconv.Atoi(parts[i])
		if err != nil {
			return [3]int{0, 0, 0}
		}
		out[i] = n
	}
	return out
}

// --- Platform detection ---

// platformBinaryName returns the release asset name for a (os, arch)
// pair. Keeping the parameters explicit makes the function pure and
// table-testable — the runtime call site passes runtime.GOOS/GOARCH.
func platformBinaryName(goos, goarch string) (string, error) {
	var os, arch string
	switch goos {
	case "linux":
		os = "linux"
	case "darwin":
		os = "macos"
	default:
		return "", fmt.Errorf("unsupported OS: %s", goos)
	}
	switch goarch {
	case "amd64":
		arch = "x64"
	case "arm64":
		arch = "arm64"
	default:
		return "", fmt.Errorf("unsupported arch: %s", goarch)
	}
	return fmt.Sprintf("cn-%s-%s", os, arch), nil
}

// --- Download ---

// downloadBinary fetches url and writes it to dest with exec bits set.
// On non-200 or IO failure, the destination file is removed before
// returning.
func downloadBinary(ctx context.Context, client *http.Client, url, dest string) error {
	req, err := http.NewRequestWithContext(ctx, http.MethodGet, url, nil)
	if err != nil {
		return fmt.Errorf("create request: %w", err)
	}
	resp, err := client.Do(req)
	if err != nil {
		return fmt.Errorf("http get: %w", err)
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		return fmt.Errorf("http status %d", resp.StatusCode)
	}

	f, err := os.OpenFile(dest, os.O_CREATE|os.O_WRONLY|os.O_TRUNC, 0755)
	if err != nil {
		return fmt.Errorf("create file: %w", err)
	}
	if _, err := io.Copy(f, resp.Body); err != nil {
		f.Close()
		os.Remove(dest)
		return fmt.Errorf("write file: %w", err)
	}
	if err := f.Close(); err != nil {
		os.Remove(dest)
		return fmt.Errorf("close file: %w", err)
	}
	return nil
}

// --- Checksum verification ---

// verifyChecksum downloads checksums.txt from checksumURL and verifies
// that the SHA-256 of the file at path matches the entry for binaryName.
// A missing entry is an error — when the kernel cannot verify, it does
// not install, matching eng/go §3.5 ("every fallback is a policy
// decision, and silent fallback is forbidden").
func verifyChecksum(ctx context.Context, client *http.Client, checksumURL, binaryName, path string) error {
	req, err := http.NewRequestWithContext(ctx, http.MethodGet, checksumURL, nil)
	if err != nil {
		return fmt.Errorf("create checksum request: %w", err)
	}
	resp, err := client.Do(req)
	if err != nil {
		return fmt.Errorf("fetch checksums: %w", err)
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		return fmt.Errorf("fetch checksums: http status %d", resp.StatusCode)
	}
	body, err := io.ReadAll(resp.Body)
	if err != nil {
		return fmt.Errorf("read checksums: %w", err)
	}

	expected, ok := lookupChecksum(body, binaryName)
	if !ok {
		return fmt.Errorf("no checksum entry for %s", binaryName)
	}

	actual, err := fileSHA256(path)
	if err != nil {
		return fmt.Errorf("compute sha256: %w", err)
	}
	if !strings.EqualFold(actual, expected) {
		return fmt.Errorf("sha256 mismatch for %s: expected %s, got %s",
			binaryName, expected, actual)
	}
	return nil
}

// lookupChecksum parses a sha256sum-formatted checksums body
// ("<hex>  <filename>" lines) and returns the hex digest for name.
func lookupChecksum(body []byte, name string) (string, bool) {
	for _, line := range strings.Split(string(body), "\n") {
		line = strings.TrimSpace(line)
		if line == "" || strings.HasPrefix(line, "#") {
			continue
		}
		fields := strings.Fields(line)
		if len(fields) < 2 {
			continue
		}
		// sha256sum tolerates a leading "*" before the filename (binary mode).
		fname := strings.TrimPrefix(fields[len(fields)-1], "*")
		if fname == name {
			return fields[0], true
		}
	}
	return "", false
}

// fileSHA256 computes the hex SHA-256 of a file.
func fileSHA256(path string) (string, error) {
	f, err := os.Open(path)
	if err != nil {
		return "", err
	}
	defer f.Close()

	h := sha256.New()
	if _, err := io.Copy(h, f); err != nil {
		return "", err
	}
	return hex.EncodeToString(h.Sum(nil)), nil
}

// --- Install ---

// installBinary renames src over dest (atomic on POSIX filesystems).
func installBinary(src, dest string) error {
	return os.Rename(src, dest)
}

// resolveBinPath returns override if set, otherwise os.Executable().
func resolveBinPath(override string) (string, error) {
	if override != "" {
		return override, nil
	}
	return os.Executable()
}

// dirWritable returns true if the directory containing path is
// writable by the current process. Used as an early guard so the
// download step does not spend time on a binary we cannot install.
func dirWritable(path string) bool {
	dir := path
	if idx := strings.LastIndex(path, string(os.PathSeparator)); idx >= 0 {
		dir = path[:idx]
	}
	return unix_W_OK(dir) == nil
}

// unix_W_OK is a minimal portable writability check. We avoid pulling
// in golang.org/x/sys to keep dependencies stdlib-only (eng/go §2.11).
func unix_W_OK(dir string) error {
	// os.Stat gives us the mode bits; we also need to know that we
	// can create a file. The cheapest portable test is to try to
	// create a temp file in the directory and remove it.
	f, err := os.CreateTemp(dir, ".cn-update-probe-*")
	if err != nil {
		return err
	}
	_ = f.Close()
	_ = os.Remove(f.Name())
	return nil
}
