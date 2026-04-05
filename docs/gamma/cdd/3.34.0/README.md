# Self-update checksum verification

**Issue:** #161 -- self-update should verify SHA-256 checksum before replacing binary
**Branch:** claude/execute-issue-144-cdd-O6Rl3
**Parent:** 7ee63ac (main)
**Mode:** MCA (targeted hardening)
**Level:** L6 -- security hardening of existing update pipeline

## Gap

The `do_update` function in `cn_agent.ml` validates downloaded binaries only via a `--version` check. A compromised binary that responds to `--version` could pass validation. The installer (install.sh) already verifies SHA-256 checksums since PR #160, but the self-update path does not.

## Acceptance Criteria

- **AC1:** `do_update` downloads `checksums.txt` from the release and verifies SHA-256 before replacing the binary.
- **AC2:** Checksum computation uses `Cn_sha256.hash` (pure OCaml, no external tool dependency).
- **AC3:** If `checksums.txt` is unavailable (pre-v3.33.0 releases), falls back to `--version` check with a warning — backward compatible.
- **AC4:** If checksum mismatches, rejects the binary and returns `Update_fail` with a diagnostic message.
- **AC5:** Checksum parsing logic (`lookup_checksum`, `verify_file_checksum`) is testable in `cn_sha256.ml` with ppx_expect tests.

## Design

The checksum parsing and verification logic lives in `cn_sha256.ml` (already in `cn_lib`), keeping the pure functions testable without needing `cn_cmd` or `cn_ffi` dependencies.

The `verify_checksum` wrapper in `cn_agent.ml` handles the I/O: fetching `checksums.txt` via curl, reading the downloaded file, then delegating to `Cn_sha256.verify_file_checksum`.

The `do_update` flow becomes:
1. Download binary to `bin_path.new`
2. Fetch `checksums.txt` for the release tag
3. If available: compute SHA-256 of downloaded file, compare → reject on mismatch
4. If unavailable: warn, fall back to `--version` only (backward compat)
5. Validate with `--version` (always, as a secondary check)
6. Atomic replace via `mv`

## Plan

Single-step: add verification to `do_update`, extract testable parsing into `cn_sha256.ml`, add ppx_expect tests.

## File Changes

| File | Change |
|------|--------|
| `src/lib/cn_sha256.ml` | Add `lookup_checksum`, `verify_file_checksum` |
| `src/cmd/cn_agent.ml` | Add `read_file_contents`, `verify_checksum`; insert checksum gate in `do_update` |
| `test/lib/cn_sha256_test.ml` | Add 6 ppx_expect tests: lookup match/miss/empty, verify valid/mismatch/no_checksum |

## CDD Trace

| Step | Artifact | Skills loaded | Decision |
|------|----------|---------------|----------|
| 0 | Issue #161 | cdd | Observe: self-update lacks checksum verification |
| 1 | — | cdd | Select: security gap, installer parity |
| 2 | README.md | cdd, design | Bootstrap: AC1-AC5, file changes |
| 3 | cn_sha256.ml, cn_agent.ml | cdd, ocaml | Code: implement verification |
| 4 | cn_sha256_test.ml | cdd, testing | Tests: 6 ppx_expect tests |
| 5 | SELF-COHERENCE.md | cdd | Self-coherence assessment |
| 6 | PR | cdd, review | Review gate |
