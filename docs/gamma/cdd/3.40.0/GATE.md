# Gate — v3.40.0 (#182 Move 2 slice 3)

## Pre-gate (authoring-side)

- **CI status:** pending (will be verified after push)
- **Required artifacts present:**
  - [x] Design: `docs/alpha/agent-runtime/CORE-REFACTOR.md` §7 Move 2 (with v3.40.0 status block appended alongside v3.38.0 + v3.39.0)
  - [x] Bootstrap: `docs/gamma/cdd/3.40.0/README.md` (8 ACs from #196, impact graph, CDD trace, explicit option-(b) decision rationale)
  - [x] Tests: 20 new expect-tests in `test/lib/cn_workflow_ir_test.ml` (T1–T4 records, S1–S6 step variants via `step_id`, IK1 issue_kind 7-variant, P1–P6 parsers, V1–V6 validator, M1–M2 manifest helper), authored before the production module they cover
  - [x] Code: `src/lib/cn_workflow_ir.ml` (new pure module, 316 lines — largest `src/lib/` module yet); `src/cmd/cn_workflow.ml` (6+2 type re-exports + 9 delegating let-bindings; all 11 IO functions untouched; 3 IO-transit types retained per option b; net −169 lines); `src/lib/dune` (`cn_workflow_ir` in modules list); `test/lib/dune` (`cn_workflow_ir_test` library registered with §2.5b check-7 comment)
  - [x] Self-coherence: `SELF-COHERENCE.md` (α A, β A, γ A−)
  - [x] Docs status update: `docs/alpha/agent-runtime/CORE-REFACTOR.md` §7 Move 2 v3.40.0 status block
- **ACs accounted for:** yes — SELF-COHERENCE §"Triadic coherence check" point 1 maps AC1–AC8 to specific code + tests.
- **Docs and code agree:** yes — CORE-REFACTOR.md §7 status block matches `cn_workflow_ir.ml` matches the re-exports in `cn_workflow.ml` matches the test coverage in `cn_workflow_ir_test.ml` matches the consumer model in `cn_runtime_contract.ml::build_orchestrator_registry` (unchanged, per option b).
- **Known debt explicit:** yes — README §"Non-goals" names: (a) slice 4 (activation evaluator from `cn_activation.ml`, last remaining Move 2), (b) option-(b) decision on `load_outcome`/`installed`/`outcome`, (c) non-re-export of `let ( let* )` as dead binding, (d) deliberate retention of `find_step`/`env_get`/`as_bool`/`as_string` in `cn_workflow.ml` per AC4, (e) explicit "no `src/core/`" decision per CORE-REFACTOR.md §7.
- **Release decision:** **hold** until:
  1. CI `dune build` + `dune runtest` green
  2. PR review round converges
  3. v3.39.0 post-release cycle remains in-flight (skill patch stashed; separate branch)
  4. §2.5b 6-check mechanical gate dogfood: branch rebased onto current `main` immediately before PR open

## §2.5b pre-review checklist (dogfood, 6 checks + manual check 7)

Applied to this branch:

1. **Branch rebased onto current `main`.** Branch `claude/182-move2-workflow-ir` was originally cut from `8b04e30` (eng/go skill v2 on top of #195 merge). During Stage H pre-commit verification, `git fetch origin main` showed main had advanced 3 eng/go-skill commits — the branch was rebased onto `d1badee` (the new tip). Rebase was clean; no conflicts because the eng/go skill commits touch a disjoint file set from the workflow IR extraction. **Post-rebase parent: `d1badee`** (the state CI actually sees and the state PR #197 reports).
2. **Self-coherence artifact present.** Yes — `docs/gamma/cdd/3.40.0/SELF-COHERENCE.md` with all 5 sections (α, β, γ, triadic check, pointers + exit criteria).
3. **CDD Trace in PR body.** To include verbatim from `README.md` §"CDD Trace" at PR open time: steps 0–7a per `docs/gamma/cdd/CDD.md` §5.3.
4. **Tests reference ACs.** Yes — every test family is named for the AC it covers (enumerated in the SELF-COHERENCE §Gamma table): T1–T4 / S1–S6 / IK1 / P1–P6 / V1–V6 / M1–M2 all map to AC1 (the 6 types + 10 pure functions) + AC5 (test coverage) + AC6 (dune wiring).
5. **Known debt explicit.** Yes — README §"Non-goals" names slice 4 + 4 deliberate scope choices; SELF-COHERENCE §Gamma records the soft-fired §9.1 tooling trigger (8th cycle with no local OCaml); the manual-check-7 discipline is flagged as "stashed skill patch pending v3.39.0 post-release PR."
6. **Schema/shape audit across test fixtures.** Yes — performed inline in SELF-COHERENCE §Beta. Two-layer audit: (a) no schema change occurred (6 moved types + 2 retained IO-transit types all byte-for-byte preserved; JSON schema `cn.orchestrator.v1` unchanged; `validate` issue messages unchanged); (b) no fixture-level record literals exist in `test/cmd/cn_workflow_test.ml` — it uses JSON-string parsing + pattern matching, not direct record construction. Structural no-op for pure-type extraction cycles, same as slice 1 (v3.38.0) and slice 2 (v3.39.0).
7. **Manual check 7 — workspace-global library-name uniqueness.** Applied pre-bootstrap (before writing any dune wiring): `grep -rn "(name cn_workflow_ir" src/ test/` → zero collisions. `grep -rn "(name cn_workflow_ir_test)" src/ test/` → zero collisions. `grep -rn "(name cn_workflow_test)" src/ test/` → 1 match in `test/cmd/dune:173` (the pre-existing executor test library, which is why the new library is named `cn_workflow_ir_test` with the distinguishing `_ir_` segment). The discipline is applied manually because the skill patch that would formalize this as check 7 of §2.5b is stashed on `claude/post-release-3.39.0` pending that cycle's post-release PR. This cycle does not wait for the patch to land before applying the check — the lesson from v3.39.0 #195 F1 is applied directly.

## Gate checklist (at release time)

- [ ] CI green on the merge commit (both `ocaml` and `Protocol contract + traceability (I2/I3)` checks must pass — the two that failed on slice 2's first push due to the library name collision)
- [ ] `dune build` succeeds on all 4 release targets
- [ ] `dune runtest` green — 20 new `cn_workflow_ir_test` expect-tests pass; existing `cn_workflow_test` (26 tests) still passes (re-export type-equality holds for `parse`, `validate`, 6 step variants, 5 issue_kind variants, `issue` record); existing `cn_runtime_contract_test` still passes (no change to `build_orchestrator_registry`'s `installed`/`Loaded`/`Load_error` consumer)
- [ ] `scripts/check-version-consistency.sh` passes
- [ ] `cn build --check` passes (no asset-side change in this cycle)
- [ ] PR review round 1 converged; no α/β findings outstanding
- [ ] v3.39.0 post-release PR remains the gating parallel cycle (not blocking but tracked)

## §9.1 triggers — pre-assessment

| Trigger | Status at gate |
|---------|---------------|
| Review rounds > 2 | TBD |
| Mechanical ratio > 20% | TBD |
| Avoidable tooling failure | **soft fired** — eighth cycle in a row with no local OCaml; same environment constraint as v3.33.0–v3.39.0 |
| Loaded skill failed to prevent a finding | TBD (slice 2 had one F1 mechanical finding → check-7 skill patch stashed; this cycle applied the check manually to prevent recurrence — the recurrence-prevention test is whether CI lands green on first push) |

## Release decision

**hold** — pending CI + PR + review. Gate flips to *proceed*
when every unchecked checklist item is green and review has
converged.
