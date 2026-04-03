## CDD Bootstrap -- v3.32.0

**Issue:** #152 -- Audit and eliminate all legacy fallback paths in src/
**Branch:** claude/execute-issue-152-cdd-O6Rl3
**Parent:** v3.31.0 (af4cf01)
**Mode:** MCA (targeted audit + cleanup)

### Gap

The codebase contains legacy code paths retained for backward compatibility
whose failed preconditions can silently degrade behavior. #150 proved the
worst case (stale-diff content swap). No systematic audit has been done.

### Acceptance Criteria

- AC1: Full audit table (file, symbol, why legacy, failure mode, risk, disposition, justification, expiry)
- AC2: Every "remove" path deleted, no dead code
- AC3: Every "keep" path has justification + fail-closed guarantee + expiry
- AC4: `run_inbound` removed or justified with concrete expiry
- AC5: No `main...origin/` or `master...origin/` diff patterns remain

### AC1: Audit Table

| # | File | Symbol | Why legacy | Failure mode | Risk | Disposition | Justification | Expiry |
|---|------|--------|-----------|--------------|------|-------------|---------------|--------|
| 1 | cn_agent.ml:672 | `run_inbound` | Deprecated actor loop, replaced by `Cn_runtime.run_cron` | Executes full old pipeline (queue, FSM, LLM) on deprecated path; warns but does not fail | high | **remove** | Dead code -- no CLI path reaches it (`cn in` routes to `Cn_runtime.run_cron` since v3.27) | -- |
| 2 | cn_agent.ml:303 | `wake_agent` | Deprecated no-op, prints warning | No-op with warning; called only from `run_inbound` | high | **remove** | Dead code -- only caller is `run_inbound` (also being removed) | -- |
| 3 | cn_agent.ml:273 | `feed_next_input` | Deprecated queue feeder, replaced by `Cn_runtime.process_one` | Writes to state/input.md on deprecated path | high | **remove** | Dead code -- only caller is `run_inbound` | -- |
| 4 | cn_assets.ml:77 | `hub_flat_mindsets_path` | Pre-package namespace compat (`agent/mindsets/*.md` without package dir) | Silently loads flat overrides into `cnos.core` namespace; `with _ -> ()` swallows all errors | medium | **remove** | Package namespace has been the only supported layout since v3.25. No known hubs use flat layout. Migration grace period expired. | -- |
| 5 | cn_assets.ml:80 | `hub_flat_skills_path` | Pre-package namespace compat (`agent/skills/...` without package dir) | Silently loads flat overrides into `cnos.core` namespace | medium | **remove** | Same as #4 | -- |
| 6 | cn_assets.ml:275-288 | flat mindset loader block | Backward compat block using `hub_flat_mindsets_path` | `with _ -> ()` swallows all read errors silently | medium | **remove** | Removing with #4 | -- |
| 7 | cn_assets.ml:319-326 | flat skill loader block | Backward compat block using `hub_flat_skills_path` | Loads skills into wrong namespace silently if directory exists | medium | **remove** | Removing with #5 | -- |
| 8 | git.ml:108 | `checkout_create` | Creates or switches to branch; `2>/dev/null` suppresses first-attempt error | If both `-b` and checkout fail, returns false -- caller handles | low | **keep** | Legitimate two-step git operation (create-or-switch). Caller checks return value. Not a legacy compat path -- it's a correct "try create, else switch" pattern. | permanent |
| 9 | git.ml:112 | `checkout_main` | `main` vs `master` fallback | If both fail, returns false -- caller handles | low | **keep** | Active backward compat for repos initialized before `main` convention. Caller (`cn_io.ml:138`) checks return. Fail-closed: false return propagates. | until main-only policy adopted |
| 10 | git.ml:115 | `delete_local_branch` | `2>/dev/null` on branch -D | If delete fails, returns false | low | **keep** | Idempotent cleanup. Suppressing "not found" is correct behavior. Caller checks return. | permanent |
| 11 | cn_assets.ml:85-88 | `read_opt` | `with _ -> ""` swallows all exceptions | File exists but unreadable -> returns "" silently (permission errors, I/O errors hidden) | medium | **convert** | Change to log warning on exception instead of silent swallow. Keep fallback to "" (missing is OK, unreadable should warn). | -- |
| 12 | cn_runtime.ml:57-59 | `release_lock` | `with _ -> ()` on close/unlink | Lock cleanup errors suppressed | none | **keep** | Idempotent cleanup must not fail. Trace event emitted regardless. Standard pattern for lock release. | permanent |
| 13 | cn_runtime.ml:86 | `extract_inbound_message` | Falls back to full packed_body when marker not found | Returns full content instead of parsed body | low | **keep** | Defensive: if structure unexpected, return everything rather than nothing. Not silent -- the fallback IS the content. | permanent |
| 14 | cn_runtime.ml:98-106 | `resolve_render` Fallback arm | Render fallback with trace event | Logs degradation via `Cn_trace.gemit` at Warn/Degraded | none | **keep** | Explicitly traced fallback. Not silent -- emits structured event with reason. Correct design. | permanent |
| 15 | cn_dotenv.ml:73-76 | `load_file` unreadable fallback | Warns to stderr, returns Ok [] | Logged to stderr -- not silent | none | **keep** | Correct: secrets.env is optional. Warns on unreadable. Permissions checked separately. | permanent |
| 16 | cn_deps.ml:167-173 | `collect_files_sorted` | `with Sys_error _ | Unix.Unix_error _ -> []` | Silently skips unreadable directories during integrity hash collection | medium | **convert** | Change to log warning. Silent skip during integrity checking could mask missing dependencies. | -- |
| 17 | cn_sandbox.ml:179-207 | `validate_path` realpath failures | `with Unix.Unix_error _ -> None` | Treats unresolvable symlinks as non-existent in security-critical path | medium | **convert** | Symlink resolution failure in sandbox validation should log warning. Current behavior (deny on None) is actually fail-closed -- but the silent swallow hides debugging info. Add trace event. | -- |

### Summary

| Disposition | Count | Items |
|-------------|-------|-------|
| **remove** | 7 | #1-7 (deprecated agent functions + flat asset compat) |
| **keep** | 6 | #8-10, 12-15 (legitimate patterns, all fail-closed or traced) |
| **convert** | 3 | #11, 16, 17 (silent swallows -> add warning/trace) |

### AC5 Status

`grep -r 'main\.\.\.origin\|master\.\.\.origin' src/` returns zero matches.
The `materialize_branch` diff pattern was deleted in v3.31.0 (#150/#151).
AC5 is already met.

### Plan

1. Delete `run_inbound`, `feed_next_input`, `wake_agent` from `cn_agent.ml` (AC4)
2. Delete `hub_flat_mindsets_path`, `hub_flat_skills_path` and their loader blocks from `cn_assets.ml`
3. Update `cn.ml` module docstring (remove "legacy: run_inbound deprecated")
4. Convert `read_opt` in `cn_assets.ml` to log warning on exception
5. Convert `collect_files_sorted` in `cn_deps.ml` to log warning on readdir failure
6. Convert `validate_path` in `cn_sandbox.ml` to emit trace on realpath failure
7. Build (`dune build`) and test (`dune runtest`) before review submission
8. Write SELF-COHERENCE.md
