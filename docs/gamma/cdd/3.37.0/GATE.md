# Gate — v3.37.0 (#184)

## Pre-gate (authoring-side)

- **CI status:** pending
- **Required artifacts present:**
  - [x] Design: `docs/alpha/agent-runtime/CORE-REFACTOR.md` §2 + §7 (Move 1)
  - [x] Bootstrap: `docs/gamma/cdd/3.37.0/README.md`
  - [x] Tests: four new expect-tests in `test/cmd/cn_build_test.ml` (three AC1 + one AC4), authored before the `cn_build.ml` changes they cover
  - [x] Code: `src/cmd/cn_build.ml` (content class), `src/cmd/cn_command.ml` (plumbing), `src/lib/cn_lib.ml` (variant + parse + help_text), `src/cli/cn.ml` (dispatch), `src/cmd/cn_gtd.ml` (deletion), `src/cmd/cn_hub.ml` (sibling cleanup)
  - [x] Assets: `src/agent/commands/{daily,weekly,save}/cn-<id>` + mirrored into `packages/cnos.core/commands/`
  - [x] Manifest: `packages/cnos.core/cn.package.json` gains `sources.commands` + top-level `commands`
  - [x] Docs: `docs/alpha/package-system/PACKAGE-SYSTEM.md` §1.1 updated (row + prose)
  - [x] Self-coherence: `SELF-COHERENCE.md` (α A, β A, γ A−)
- **ACs accounted for:** yes — SELF-COHERENCE §"Triadic coherence check" point 1 maps AC1–AC7 to specific code + tests.
- **Docs and code agree:** yes — PACKAGE-SYSTEM.md §1.1 matches the source_decl addition matches the copy loops matches the manifest matches the built assets.
- **Known debt explicit:** yes — see §7 deferrals in SELF-COHERENCE + the v3.36.0 carryover list (llm step, parallel, inline list form, unrelated bare catches, other built-in commands).
- **Release decision:** **hold** until:
  1. CI `dune build` + `dune runtest` green
  2. PR review round converges
  3. v3.36.0 post-release cycle is closed (it is — PR #183 merged + commit 6741fdb on main)
  4. §2.5b mechanical gate dogfood: branch rebased onto current main immediately before PR open

## §2.5b pre-review checklist (dogfood)

The skill patch from v3.36.0 PR #183 added a five-check pre-review
gate to `cdd/SKILL.md` §2.5b. This is the first cycle running under
it. The checks, applied to this branch:

1. **Branch rebased onto current `main`.** To be done immediately
   before `gh pr create`: `git fetch origin main && git rebase origin/main`. The branch was cut from a main that already contains v3.36.0 + the post-release + the #182 refactor commits (2b5d55c, ffbcbff, 9329838, 7207ded, 3ec6132), so the rebase should be a no-op or trivial.
2. **Self-coherence artifact present.** Yes — this directory contains `README.md`, `SELF-COHERENCE.md`, and this `GATE.md`.
3. **CDD Trace in the PR body.** To include in the PR body at open time: steps 0–7a per `docs/gamma/cdd/CDD.md` §5.3.
4. **Tests reference ACs.** Yes — each of the four new tests is tagged with the AC it covers in its name (`(AC1)`, `(AC4)`).
5. **Known debt explicit.** Yes — the issue's non-goals are
   preserved (commit/push/peer/send/reply stay built-in, no
   `src/core/` extraction, no package roles, no runtime-extension
   changes), and the SELF-COHERENCE §"Gamma" section names the
   open items carried from prior cycles.

## Gate checklist (at release time)

- [ ] CI green on the merge commit
- [ ] `dune build src/cli/cn.exe` succeeds on all 4 release targets
- [ ] `dune runtest` green — four new `cn_build_test` expect-tests pass
- [ ] `scripts/check-version-consistency.sh` passes
- [ ] `cn build --check` passes (packages/cnos.core/commands/ mirrored cleanly against src/agent/commands/; executable bits preserved on `cn-*` files)
- [ ] On a hub with cnos.core 3.37.0 installed: `cn help` lists `daily`, `weekly`, `save` under external commands; `cn doctor` → `Commands: 3 healthy` (plus any pre-existing)
- [ ] `cn daily` on a real hub creates `threads/reflections/daily/YYYYMMDD.md` with the expected template (same file layout as pre-migration)
- [ ] PR review round 1 converged; no α/β findings outstanding
- [ ] v3.36.0 cycle closed (it is)

## §9.1 triggers — pre-assessment

| Trigger | Status at gate |
|---------|---------------|
| Review rounds > 2 | TBD |
| Mechanical ratio > 20% | TBD (the v3.36.0 skill patch is explicitly trying to drive this under the threshold by mechanizing the pre-review gate) |
| Avoidable tooling failure | **soft fired** — no OCaml locally; same environment constraint as the last four cycles |
| Loaded skill failed to prevent a finding | TBD (dogfood of §2.5b — first cycle where the pre-review checklist is actually followed by the author) |

## Release decision

**hold** — pending CI + PR + review. Gate flips to *proceed* when
every unchecked checklist item is green and review has converged.
