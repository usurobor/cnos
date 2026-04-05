# RELEASE.md

## Outcome

Coherence delta: C_Σ pending · **Level:** `L7`

Installer rewritten from 80-line bootstrap hack to production-grade product surface. Checksum verification added end-to-end (workflow generates SHA-256, installer verifies). Version detection hardened against API format changes.

## Why it matters

The installer is the first contact surface for new users. Silent failures during install (wrong platform, truncated download, corrupted binary) erode trust before the tool is even used. A robust installer with actionable errors, integrity verification, and atomic writes sets the right expectation for the tool itself.

## Changed

- **install.sh rewrite** (#158): UX helpers (ok/warn/fail with color), NO_COLOR support, cleanup trap, platform detection with actionable rejection, atomic install (same-filesystem mktemp+mv), minimum size validation, SHA-256 checksum verification against release checksums.txt.
- **Release workflow**: generates checksums.txt (SHA-256 per artifact) and uploads alongside binaries. Both release paths (curated RELEASE.md and auto-generated) include checksums.
- **Version detection**: replaced GitHub API JSON parsing with HTTP redirect-based detection (`/releases/latest` Location header). No jq/sed on JSON required.

## Validation

- `shellcheck install.sh` — clean (no warnings)
- Checksum verification tested: sha256sum (Linux) and shasum -a 256 (macOS) paths both covered
- Graceful degradation: missing checksums.txt or missing hash tool produces warning, not failure

## Known Issues

- Checksum verification requires a release with checksums.txt uploaded — first release after this change will be the first to include them.
- install.sh cannot verify its own integrity (bootstrap trust problem) — users must trust the raw.githubusercontent.com fetch.
