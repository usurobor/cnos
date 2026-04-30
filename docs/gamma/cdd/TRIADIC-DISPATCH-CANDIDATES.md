# Triadic Dispatch Candidates

γ-side triage of open issues against the triadic CDD dispatch envelope.

## Dispatch envelope

- γ (coordinator) dispatches α (implementer) and β (reviewer) via `claude -p` on a 2 GB VPS
- Each α session is ephemeral, foreground, and should complete in < 10 minutes
- α works on a git worktree, commits, pushes to a cycle branch
- The repo is OCaml + Markdown (skills, specs, docs, CTB language drafts)

## Selection criteria

Include if:

- Completable in 1–3 commits
- Isolated — no deep cross-package dependencies
- Clear done condition — α and β can verify without ambiguous judgment
- Prompt-friendly — issue body + relevant file context fits one dispatch

Exclude if:

- Requires new OCaml CLI commands
- Multi-package coordination or deep runtime internals
- Umbrella/tracking issue with no single deliverable
- Blocked by unimplemented issues
- Open-ended design with no stopping point
- Would need runtime test infrastructure that doesn't exist

## Candidates

### #5 — Require review commit before merging to main

Suitability: high
Scope: ~1 commit, ~2 files
Why: Two skill markdown files (`eng/review/SKILL.md`, `eng/ship/SKILL.md`); ACs are explicit and verifiable (text presence + check rule).
Risk: β must agree on what "checks for review commit" prose looks like — purely textual, no runtime.
α focus: edit both SKILLs to require/check a non-author review commit before merge; record reviewer identity in commit metadata convention.

### #14 — Ensure only non-secret info gets committed to git

Suitability: medium-high
Scope: ~1–2 commits, ~3 files
Why: Bounded to `.gitignore` patterns plus skill prose in `eng/ship/SKILL.md`. Small body, narrow AC.
Risk: AC list is informal — α must pick a scope (gitignore + doc, no hooks) and β must accept hook deferral.
α focus: add gitignore patterns for common secret files and a "no secrets in git" section in `eng/ship/SKILL.md`; defer pre-commit hook to a follow-up.

### #84 — CA mindset missing reflection requirements for continuity

Suitability: high
Scope: ~1 commit, 1 file
Why: Single mindset markdown (`cnos.core/mindsets/CA.md`); MCA section drafted in the issue body.
Risk: β must accept the proposed wording without re-litigating doctrine.
α focus: add a `## Reflect` section after Learn in CA.md, verbatim or close to the proposed MCA.

### #149 — UIE must include skill loading as part of Understand before Execute

Suitability: high
Scope: ~1 commit, 1 file
Why: Updates SOUL.md §2.2 with explicit "load required skills" step. Three concrete ACs.
Risk: SOUL is high-leverage — β must check that the wording survives without unintended overreach into auto-loading.
α focus: edit SOUL.md §2.2 UIE algorithm to make skill determination + load part of Understand.

### #292 — Resumption protocol for partial CDD artifacts

Suitability: high
Scope: ~1–2 commits, ~4 files
Why: Markdown-only edits to `CDD.md §1.4` plus α/β/γ SKILL.md resumption sub-sections. ACs name exact files and section anchors.
Risk: AC4 names `cn resume` directive — α must mark it forward-looking, not implement a CLI.
α focus: extend CDD.md §1.4 with a Resumption sub-clause + section-manifest format; add Resumption sub-sections to alpha/beta/gamma SKILL.md.

### #293 — Disambiguate cycle-tag vs disconnect-tag; lock CHANGELOG scoring sequence

Suitability: high
Scope: ~1–2 commits, ~5 files
Why: Pure spec disambiguation across `CDD.md`, `release/SKILL.md`, `post-release/SKILL.md`, `operator/SKILL.md`. Recommended option (A) is named in the body.
Risk: γ must accept "option A" in advance to keep α from re-deciding mid-dispatch.
α focus: implement option A — δ-only tag, β writes provisional TSC row, γ revises in PRA — touching the named files only.

### #296 — Issue-edit cache-bust convention + γ session branch formalization

Suitability: high
Scope: ~1–2 commits, ~5 files
Why: Six ACs map to specific sections of `CDD.md`, gamma/alpha/beta/operator SKILL.md. Uses #283's worked example.
Risk: AC6 references a worked example by commit SHA — α must include the citation, not invent new examples.
α focus: add cache-bust rule to CDD.md §Tracking; mirror γ session branch convention into CDD.md §1.4/§4.2 and the four role skills.

### #297 — docs(ctb): make TSC formal grounding explicit

Suitability: high
Scope: ~1–2 commits, ~1–2 files
Why: Primary file is `docs/alpha/ctb/SEMANTICS-NOTES.md §15.1` with optional touchpoint in v0.2 draft. Six well-bounded ACs.
Risk: Requires reading TSC (external repo) — α must not pull in TSC content, only reference sections.
α focus: add SEMANTICS-NOTES.md §15.1 stating TSC as formal upstream; map witness/verdict to CTB close-outs; cite TSC §10 composition bound without overclaiming.

### #309 — skill(eng): create eng/troubleshoot

