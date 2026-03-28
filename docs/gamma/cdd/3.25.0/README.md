# v3.25.0 — Anti-probe: structural self-knowledge interception

**Issue:** #64 — P0: agent probes filesystem for self-knowledge despite Runtime Contract
**Branch:** claude/fix-agent-filesystem-probing-sBngf
**Mode:** MCA
**Active skills:** ocaml, testing
**Engineering level target:** L7

## Gap

The agent can probe the filesystem for self-knowledge (version, identity, config) despite the Runtime Contract declaring that information in packed context. The current mitigation is instructional (RC text says "don't probe"). The executor processes probes normally, returning `file_not_found` or actual file content, wasting tokens and passes.

## Coherence Contract

| Axis | Target | Measure |
|------|--------|---------|
| alpha | A | Self-knowledge interceptor is structurally correct: known probe paths return `contract_redirect` with RC pointer |
| beta | A | Executor, sandbox, RC, tests, and docs all agree on which paths are self-knowledge and what happens when probed |
| gamma | A- | Clean cycle: 1-2 review rounds, tests before code, no mechanical findings |

## Acceptance Criteria

| # | AC | Evidence |
|---|-----|---------|
| 1 | `fs_read cn.json` returns `contract_redirect` status, not file content | Expect test |
| 2 | `fs_read` on package manifest files returns `contract_redirect` | Expect test |
| 3 | `fs_list` on self-knowledge directories returns `contract_redirect` when targeting identity paths | Expect test |
| 4 | Legitimate filesystem reads (e.g., `src/`, `docs/`, `agent/wake/README.md`) are unaffected | Expect test |
| 5 | Redirect reason includes pointer to Runtime Contract section | Expect test output inspection |
| 6 | Runtime Contract authority declaration updated to reference structural interception | Code inspection |

## Deliverables

- SELECTION.md (this cycle's selection rationale)
- README.md (this file)
- PLAN.md (implementation plan)
- SELF-COHERENCE.md (author self-assessment)
- Code: `cn_executor.ml` self-knowledge interceptor
- Tests: `cn_executor_test.ml` expect tests for interceptor
- Docs: Runtime Contract authority declaration update
