# Self-Coherence: v3.34.0 (#161, #156 Steps 1-3)

## Alpha (type-level clarity)

### Issue #161

- `Cn_sha256.lookup_checksum : body:string -> binary:string -> string option` — pure parsing.
- `Cn_sha256.verify_file_checksum : checksums_body:string -> binary:string -> file_contents:string -> [`Valid | `Mismatch | `No_checksum]` — pure verification.
- `verify_checksum` in cn_agent.ml: I/O wrapper returning polymorphic variant.
- Named parameters prevent argument transposition.

### Issue #156

New types in `cn_placement.ml`:
- `mode = Standalone | Attached` — exhaustive, no string matching at call sites.
- `backend_kind = Nested_clone | Submodule` — future backends extend this variant.
- `backend = { kind; remote }` — backend metadata.
- `placement = { mode; hub_root; workspace_root; backend }` — the core record.
- `parse_manifest : string -> placement option` — total (returns None on any error).
- `resolve : discovery_root:string -> placement -> placement` — converts relative paths to absolute.
- `find_placement : string -> placement option` — checks filesystem for manifest.
- `standalone : string -> placement` — standalone fallback constructor.
- `discover : string -> placement option` — new in cn_hub.ml, placement-aware walk.

All functions are total — no exceptions escape. Invalid manifests return None.

## Beta (authority surface agreement)

### Checksum (#161)

- The checksums.txt format matches `sha256sum` output (used by release.yml).
- `lookup_checksum` parses both single-space and double-space separators.
- `do_update` gates on checksum before `--version`, matching the installer order.

### Placement (#156)

- The manifest schema (`cn.hub_placement.v1`) matches the design doc spec exactly.
- `discover` checks placement manifest before legacy markers — manifest is authoritative when present.
- Legacy `find_hub_path` preserved and still callable — no breaking change.
- `cn.ml` extracts `hub_root` for all existing callers — standalone behavior unchanged.
- `_workspace_root` is bound but unused — honest about incremental threading.

### Cross-surface

- Both issues use the established pattern: pure logic in testable modules, I/O in wrappers.
- Both maintain backward compatibility (missing checksums → warn; missing manifest → standalone).

## Gamma (cycle economics)

### New files
- `src/cmd/cn_placement.ml`: 107 lines (types + parsing + resolution)
- `test/cmd/cn_placement_test.ml`: ~120 lines (11 tests)

### Modified files
- `src/lib/cn_sha256.ml`: +24 lines (2 functions)
- `src/cmd/cn_agent.ml`: +22 lines net (verification gate)
- `src/cmd/cn_hub.ml`: +25 lines (discover function + docstrings)
- `src/cli/cn.ml`: +6/-3 lines (discover instead of find_hub_path)
- `test/lib/cn_sha256_test.ml`: +42 lines (6 tests)
- Build files: 2 module registrations

### Debt acknowledged
- `_workspace_root` unused in cn.ml — deferred to Steps 4-10.
- 19 workspace-targeted call sites still use `hub_path` — correct only in standalone mode. Attached mode correctness requires threading.

## Triadic Coherence Check

1. **Do all ACs trace to code?**
   - AC1-5 (#161): Yes — `verify_checksum`, `Cn_sha256.hash`, fallback warning, mismatch rejection, 6 tests.
   - AC6-11 (#156): Yes — schema in `parse_manifest`, typed record, `discover` function, `cn.ml` uses it, standalone unchanged, 11 tests.

2. **Is standalone mode a regression risk?**
   - `discover` hits the same legacy markers (`.cn/config.json`, `.cn/config.yaml`, `state/peers.md`). When no placement manifest exists, it returns `Cn_placement.standalone hub_path` which sets `hub_root = workspace_root = hub_path`. All downstream callers receive the same value they did before.

3. **Is attached mode premature?**
   - No. The manifest parser and `discover` function handle attached mode correctly. But no command creates `.cn/placement.json` yet, so it can only be tested via manual file creation or unit tests. This is intentional — the foundation lands before the `cn attach` command.

4. **Are there silent failure paths?**
   - Invalid placement manifest → `parse_manifest` returns None → `discover` falls through to legacy markers. A warning is printed.
   - Checksum download failure → `No_checksums` → warn + fallback. Not silent.
   - `read_file_contents` can raise if file is unreadable — propagates as uncaught exception, not silent.

## Exit Criteria

### Issue #161
- [x] AC1: Checksum verified in do_update
- [x] AC2: Uses Cn_sha256.hash
- [x] AC3: Backward-compatible fallback
- [x] AC4: Mismatch rejection
- [x] AC5: 6 ppx_expect tests

### Issue #156 (Steps 1-3)
- [x] AC6: Placement manifest schema
- [x] AC7: parse_manifest
- [x] AC8: discover function
- [x] AC9: cn.ml uses discover
- [x] AC10: Standalone unchanged
- [x] AC11: 11 ppx_expect tests
