# Plan — v3.27.0

## Design

Per-pass events reuse existing `invocation.start`/`invocation.end` kinds (no schema bump). Distinguished from summary events via `details: [("scope", "pass")]`.

- Per-pass events: emitted inside `Cn_orchestrator.run_n_pass` loop (orchestrator owns pass lifecycle)
- Summary events: remain in `Cn_runtime.finalize_project` (runtime owns message lifecycle)
- Per-pass entry fields: `pass` (1-indexed), `ops`, `duration_ms`, `details.scope`
- Token usage: not available per-pass (llm_call returns string only). AC says "if available."

## Files

| File | Change |
|------|--------|
| `src/cmd/cn_orchestrator.ml` | Emit per-pass `invocation.start`/`invocation.end` in loop body |
| `src/cmd/cn_runtime.ml` | Propagate `result.passes_used` to summary `invocation.end` |
| `src/cmd/cn_logs.ml` | Format per-pass vs summary events distinctly |
| `test/cmd/cn_orchestrator_test.ml` | Per-pass logging tests (single-pass, multi-pass, msg_id) |
| `test/cmd/cn_logs_test.ml` | Per-pass formatting tests (start, end, summary unchanged) |

## Invariants to test (from testing skill)

1. **Per-pass event emission invariant:** Every pass in `run_n_pass` emits exactly one `invocation.start` and one `invocation.end` with `scope=pass` and correct pass number.
2. **Summary backward compat invariant:** Summary events (without `scope=pass`) retain their existing shape.
3. **Cross-surface equivalence:** Writer (`cn_orchestrator.ml`) and reader (`cn_logs.ml`) agree on the per-pass event structure — what's written is correctly formatted.
4. **msg_id correlation invariant:** All per-pass events carry the trigger_id for message-level correlation.

## Artifact order

1. Plan (this file)
2. Tests (write expect tests for invariants above)
3. Code (implementation in orchestrator, runtime, logs)
4. Self-coherence (verify ACs)
