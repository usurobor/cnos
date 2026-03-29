# Selection — v3.27.0

## Observation Inputs

### CHANGELOG TSC
- Latest: v3.26.1 (A/A/A/A, L5) — docs release
- Previous: v3.26.0 (A-/A/A-/B+, L7) — unified log Phase 1
- Weakest axis on v3.26.0: gamma (6 review rounds, 54% mechanical ratio)

### Encoding Lag
- #74 Phase 1 shipped (P0 closed). Phase 2 committed as next MCA.
- 12 growing issues. No new stale.

### Doctor/Status
- No P0. No operational infrastructure debt.

### Last Assessment (v3.26.0)
- Next MCA committed: "#74 Phase 2 — per-pass logging in N-pass bind loop"
- First AC: "Per-pass logging emits invocation.start/invocation.end for each pass in the N-pass loop"

## Selection

- **Rule applied:** CDD §3.3 — Assessment commitment default
- **Selected gap:** #135 — Per-pass logging in N-pass bind loop
- **Rationale:** v3.26.0 assessment explicitly committed #74 Phase 2 as next MCA. No P0 or operational debt overrides. Natural follow-on to Phase 1 unified log.
