# Gate — v3.35.0 (#173 slice)

## Pre-gate (authoring-side)

- **CI status:** pending — not yet run on this branch
- **Required artifacts present:**
  - [x] Design: `docs/alpha/agent-runtime/ORCHESTRATORS.md` §4 (pre-existing)
  - [x] Coherence contract: `docs/gamma/cdd/3.35.0/README.md` (gap, mode, ACs)
  - [x] Plan: `docs/gamma/cdd/3.35.0/PLAN-runtime-activation.md`
  - [x] Tests: `test/cmd/cn_activation_test.ml` (11) + delta in `test/cmd/cn_runtime_contract_test.ml` (4)
  - [x] Code: `src/cmd/cn_activation.ml` (new) + `cn_runtime_contract.ml` + `cn_doctor.ml`
  - [x] Docs: `docs/alpha/agent-runtime/RUNTIME-CONTRACT-v2.md` §4 JSON schema extended with activation_index, commands, orchestrators
  - [x] Self-coherence: `docs/gamma/cdd/3.35.0/SELF-COHERENCE.md` (α A, β A, γ A−)
- **ACs accounted for:** yes — see SELF-COHERENCE §"Triadic Coherence Check" point 1 (AC1–AC6 each mapped to specific code)
- **Docs and code agree:**
  - JSON schema example in RUNTIME-CONTRACT-v2.md matches the `to_json` output field layout in `cn_runtime_contract.ml`
  - ORCHESTRATORS.md §4.1/§4.2 shape matches the record types and JSON emitters
  - README §"Impact Graph" enumerates every touched file; `git status` on the branch matches it
- **Snapshot ready:** n/a for this cycle — no release tag until the release train picks this up
- **Previous release assessed:** yes (v3.34.0 post-release covers #167 slice in `docs/gamma/cdd/3.34.0/POST-RELEASE-ASSESSMENT-package-artifacts.md`)
- **Known debt explicit:** yes — PLAN §3 lists frontmatter-parser inline-list limitation, sub-skill exclusion, no-package-declares-orchestrators-yet, binary trigger-conflict policy
- **Release decision:** **hold** until:
  1. CI runs `dune build` + `dune runtest`
  2. PR review round converges
  3. Branch is opened as a PR (stop hook convention: no PR unless explicitly asked)

## Gate checklist (at release time)

- [ ] CI green on the merge commit
- [ ] `dune build src/cli/cn.exe` succeeds on all 4 release targets
- [ ] `dune runtest` green — 15 new expect tests all pass
- [ ] `scripts/check-version-consistency.sh` passes
- [ ] `cn build --check` passes (packages/ in sync with src/agent/ — this cycle did not touch src/agent/ so no-op)
- [ ] Runtime contract emitted by a real hub wake shows `cognition.activation_index.skills` is non-empty and `body.commands` / `body.orchestrators` render with at least the package-declared entries
- [ ] PR review round 1 converged; no α/β findings outstanding
- [ ] v3.34.0 post-release cycle closed (it is)
- [ ] Known debt materialized as follow-up issues (or noted as durable known-debt in the post-release)

## §9.1 triggers — pre-assessment

| Trigger | Status at gate |
|---------|---------------|
| Review rounds > 2 | TBD (no review yet) |
| Mechanical ratio > 20% | TBD (no findings yet) |
| Avoidable tooling failure | **soft fired** — no OCaml toolchain in authoring sandbox; same environment constraint as v3.34.0 #167 cycle |
| Loaded skill failed to prevent a finding | TBD (baseline: skills were loaded and read before writing, which is the explicit corrective from the v3.34.0 post-release assessment for #167) |

## Release decision

**hold** — pending CI + PR + review. Gate flips to *proceed* when every unchecked checklist item above is green and review has converged.
