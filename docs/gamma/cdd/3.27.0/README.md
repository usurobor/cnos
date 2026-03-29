# v3.27.0 — Per-Pass Logging in N-Pass Bind Loop

**Issue:** #135 — #74 Phase 2: Per-pass logging in N-pass bind loop
**Parent:** #74 — Rethink logs structure for operator observability
**Level:** L6 — System-safe (extends existing unified log with finer granularity)

## Gap

When the agent takes multiple passes (e.g., observe ops then effect ops), the operator sees a single invocation with `pass_count=N` but no visibility into what each pass did, how long each took, or where a multi-pass failure occurred. The unified log (v3.26.0) emits `invocation.start` and `invocation.end` once per message, not per pass.

## Change

1. **Per-pass `invocation.start`/`invocation.end` events**: Each pass in the N-pass loop emits start/end events to the unified log with a `pass` field (1-indexed) and `scope=pass` in details to distinguish from summary events.

2. **Summary events unchanged**: The existing message-level `invocation.start`/`invocation.end` remain as-is (backward compatible).

3. **`cn logs --msg` per-pass detail**: The CLI formatter distinguishes per-pass events from summary events, showing pass number, ops executed, and duration per pass.

4. **Correct passes_used propagation**: The summary `invocation.end` now reflects `passes_used` from the orchestrator result, not a hardcoded 1.

## Acceptance Criteria

1. Each pass in the N-pass loop emits `invocation.start` and `invocation.end` with a `pass` field (1-indexed)
2. The existing message-level `invocation.start`/`invocation.end` remain as summary events (backward compatible)
3. `cn logs --msg <id>` shows per-pass detail when available
4. Per-pass entries include: pass number, ops executed, duration, token usage (if available)
5. Log volume stays within budget (~2KB per invocation -> ~2KB per pass, acceptable for N<=5)

## Deliverables

- SELECTION.md
- PLAN.md
- SELF-COHERENCE.md
- POST-RELEASE-ASSESSMENT.md (post-release)

## Files Changed

- `src/cmd/cn_orchestrator.ml` — emit per-pass invocation.start/end events
- `src/cmd/cn_runtime.ml` — propagate passes_used to summary invocation.end
- `src/cmd/cn_logs.ml` — format per-pass entries distinctly
- `test/cmd/cn_orchestrator_test.ml` — per-pass logging tests
- `test/cmd/cn_logs_test.ml` — per-pass formatting tests
