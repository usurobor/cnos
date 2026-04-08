# Gate — v3.36.0 (#174)

## Pre-gate (authoring-side)

- **CI status:** pending — not yet run
- **Required artifacts present:**
  - [x] Design: `docs/alpha/agent-runtime/ORCHESTRATORS.md` §7–8
  - [x] Plan: `docs/alpha/agent-runtime/PLAN-174-orchestrator-runtime.md` (committed at 29eeb29)
  - [x] Bootstrap: `docs/gamma/cdd/3.36.0/README.md`
  - [x] Tests: `test/cmd/cn_workflow_test.ml` (18) + updated `test/cmd/cn_runtime_contract_test.ml`
  - [x] Code: `src/cmd/cn_workflow.ml` (new) + `cn_runtime_contract.ml` + `cn_doctor.ml` + `cn_build.ml`
  - [x] Docs: `PACKAGE-SYSTEM.md` §1.1 extended with orchestrators class
  - [x] Shipped asset: `src/agent/orchestrators/daily-review/orchestrator.json` + built copy
  - [x] Self-coherence: `SELF-COHERENCE.md` (α A · β A · γ A−)
- **ACs accounted for:** yes — SELF-COHERENCE §"Triadic Coherence Check" point 1 maps AC1–AC7. AC3 and AC7 carry the documented `llm` deferral.
- **Docs and code agree:** yes — PACKAGE-SYSTEM.md §1.1 matches the source_decl additions matches the cn_build copy loop matches Cn_workflow.discover matches build_orchestrator_registry matches the daily-review manifest.
- **Known debt explicit:** yes (SELF-COHERENCE §"Triadic Coherence Check" points 1/4 + PLAN §"Deferred to v2").
- **Release decision:** **hold** until:
  1. CI `dune build` + `dune runtest` green
  2. PR review converges
  3. v3.35.0 post-release closed (it is — PR #178 landed)

## Gate checklist (at release time)

- [ ] CI green on the merge commit
- [ ] `dune build src/cli/cn.exe` succeeds on all 4 release targets
- [ ] `dune runtest` green — 18 cn_workflow tests + updated cn_runtime_contract_test suite
- [ ] `scripts/check-version-consistency.sh` passes
- [ ] `cn build --check` passes (daily-review orchestrator mirrored between src/agent/ and packages/cnos.core/)
- [ ] `cn doctor` on a hub with the shipped cnos.core reports "Orchestrators: 1 healthy"
- [ ] `state/runtime-contract.json` on a real wake shows `body.orchestrators` with `daily-review` + `trigger_kinds: ["command"]`
- [ ] PR review round 1 converged; no α/β findings outstanding
- [ ] Known debt materialised as follow-up issues:
  - `llm` step execution (mechanism for prompt + context injection)
  - `parallel` step kind (needs async model)
  - `match` step execution test (direct X-series test; today the branch is exercised only via validator V2 path)

## §9.1 triggers — pre-assessment

| Trigger | Status at gate |
|---------|---------------|
| Review rounds > 2 | TBD |
| Mechanical ratio > 20% | TBD |
| Avoidable tooling failure | **soft fired** — no OCaml toolchain locally; same as last two cycles |
| Loaded skill failed to prevent a finding | TBD (baseline: skills loaded before writing, corrective from v3.34.0 post-release held) |

## Release decision

**hold** — pending CI + PR + review. Gate flips to *proceed* when every unchecked checklist item is green and review has converged.