Suitability: high
Scope: ~1 commit, 1 new file
Why: Single SKILL.md under `src/packages/cnos.eng/skills/eng/troubleshoot/`; AC list is concrete and the failure-evidence section in the issue body is the substrate.
Risk: AC4 wants 3 worked examples — α must lift them from the issue text rather than discover new ones.
α focus: author SKILL.md with frontmatter + triage-order algorithm + hypothesis discipline + 3 examples sourced from the issue body + handoff to `eng/rca`.

### #277 — Rewrite SOUL.md to skill form with UIE-V agent loop

Suitability: medium
Scope: ~2–3 commits, ~2–3 files
Why: Bounded surfaces (canonical SOUL skill + Sigma's SOUL derivation), but 13 ACs and substantial new prose.
Risk: 10-minute α budget is tight; β must verify against a long AC list. May need to be split (canonical artifact + Sigma derivation as separate cycles).
α focus: produce `cnos.core/skills/agent/SOUL.md` in skill form (frontmatter, UIE-V, named failure mode, kata) — defer Sigma derivation to a sibling cycle if scope tightens.

### #311 — core(agent): define triadic-agent contract

Suitability: medium
Scope: ~2–3 commits, ~2 files
Why: Pure design-note + contract-artifact work in `docs/alpha/agent-runtime/`; explicit non-goal of becoming a full design document.
Risk: 11 closure conditions and dense cross-references to TSC/CTB/#310 — strong prompt scoping required to avoid theory dump.
α focus: write design note picking the contract surface; produce the `tri(orientation, intervention, witness)` contract with one CDD example + one non-CDD example + counterexamples; update source map.

## Excluded issues (with one-line reason)

- **#310** — adds new CLI dispatch primitive in cnos.core (new command, not isolated).
- **#305** — extends `cn cdd-verify` binary (CLI/runtime work).
- **#303** — new `ctb-check` command, parser + fixtures (CLI tool build).
- **#295** — new `cn dispatch` CLI command (runtime + identity rotation).
- **#294** — new `cn cdd status N` CLI command.
- **#286** — multi-cycle redesign of γ encapsulation; depends on #295.
- **#285** — large cross-package refactor (cnos.core + cnos.cdd, frontmatter migration + composition operators).
- **#284** — introduces a new kind to LANGUAGE-SPEC; substantial spec extension.
- **#281** — explicitly blocked on #277 (writer-package redo).
- **#280** — requires operator decision before α can act; choice gates AC2/AC3.
- **#275** — substantive spec evolution (typed contract grammar, BNF, satisfaction relation, version bump).
- **#273** — pre-push git hook + installer + cross-language test fixture; mixes scripting and skill prose.
- **#271** — GitHub App registration + secrets wiring; out-of-repo platform action.
- **#269** — Telegram poster + significance-detection daemon; runtime infra.
- **#256** — multi-cycle CI rewrite with JSON contracts and per-run bundles.
- **#255** — umbrella tracker for CDD 1.0; no single deliverable.
- **#245** — multi-PR cleanup + executor wiring + first kata run.
- **#244** — umbrella tracker for kata 1.0.
- **#242** — substantial layout doctrine + verifier; requires operator decision A/B/C.
- **#241** — `cn identity` command + schema + isolation enforcement; deferred until MCI freeze.
- **#240** — protocol doctrine + cn-cdd-verify extension + end-to-end run; deferred until MCI freeze.
- **#218** — Rust transport package + subprocess protocol; new language and runtime boundary.
- **#216** — Go runtime package-command discovery + extracting four commands; multi-PR.
- **#193** — runtime executor wiring for `llm` step; depends on #182, deep runtime.
- **#192** — kernel rewrite OCaml → Go (massive).
- **#190** — agent web surface (browsable hub); web infrastructure.
- **#189** — native PR-equivalent threads; substrate work.
- **#186** — package restructuring across cnos.core and domain packages.
- **#181** — gh-pages package source endpoint; release plumbing.
- **#175** — CTB → orchestrator IR compiler; depends on #174.
- **#170** — orchestrators umbrella; sub-issues.
- **#168** — explicitly a tracking issue with no deliverable.
- **#156** — multi-step attached hub placement (executor/sync/deps/doctor).
- **#154** — canonical event layer; substrate.
- **#153** — thread event semantic spec; deep design.
- **#101** — three-cycle B14 corpus normalization (rename + classify + rewrites).
- **#100** — first-class memory faculty; design + skill + recall protocol.
- **#87** — bootstrap problem unresolved (cn binary not available to scheduled agent).
- **#79** — vision-level projection surfaces.
- **#77** — P2P vision.
- **#71** — voice/TTS infrastructure.
- **#70** — open-ended personality archetypes design.
- **#69** — first-wake setup experience design.
- **#68** — runtime introspection daemon.
- **#59** — `cn doctor` deep-check command.
- **#45** — B12 umbrella issue.
- **#44** — streaming runtime change.
- **#43** — interrupt mechanism in agent runtime.
- **#42** — Telegram parity multi-phase spine.
- **#35** — daemon mode + new skill.
- **#34** — runtime coherence loop with new trace events.
