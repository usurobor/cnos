# Gate — v3.38.0 (#182 Move 2 — first slice)

## Pre-gate (authoring-side)

- **CI status:** pending
- **Required artifacts present:**
  - [x] Design: `docs/alpha/agent-runtime/CORE-REFACTOR.md` §7 Move 2 (with v3.38.0 status block)
  - [x] Bootstrap: `docs/gamma/cdd/3.38.0/README.md`
  - [x] Tests: 11 new expect-tests in `test/lib/cn_package_test.ml` (R1–R4, P1–P3, L1–L2, F1–F2), authored before the production module they cover
  - [x] Code: `src/lib/cn_package.ml` (new pure module), `src/lib/dune` (registration), `test/lib/dune` (test library), `src/cmd/cn_deps.ml` (type re-exports + delegating helpers; pure type/helper bodies removed)
  - [x] Self-coherence: `SELF-COHERENCE.md` (α A, β A, γ A−)
  - [x] Docs status update: `docs/alpha/agent-runtime/CORE-REFACTOR.md` §7 Move 2 status block
- **ACs accounted for:** yes — SELF-COHERENCE §"Triadic coherence check" point 1 maps AC1–AC8 to specific code + tests.
- **Docs and code agree:** yes — CORE-REFACTOR.md §7 status block matches `cn_package.ml` matches the re-exports in `cn_deps.ml` matches the test coverage in `cn_package_test.ml`.
- **Known debt explicit:** yes — see §"Non-goals (this cycle)" in README.md and §"Move 2 status" in CORE-REFACTOR.md (three remaining Move 2 candidates: runtime contract, workflow IR, activation).
- **Release decision:** **hold** until:
  1. CI `dune build` + `dune runtest` green
  2. PR review round converges
  3. v3.37.0 post-release cycle is closed (it is — PR #187 merged at `cfe45c2`)
  4. §2.5b 6-check mechanical gate dogfood: branch rebased onto current main immediately before PR open

## §2.5b pre-review checklist (dogfood, 6 checks)

The §2.5b gate currently has six checks (5 from v3.36.0 + the
schema/fixture audit added in v3.37.0). Applied to this branch:

1. **Branch rebased onto current `main`.** To be done immediately before opening PR: `git fetch origin main && git rebase origin/main`. The branch was cut from `cfe45c2` (v3.37.0 post-release merge), which is current `main` at cycle-start. The rebase should be a no-op or trivial.
2. **Self-coherence artifact present.** Yes — this directory contains `README.md`, `SELF-COHERENCE.md`, and this `GATE.md`.
3. **CDD Trace in the PR body.** To include in the PR body at open time: steps 0–7a per `docs/gamma/cdd/CDD.md` §5.3, mirroring the trace table in `README.md` §"CDD Trace".
4. **Tests reference ACs.** Yes — each of the 11 new tests names the AC it covers in its expect-test name (R1/R2 → AC2 round-trips, R3/R4 → AC1 record shape, P1/P2/P3 → AC2 parse_package_index, L1/L2 → AC2 lookup_index, F1/F2 → AC2 is_first_party). The README.md ACs map to test families one-to-one.
5. **Known debt explicit.** Yes — README.md §"Non-goals" lists the three remaining Move 2 extractions (runtime contract, workflow IR, activation), the deliberate non-tightening of `is_first_party`, and the explicit "no `src/core/`" decision per CORE-REFACTOR.md §7. CORE-REFACTOR.md status block names the remaining slices.
6. **Schema/shape audit across test fixtures.** Yes — performed inline. The records moved modules but their field names, field types, and field ordering are byte-for-byte identical, and the OCaml type-equality re-export preserves type identity. SELF-COHERENCE §Beta "Stale-reference scan" enumerates all five caller sites that construct or destructure `Cn_deps.{manifest|lockfile|locked_dep}` records (one in `cn_runtime_contract.ml`, two in `cn_deps_test.ml`, two in `cn_runtime_contract_test.ml`); all five compile unchanged because the re-exported type IS the canonical type at the OCaml level. Zero fixture edits required.

## Gate checklist (at release time)

- [ ] CI green on the merge commit
- [ ] `dune build` succeeds on all 4 release targets
- [ ] `dune runtest` green — 11 new `cn_package_test` expect-tests pass; existing `cn_deps_test` and `cn_runtime_contract_test` still pass (re-export equality holds)
- [ ] `scripts/check-version-consistency.sh` passes
- [ ] `cn build --check` passes (no asset-side change in this cycle)
- [ ] PR review round 1 converged; no α/β findings outstanding
- [ ] v3.37.0 cycle closed (it is)

## §9.1 triggers — pre-assessment

| Trigger | Status at gate |
|---------|---------------|
| Review rounds > 2 | TBD |
| Mechanical ratio > 20% | TBD (the §2.5b 6-check gate is the corrective; this is the second cycle dogfooding it after v3.37.0) |
| Avoidable tooling failure | **soft fired** — sixth cycle in a row with no local OCaml; same environment constraint as v3.33.0–v3.37.0 |
| Loaded skill failed to prevent a finding | TBD (the schema/fixture audit added in v3.37.0 was applied inline this cycle — see check 6 above) |

## Release decision

**hold** — pending CI + PR + review. Gate flips to *proceed*
when every unchecked checklist item is green and review has
converged.
