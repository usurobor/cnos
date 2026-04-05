# v3.34.0: Self-update checksum verification + Hub placement foundation

**Issues:** #161 (checksum verification), #156 (hub placement models Steps 1-3)
**Branch:** claude/execute-issue-144-cdd-O6Rl3
**Parent:** 42da381 (main)
**Mode:** MCA
**Level:** L7 — boundary move: placement model introduces explicit root separation

---

## Issue #161 — Self-update checksum verification

### Gap

The `do_update` function validates downloaded binaries only via a `--version` check. The installer already verifies SHA-256 checksums since PR #160, but the self-update path does not.

### Acceptance Criteria

- **AC1:** `do_update` downloads `checksums.txt` and verifies SHA-256 before replacing the binary.
- **AC2:** Checksum computation uses `Cn_sha256.hash` (pure OCaml, no external tool).
- **AC3:** Pre-v3.33.0 releases without checksums.txt fall back to `--version` with a warning.
- **AC4:** Checksum mismatch rejects the binary with a diagnostic.
- **AC5:** Parsing logic testable in `cn_sha256.ml` with ppx_expect tests.

### File Changes

| File | Change |
|------|--------|
| `src/lib/cn_sha256.ml` | Add `lookup_checksum`, `verify_file_checksum` |
| `src/cmd/cn_agent.ml` | Add `read_file_contents`, `verify_checksum`; checksum gate in `do_update` |
| `test/lib/cn_sha256_test.ml` | 6 ppx_expect tests |

---

## Issue #156 — Hub placement foundation (Steps 1-3)

### Gap

cnos assumes `hub_root == workspace_root`. Sandboxed agents (Claude Code, Codespaces, CI) need distinct roots: hub state in one repo, workspace operations in another. The design doc (`docs/alpha/HUB-PLACEMENT-MODELS.md`) and 10-step plan exist. This cycle implements the foundation: placement manifest, discovery refactor, and CLI root split.

### Acceptance Criteria

- **AC6:** Placement manifest (`.cn/placement.json`) schema supports standalone and attached modes with backend metadata.
- **AC7:** `Cn_placement.parse_manifest` parses JSON into typed `placement` record.
- **AC8:** `Cn_hub.discover` checks for placement manifest first, falls back to legacy `find_hub_path`.
- **AC9:** `cn.ml` uses `discover` and extracts both `hub_root` and `workspace_root` from placement.
- **AC10:** Standalone mode behavior is unchanged — no regression.
- **AC11:** 11 ppx_expect tests cover manifest parsing (valid/invalid), mode resolution, and fallback.

### Design

Three layers:
1. **`cn_placement.ml`** — Types (mode, backend_kind, placement), manifest parser, resolver, standalone fallback. Pure parsing + resolution with `Cn_ffi` for I/O.
2. **`cn_hub.ml` `discover`** — Placement-aware discovery that walks up directory tree checking for `.cn/placement.json` before legacy markers.
3. **`cn.ml`** — Uses `discover` instead of `find_hub_path`. Extracts `hub_root` (used by all current callers) and `workspace_root` (available for incremental threading).

### Plan

| Step | Goal | Files |
|------|------|-------|
| 1 | Placement manifest + resolver | `src/cmd/cn_placement.ml` (new), `src/cmd/dune` |
| 2 | Hub discovery refactor | `src/cmd/cn_hub.ml` |
| 3 | CLI root split | `src/cli/cn.ml` |
| Tests | Parsing + mode + fallback | `test/cmd/cn_placement_test.ml` (new), `test/cmd/dune` |

### File Changes

| File | Change |
|------|--------|
| `src/cmd/cn_placement.ml` | New: types, `parse_manifest`, `resolve`, `find_placement`, `standalone` |
| `src/cmd/cn_hub.ml` | Add `discover` function, preserve `find_hub_path` |
| `src/cmd/dune` | Register `cn_placement` module |
| `src/cli/cn.ml` | Use `discover`, extract `hub_root`/`workspace_root` |
| `test/cmd/cn_placement_test.ml` | New: 11 ppx_expect tests |
| `test/cmd/dune` | Register `cn_placement_test` library |

### Known Debt

- Workspace-root threading to 19 downstream call sites deferred (Steps 4-10 of plan).
- `cn attach` command not yet implemented (Step 4).
- Runtime Contract integration deferred (Step 6).
- Doctor validation deferred (Step 9).

---

## CDD Trace

| Step | Artifact | Skills loaded | Decision |
|------|----------|---------------|----------|
| 0 | Issues #161, #156 | cdd | Observe: checksum gap + placement gap |
| 1 | — | cdd | Select: security + architecture foundation |
| 2 | README.md | cdd, design | Bootstrap: AC1-AC11, file changes |
| 3 | cn_sha256.ml, cn_agent.ml | cdd, ocaml | Code #161: checksum verification |
| 4 | cn_placement.ml, cn_hub.ml, cn.ml | cdd, ocaml | Code #156: placement foundation |
| 5 | cn_sha256_test.ml, cn_placement_test.ml | cdd, testing | Tests: 17 ppx_expect tests |
| 6 | SELF-COHERENCE.md | cdd | Self-coherence assessment |
| 7 | PR | cdd, review | Review gate |
