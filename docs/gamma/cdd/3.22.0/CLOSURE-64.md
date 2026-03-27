# Closure -- #64: P0 agent probes filesystem for self-knowledge

## CDD Path

- Issue: #64
- Path: Small-change closure-by-verification (CDD 1.2)
- Primary fixes: #56 (RC v1), #62 (RC v2), #63 (stale history)

## AC Coverage

| # | AC | Evidence | Status |
|---|----|----------|--------|
| 1 | Runtime Contract is the authoritative self-model at wake | cn_runtime_contract.ml gather() builds four-layer self-model. render_markdown() emits authority preamble. cn_runtime_contract_test.ml asserts cn_version_matches and authority preamble presence. | met |
| 2 | Agent does not need to probe filesystem for identity/cognition | cn_context.ml packs RC into system block 2. Authority declaration says do not read cn.json to determine version. cn_runtime_contract_test.ml tests preamble. | met |
| 3 | Stale conversation history cannot override current contract | cn_context.ml load_conversation_turns tags entries from prior cn_version with stale prefix referencing RC as authoritative. cn_stale_history_test.ml covers: current (no tag), prior (stale+authority), missing version (stale+unknown), content preservation. | met |

## Residual / Known Debt

None. Residual LLM compliance risk filed previously as #124 (coherent-llm label) -- explicitly out of scope and tracked.

## Self-Coherence

- alpha: Three root causes, three fixes, three test suites. Each maps 1:1.
- beta: Fixes span contract content, authority instruction, and temporal tagging. All tested independently and compose correctly.
- gamma: CDD small-change path followed. Active skills (cdd, eng/ocaml, eng/testing) read before verification.

CONVERGED
Date: 2026-03-27
Version: 3.22.0
Author: sigma
