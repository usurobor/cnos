# Gate — v3.39.0 (#182 Move 2 slice 2)

## Pre-gate (authoring-side)

- **CI status:** pending
- **Required artifacts present:**
  - [x] Design: `docs/alpha/agent-runtime/CORE-REFACTOR.md` §7 Move 2 (with v3.39.0 status block appended alongside v3.38.0)
  - [x] Bootstrap: `docs/gamma/cdd/3.39.0/README.md` (10 ACs including implementer-added AC10, impact graph, CDD trace)
  - [x] Tests: 13 new expect-tests in `test/lib/cn_contract_test.ml` (P1/P1b/O1/Z1/ZE1/I1/E1/C1/C2/OR1/A1/CG1/B1/RC1), authored before the production module they cover
  - [x] Code: `src/lib/cn_contract.ml` (new pure module, 11 types + `activation_entry` + `zone_to_string`); `src/cmd/cn_runtime_contract.ml` (11 type re-exports + 1 delegating let-binding; all IO functions untouched); `src/cmd/cn_activation.ml` (1 type-equality re-export for `activation_entry`); `src/lib/dune` (`cn_contract` in modules list); `test/lib/dune` (`cn_contract_test` library registered)
  - [x] Self-coherence: `SELF-COHERENCE.md` (α A, β A, γ A−)
  - [x] Docs status update: `docs/alpha/agent-runtime/CORE-REFACTOR.md` §7 Move 2 v3.39.0 status block
- **ACs accounted for:** yes — SELF-COHERENCE §"Triadic coherence check" point 1 maps AC1–AC10 to specific code + tests.
- **Docs and code agree:** yes — CORE-REFACTOR.md §7 status block matches `cn_contract.ml` matches the re-exports in `cn_runtime_contract.ml` and `cn_activation.ml` matches the test coverage in `cn_contract_test.ml`.
- **Known debt explicit:** yes — README §"Non-goals" names the two remaining Move 2 slices (workflow IR from `cn_workflow.ml`, activation evaluator from `cn_activation.ml`); the AC5 scope-limit keeping `to_json`/`render_markdown`/`write` in `cn_runtime_contract.ml` is stated explicitly.
- **Release decision:** **hold** until:
  1. CI `dune build` + `dune runtest` green
  2. PR review round converges
  3. v3.38.0 post-release cycle is closed (it is — PR #191 merged at `38ec1c2`, lag patched at `de39e64`)
  4. §2.5b 6-check mechanical gate dogfood: branch rebased onto current `main` immediately before PR open

## §2.5b pre-review checklist (dogfood, 6 checks)

Applied to this branch:

1. **Branch rebased onto current `main`.** Branch `claude/182-move2-contract-types` was cut from `de39e64` (current `main` — v3.38.0 post-release lag patch). Rebase will be executed as `git fetch origin main && git rebase origin/main` immediately before `gh pr create`; expected to be a no-op or trivial because no work has landed on `main` since the branch was cut.
2. **Self-coherence artifact present.** Yes — `docs/gamma/cdd/3.39.0/SELF-COHERENCE.md` with all 5 sections (α, β, γ, triadic check, pointers + exit criteria).
3. **CDD Trace in the PR body.** To include verbatim from `README.md` §"CDD Trace" at PR open time: steps 0–7a per `docs/gamma/cdd/CDD.md` §5.3.
4. **Tests reference ACs.** Yes — each test family names the AC it covers:
   - P1/P1b, O1, Z1, ZE1, I1, E1, C1, C2, OR1, CG1, B1, RC1 → AC1 (11 types) + AC2 (`zone_to_string`) + AC6 (expect-test coverage)
   - A1 → AC10 (`activation_entry` extraction)
5. **Known debt explicit.** Yes — README §"Non-goals" lists two remaining Move 2 slices (workflow IR, activation evaluator), the deliberate scope choice to keep `to_json`/`render_markdown`/`write` in `cn_runtime_contract.ml` per AC5, and the explicit "no `src/core/`" decision per CORE-REFACTOR.md §7. SELF-COHERENCE §Gamma records the soft-fired §9.1 tooling trigger (7th cycle with no local OCaml).
6. **Schema/shape audit across test fixtures.** Yes — performed inline in SELF-COHERENCE §Beta. Two-layer audit:
   - Layer 1: did any schema change occur? **No.** Record field names, field types, ordering, variant constructor names, `zone_to_string` output strings, and the JSON schema `cn.runtime_contract.v2` (produced by the unchanged `to_json`) are all preserved byte-for-byte.
   - Layer 2: are there fixture-level record literals in `test/`? **No.** `cn_runtime_contract_test.ml` uses `gather` on a temp hub; `cn_activation_test.ml` uses `build_index` on a temp hub. No `let x : Cn_runtime_contract.package_info = { ... }` literals to sweep.
   
   The check is a structural no-op for pure-type extraction cycles where the IO functions that produce the records are untouched. Same held for v3.38.0 slice 1.

## Gate checklist (at release time)

- [ ] CI green on the merge commit
- [ ] `dune build` succeeds on all 4 release targets
- [ ] `dune runtest` green — 13 new `cn_contract_test` expect-tests pass; existing `cn_runtime_contract_test` (47 tests) + `cn_activation_test` (9 tests) still pass (re-export type-equality holds across two touched `src/cmd/` modules)
- [ ] `scripts/check-version-consistency.sh` passes
- [ ] `cn build --check` passes (no asset-side change in this cycle)
- [ ] PR review round 1 converged; no α/β findings outstanding
- [ ] v3.38.0 cycle closed (it is — post-release merged, lag patched)

## §9.1 triggers — pre-assessment

| Trigger | Status at gate |
|---------|---------------|
| Review rounds > 2 | TBD |
| Mechanical ratio > 20% | TBD |
| Avoidable tooling failure | **soft fired** — seventh cycle in a row with no local OCaml; same environment constraint as v3.33.0–v3.38.0 |
| Loaded skill failed to prevent a finding | TBD (slice 1 was clean; slice 2 scope is larger — two `src/cmd/` modules touched + chained re-export via `activation_entry`) |

## Release decision

**hold** — pending CI + PR + review. Gate flips to *proceed*
when every unchecked checklist item is green and review has
converged.
