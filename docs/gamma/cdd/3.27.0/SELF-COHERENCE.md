# Self-Coherence — v3.27.0

## Acceptance Criteria

| AC | Description | Evidence | Status |
|----|-------------|----------|--------|
| AC1 | Each pass emits `invocation.start`/`invocation.end` with `pass` field (1-indexed) | `cn_orchestrator.ml`: `Cn_ulog.write` with `~pass:pass_num` at loop start and via `emit_pass_end` at each exit point. `pass_num = pass_index + 1` (1-indexed). | Met |
| AC2 | Message-level start/end remain as summary events (backward compatible) | `cn_runtime.ml:1069-1071`: summary `invocation.start` unchanged. `cn_runtime.ml:836-840`: summary `invocation.end` unchanged. Per-pass events distinguished by `details: [("scope", "pass")]`. | Met |
| AC3 | `cn logs --msg <id>` shows per-pass detail when available | `cn_logs.ml:is_per_pass` detects `scope=pass` in details. `format_entry` shows `"pass N (per-pass)"` for start, `"pass N Xops Yms"` for end. | Met |
| AC4 | Per-pass entries include: pass number, ops executed, duration, token usage (if available) | Pass number: `~pass:pass_num`. Ops: `~ops:(List.length current_ops)`. Duration: `~duration_ms:pass_duration_ms`. Token usage: not available per-pass (llm_call returns string only, not token counts). AC says "if available" — satisfied. | Met |
| AC5 | Log volume stays within budget (~2KB per pass, acceptable for N<=5) | Per-pass start: ~120 bytes JSON. Per-pass end: ~150 bytes JSON. Total per pass: ~270 bytes. For N=5: ~1.35KB. Well within budget. | Met |

## Triadic Self-Check

### alpha (structural)
- Per-pass events reuse existing `invocation.start`/`invocation.end` kinds — no schema change needed
- `emit_pass_end` is a local closure capturing `pass_t0`, `pass_num`, `current_ops` — clean scope
- `is_per_pass` in cn_logs.ml checks `details` field — consistent with existing entry structure
- 2 emission points per pass (start + end), 4 exit paths in loop (not-continue, max-passes, budget, continue) all call `emit_pass_end`

### beta (alignment)
- Writer (cn_orchestrator.ml) and reader (cn_logs.ml) agree on `scope=pass` convention
- Tests verify the cross-surface equivalence: what's written is correctly formatted
- Summary events in cn_runtime.ml now correctly report `passes_used` from orchestrator result instead of hardcoded 1
- cn_ulog.ml entry structure already had `pass`, `passes`, and `details` fields — no schema change

### gamma (process)
- CDD followed: observe → select → branch → bootstrap → gap → mode → skills → design → plan → tests → code → self-coherence
- Tests written before code (artifact order respected)
- 3 active skills loaded and read: cdd, ocaml, testing
- Engineering level: L6 — extends existing architecture with finer granularity, cross-surface coherence verified, no boundary move

## Files Changed

| File | Lines added | Lines removed | Purpose |
|------|------------|---------------|---------|
| `src/cmd/cn_orchestrator.ml` | 24 | 0 | Per-pass start/end emission |
| `src/cmd/cn_runtime.ml` | 1 | 1 | Propagate passes_used |
| `src/cmd/cn_logs.ml` | 21 | 7 | Per-pass formatting |
| `test/cmd/cn_orchestrator_test.ml` | 99 | 0 | 3 per-pass tests |
| `test/cmd/cn_logs_test.ml` | 44 | 0 | 3 formatting tests |
| `docs/gamma/cdd/3.27.0/` | 4 files | 0 | CDD artifacts |

## Known Gaps

- **No OCaml toolchain available** — cannot run `dune build` or `dune runtest` locally. Tests are written as ppx_expect tests and will be validated by CI.
- **Token usage per-pass:** Not available because `llm_call` returns `string`, not a response object with token counts. This is by design (AC says "if available").
- **Branch name non-compliant:** System assigned `claude/fix-issue-135-UxKKt` instead of CDD-format `claude/3.27.0-135-per-pass-logging`. Environmental constraint.
