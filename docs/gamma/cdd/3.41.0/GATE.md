# Gate — v3.41.0 (#182 Move 2 slice 4 — **final slice**)

## Pre-gate (authoring-side)

- **CI status:** pending (this is the first cycle running check 8 formally — PR will be opened as draft, CI must go green before marking ready-for-review)
- **Required artifacts present:**
  - [x] Design: `CORE-REFACTOR.md` §7 with **"✅ Move 2 complete"** status block
  - [x] Bootstrap: `docs/gamma/cdd/3.41.0/README.md` (8 ACs + Move 2 complete milestone + §1.4 compliance trace)
  - [x] Tests: 21 ppx_expect tests in `test/lib/cn_frontmatter_test.ml`, authored before the production module
  - [x] Code: `src/lib/cn_frontmatter.ml` (new, 12 pure surface items); `src/cmd/cn_activation.ml` (rewritten, 3 type re-exports + 9 delegations + 3 IO functions retained + slice-2 `activation_entry` chain untouched); `src/lib/dune` + `test/lib/dune`
  - [x] Self-coherence: `SELF-COHERENCE.md` (α A, β A, γ A)
- **ACs accounted for:** yes — all 8 mapped to code + tests in SELF-COHERENCE §"Triadic coherence check"
- **Docs and code agree:** yes — CORE-REFACTOR.md §7 milestone matches extraction reality; remaining candidates = none
- **Known debt explicit:** yes — README §Non-goals names 4 items; §1.4 steps 11–13 ownership stated explicitly
- **Release decision:** **hold** until CI green + review converges. Steps 9–13 owned by user per §1.4.

## §2.5b pre-review checklist (8 checks — all formal this cycle)

1. **Branch rebased onto current `main`.** Pending verify at push time. Branch cut from current main post-v3.40.0 release + §1.4 + #198 + #200. Rebase expected trivial.
2. **Self-coherence present.** ✅ `docs/gamma/cdd/3.41.0/SELF-COHERENCE.md`
3. **CDD Trace in PR body.** Will be included from README.
4. **Tests reference ACs.** ✅ 21 test families named per AC1/AC2/AC5/AC6.
5. **Known debt explicit.** ✅ README §Non-goals (4 items).
6. **Schema/fixture audit.** ✅ Structural no-op (type-equality, no schema change, detailed in SELF-COHERENCE §Beta).
7. **Workspace library-name uniqueness.** ✅ `cn_frontmatter` + `cn_frontmatter_test` both grep-verified unique pre-bootstrap and re-verified at Stage D.
8. **CI green on head commit before requesting review.** **Pending — this is the formal test.** PR will be opened as **draft**. If CI is red, iterate on draft. Only mark ready-for-review when CI is green. First cycle running this check as a formal gate item.

## Gate checklist (at release time — owned by releasing agent per §1.4)

- [ ] CI green on the merge commit
- [ ] `dune build` succeeds
- [ ] `dune runtest` green — 21 new `cn_frontmatter_test` expect-tests pass; existing `cn_activation_test` (9 tests) still passes; existing `cn_contract_pure_test`, `cn_workflow_ir_test`, `cn_package_test` all unaffected
- [ ] `scripts/check-version-consistency.sh` passes
- [ ] `cn build --check` passes (no asset-side change)
- [ ] PR review converged; no α/β findings outstanding
- [ ] v3.40.0 post-release cycle closed (it is — #200 merged at `8626048`)
- [ ] **Move 2 complete** — CORE-REFACTOR.md §7 status block confirms 0 remaining slices

## §9.1 triggers — pre-assessment (for the releasing agent's use per §1.4)

| Trigger | Status at gate |
|---------|---------------|
| Review rounds > 2 | TBD |
| Mechanical ratio > 20% | TBD (target: 0% — this is the test of whether checks 7 + 8 actually prevent the failure classes from slices 2 + 3) |
| Avoidable tooling failure | **soft** — 9th cycle with no local OCaml; check 8 absorbs downstream impact via draft-until-green |
| Loaded skill failed to prevent a finding | TBD (this is the validation cycle for PR #198's correctives) |

## Release decision

**hold** — pending CI green on draft PR → mark ready-for-review → reviewer converges → releasing agent (per §1.4) owns steps 9–13.
