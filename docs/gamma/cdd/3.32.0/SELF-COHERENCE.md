## Self-Coherence Report -- v3.32.0

**Issue:** #152 -- Audit and eliminate all legacy fallback paths in src/

### Alpha (type-level clarity)

All deleted symbols had clear types. No type ambiguity introduced or removed.

- `run_inbound` (deleted): `string -> string -> unit` -- only caller was CLI dispatch, which already routes to `Cn_runtime.run_cron`
- `feed_next_input` (deleted): `string -> bool` -- only caller was `run_inbound`
- `wake_agent` (deleted): `string -> unit` -- only caller was `run_inbound`
- `hub_flat_mindsets_path` (deleted): `string -> string` -- pure path constructor
- `hub_flat_skills_path` (deleted): `string -> string` -- pure path constructor
- `read_opt` (converted): signature unchanged (`string -> string`), behavior unchanged for success/missing cases, now logs on exception

**Alpha score: A** -- No new types. Deleted code was unambiguous. Converted code preserves type signatures.

### Beta (authority surface agreement)

| Surface | Before | After | Agreement |
|---------|--------|-------|-----------|
| CLI dispatch (cn.ml:440) | Routes `cn in` to `Cn_runtime.run_cron` | Same | yes |
| cn_agent.ml | Contains dead `run_inbound` (lines 666-787) | Deleted | yes |
| cn_runtime.ml docstring | References "Replaces previous run_inbound..." | Updated to remove reference | yes |
| cn_protocol_test.ml:611 | Comment references `run_inbound` | Updated to reference `run_cron` | yes |
| cn_assets.ml | Flat path loaders (lines 275-288, 319-326) | Deleted | yes |
| cn_assets.ml:77-81 | `hub_flat_*_path` functions | Deleted | yes |
| cn_deps.ml:163 | `collect_files_sorted` silently swallows errors | Now logs warning | yes |
| cn.ml:13 docstring | Says "(legacy: run_inbound deprecated)" | Updated to remove legacy note | yes |

**Beta score: A** -- All authority surfaces updated. No stale references to deleted code remain.

### Gamma (cycle economics)

- Audit: 17 findings across 11 files
- Dispositions: 7 remove, 6 keep, 3 convert (1 deferred -- sandbox is already fail-closed)
- Lines deleted: ~160 (cn_agent.ml) + ~25 (cn_assets.ml) = ~185 lines removed
- Lines added: ~5 (warning logging in read_opt, collect_files_sorted)
- Net: ~180 lines removed
- AC status: AC1 met (audit table in README), AC2 met (all "remove" paths deleted), AC3 met (all "keep" paths have justification), AC4 met (run_inbound deleted), AC5 already met (no diff patterns in src/)

### Pointers

| What | Where |
|------|-------|
| Audit table | docs/gamma/cdd/3.32.0/README.md |
| Deleted: run_inbound, feed_next_input, wake_agent | cn_agent.ml (was lines 269-304, 666-787; now ends at line 629) |
| Deleted: flat path loaders | cn_assets.ml (was lines 75-81, 275-288, 319-326) |
| Converted: read_opt | cn_assets.ml:77 |
| Converted: collect_files_sorted | cn_deps.ml:163 |
| Updated docstring | cn_runtime.ml:6 |
| Updated docstring | cn.ml:13 |
| Updated test comment | cn_protocol_test.ml:611 |

### Triadic Coherence Check

1. **Does every deleted function have zero callers?** Yes. `run_inbound` was not reachable from CLI dispatch. `feed_next_input` and `wake_agent` were only called from `run_inbound`. Flat path functions were only used in the deleted loader blocks.

2. **Does every "keep" path have fail-closed behavior?** Yes. `checkout_main` returns bool (caller checks). `delete_local_branch` returns bool. `release_lock` is idempotent cleanup. `extract_inbound_message` returns full content (not silent). `resolve_render` emits trace event. `load_file` warns to stderr.

3. **Does every "convert" path now log on failure?** Yes. `read_opt` logs via `Printf.eprintf`. `collect_files_sorted` logs via `Printf.eprintf`. Sandbox `validate_path` was not converted -- it's already fail-closed (returns `Error` on all failure paths).

### Exit Criteria

- [x] AC1: Audit table written with 17 findings
- [x] AC2: 7 "remove" paths deleted, no dead code
- [x] AC3: 6 "keep" paths justified with fail-closed guarantee
- [x] AC4: `run_inbound` deleted (was dead code since v3.27)
- [x] AC5: No `main...origin/` or `master...origin/` patterns in src/
