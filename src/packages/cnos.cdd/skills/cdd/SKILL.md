---
name: cdd
description: Apply Coherence-Driven Development to substantial changes. Use when work spans design, code, tests, docs, runtime behavior, process, or release.
artifact_class: skill
kata_surface: embedded
governing_question: How does a substantial change move from observed incoherence to closed cycle with explicit artifacts and assessment?
triggers: [review, PR, release, issue, design, plan, assess, post-release, ship, tag]
---

# CDD

## Core Principle

A release is not the end of the method. Assessment and closure are part of the method.

## Algorithm

1. Define — observe the system, select the gap, name the incoherence, choose MCA or MCI.
2. Unfold — produce artifacts in order: design → contract → plan → tests → code (or delegated handoff §2.5a) → docs → self-coherence → review → gate → release → observe → assess.
3. Rules — enforce the mechanical invariants and leave semantic judgment explicit.

---

## 1. Define

### 1.1 Identify the parts

- observation inputs
- selected gap
- mode (MCA / MCI / both)
- artifact pipeline
- review
- gate
- assessment
- closure

  - ❌ "Pick an issue and start coding."
  - ✅ "Read CHANGELOG TSC, lag table, doctor/status, and the last assessment first."

### 1.2 Articulate how they fit

Observation chooses the next gap. The gap determines mode. Mode drives the artifact pipeline. The pipeline produces something reviewable. Release is measured by assessment. Assessment creates immediate fixes and next commitments. Closure feeds the next cycle.

  - ❌ Treat release as the finish line.
  - ✅ Treat release as the handoff into observation and assessment.

### 1.3 Name the failure mode

CDD fails through pipeline without selection or release without closure. Typical failures:

- work chosen by preference, not observation
- missing bootstrap or missing self-coherence
- review without an explicit contract
- release without assessment
- assessment that names debt but does not materialize it

---

### 1.4 Roles

CDD is triadic at the role level:

- **α** implements
- **β** reviews and releases
- **γ** coordinates and unblocks

| Role | Function | What they own | Identity constraint |
|------|----------|---------------|---------------------|
| **α (Implementer)** | Produce | Code, tests, fixes, self-coherence, pre-review readiness, PR | Must be separate from β |
| **β (Reviewer + Releaser)** | Judge and integrate | Review (RC/A decision), merge, tag, deploy, post-release assessment | Must be separate from α |
| **γ (Coordinator)** | Orchestrate | Issue creation, dispatch prompts, unblocking, cross-agent context, compliance verification | Must hold full cycle context |

#### Flow

```
γ (issue + dispatch) → α (implement + PR) → β (review) → RC → α (fix) → β (re-review)
                                                        → A  → β (merge, tag, deploy, assess)
                       γ (unblocks α or β when stuck)
```

#### Why these roles

The structure is a **dyad plus coordinator**: α and β are two workers that interact through artifacts, isolated from each other. γ coordinates the dyad — sees both sides, does neither.

- α cannot see β's review reasoning or conversation state
- β cannot see α's implementation rationale or conversation state
- γ sees both — that is its function

β owns both review and release because the reviewer already has full artifact context when it's time to merge — splitting review from release creates a handoff that adds no value. γ owns coordination because issue quality determines implementation quality, dispatch prompts are the control surface, and unblocking requires cross-agent context that only the coordinator holds.

- **α** owns the artifact — their output is what α scores
- **β** owns judgment and what the system becomes after integration — what β scores
- **γ** owns cycle coherence — issue clarity, prompt completeness, inter-agent flow

#### γ algorithm

1. Observe and select the gap (§2.0)
2. Create the issue with full implementation guidance (issue skill §2.4), including Tier 3 skills
3. Write α dispatch prompt (see format below)
4. When α opens PR and CI is green, write β dispatch prompt (see format below)
5. If α or β is blocked, diagnose and unblock: clarify requirements, resolve ambiguity, provide missing context
6. After β releases, collect close-outs from both α and β
7. Review both close-outs. Triage each finding using CAP:
   - MCA available (skill patch, gate, mechanization) → ship it now as immediate output
   - No MCA yet, pattern real → MCI. Two kinds:
     - **Project MCI** (future cycles on this project need to know) → `.cdd/` in the repo
     - **Agent MCI** (future sessions of this agent need to know, any project) → agent hub (`cn-<agent>/threads/adhoc/`)
   - One-off, no pattern → drop
8. If any §9.1 trigger fired, verify Cycle Iteration section exists in assessment
9. Cycle closed when: assessment committed, close-outs reviewed, immediate outputs executed

#### γ dispatch prompt format

**To α:**
```
You are α. Project: <project>.
Load src/packages/cnos.cdd/skills/cdd/SKILL.md and follow the α algorithm (§1.4).
Issue: gh issue view <number>
```

**To β:**
```
You are β. Project: <project>.
Load src/packages/cnos.cdd/skills/cdd/SKILL.md and follow the β algorithm (§1.4).
PR: gh pr view <number>
Issue: gh issue view <number>
```

Parameters: `<project>` is the project name (e.g. `cnos`, `myapp`). Git identity uses `<role>@cdd.<project>` (e.g. `alpha@cdd.cnos`). `<number>` is the issue or PR number.

The prompt names the role, provides parameters, and points to the issue or PR. The CDD skill tells each role what to load (§4.4 tiers) and what to do (§1.4 algorithm). γ does not enumerate skills or steps in the prompt — that is the skill's job. If the prompt needs to restate the algorithm, the algorithm is not clear enough — fix the skill.

#### α algorithm

1. Receive dispatch prompt from γ
2. Configure git identity using the project name from the dispatch prompt: `git config user.name "alpha"` and `git config user.email "alpha@cdd.<project>"`
3. Load CDD skill (this file), load all Tier 1 + Tier 2 skills (§2.4), load Tier 3 skills from the issue
4. Read the issue fully, read source files referenced in implementation guidance
5. Implement: branch, code, tests, self-coherence
6. Open PR (draft if CI unavailable locally), wait for CI green
7. Subscribe to PR notifications (do not wait for operator to prompt)
8. Request review from β
9. If β returns RC: fix findings, push, re-request review
10. When β approves: write α close-out (cycle findings or "no findings")
11. Done

**α close-out:** Report cycle-level learnings to γ. Must include one of:
- Concrete findings: skill gaps, process friction, tooling issues, things that should be mechanized
- "No new findings" — explicitly stated, not omitted

This is α's input to γ's cycle iteration decision (§9.1).

#### β algorithm

1. Receive dispatch prompt from γ (or pick up from α's review request)
2. Configure git identity using the project name from the dispatch prompt: `git config user.name "beta"` and `git config user.email "beta@cdd.<project>"`
3. Load CDD skill (this file), load all Tier 1 + Tier 2 skills (§2.4), load Tier 3 skills from the issue
4. Read the PR diff, read the issue
5. Review: produce CR with findings per review skill, or approve
6. If RC: post findings as PR comment, wait for α's fix
7. If A: merge, tag, deploy per release skill
8. Write post-release assessment per post-release skill
9. Write β close-out (cycle findings or "no findings")
10. Done when assessment and close-out are committed

**β close-out:** Report cycle-level learnings to γ. Must include one of:
- Concrete findings: review pattern issues, skill gaps surfaced during review, process friction, §3.7 violations observed, things that should be mechanized
- "No new findings" — explicitly stated, not omitted

This is β's input to γ's cycle iteration decision (§9.1).

#### Minimum configuration

Two agents: one for α, one for β. γ may be the operator or a third agent. When only two agents are available, the operator serves as γ (issue creation, dispatch, unblocking).

#### Operator override

The operator may reassign any role explicitly. Implicit role drift is not permitted — if β requests changes, α executes the fix.

**Small-change exception:** A small-change cycle (§1.2) may be completed by one agent if the change qualifies under §1.2, no claim of independent review is made, and the artifact states that small-change mode was used.

  - ❌ One agent authors, reviews, merges, and assesses its own substantial change.
  - ❌ Author self-approves and self-releases under the guise of triadic roles.
  - ❌ γ implements or reviews — γ coordinates.
  - ✅ γ dispatches → α implements → β reviews and releases.

## 2. Unfold

### 2.0 Observe and select

Read, in order:

1. CHANGELOG TSC table
2. encoding lag table
3. doctor / status
4. last post-release assessment

Selection rules:

- P0 override first — but only if the P0 is new since the last assessment or has escalated. Known P0s that were weighed and deferred are not overrides.
- operational infrastructure debt second — but size it first: if the fix is minutes of work, execute as immediate output and continue to §3.3. Only select as cycle gap when it requires design/tests/review.
- last assessment's Next MCA is the default unless overridden
- stale lag set freezes new design work
- then weakest axis
- then leverage
- then dependency order
- then effort-adjusted tie-break

If no gap exists, do not force a substantial cycle. Remain in observation or use the small-change path.

### 2.1 Branch

Create a dedicated branch before artifacts.

Format:

```text
{agent}/{version}-{issue}-{scope}
```

or, if version is not known:

```text
{agent}/{issue}-{scope}
```

Pre-flight:

- version valid
- no duplicate branch
- no duplicate open PR
- branch format valid
- CI/main state known
- scope declared

### 2.2 Bootstrap

First diff on a substantial branch:

```text
docs/{tier}/{bundle}/{X.Y.Z}/
```

with:

- README.md
- one stub per declared deliverable

Version directories freeze after release except for path-reference repair.

### 2.3 Name the gap

State:

- what incoherence exists
- why it matters
- what fails if skipped

### 2.4 Choose mode and active skills

- MCA → change the system
- MCI → change the model
- both when required
- MCA first when coherent action is possible
- when in doubt, apply CAP: if the answer is already in the system, cite it (MCA) — don't reinvent it (MCI). If two paths close the same gap, take the lighter one unless the heavier one buys durability the lighter one cannot.

State why MCI is required if action is blocked.

#### Skill loading tiers

Skills are loaded in three tiers. All tiers are mandatory for substantial changes.

**Tier 1 — CDD lifecycle (always loaded):**
All skills under `cdd/` — the master CDD skill plus sub-skills (issue, design, review, release, post-release). These define the lifecycle every role follows.

**Tier 2 — General engineering (always loaded):**
All general skills under `eng/` that apply regardless of domain: coding, design-principles, ship, testing, documenting, process-economics, rca, follow-up, writing, skill. These constrain how any code is written.

**Tier 3 — Issue-specific (selected per issue):**
Skills that depend on what the work touches. The issue's "Skills and constraints" section (issue skill §2.4) names these explicitly. Examples:
- Language: `eng/go`, `eng/ocaml`, `eng/typescript`
- Domain: `eng/ux-cli`, `eng/performance-reliability`, `eng/tool-writing`
- Architecture: `eng/architecture-evolution`, `eng/functional`

The issue must name Tier 3 skills. If the issue doesn't name them, α identifies them from the work shape before coding.

**Read each SKILL.md file before beginning any work step.** Naming a skill without reading it is not loading it. (CDD §4.4)

**Load project invariants.** If the project maintains an architectural invariants document (e.g. `INVARIANTS.md`), load it and identify which active invariants and transition constraints are touched by this change. Name them explicitly. The reviewer will verify them (review §2.2.13).

### 2.5 Build artifacts in order

For substantial changes:

1. design
2. coherence contract
3. plan
4. tests
5. code
6. docs
7. self-coherence

Do not invert the order casually. Each step should reduce uncertainty for the next.

**Pre-coding gate (before step 5):** Before writing code, confirm:
- Active engineering skills are loaded (not just named — read the SKILL.md files)
- Project invariants are loaded and affected constraints identified (§2.4)
- Engineering skill rules that derive from those invariants are understood (e.g. eng/go §2.17 derives from INVARIANTS.md T-004, §2.18 derives from T-002)

This gate exists because implementation agents produce correct features with wrong boundaries when invariants are loaded at review time but not at coding time.

### 2.5a Delegated implementation handoff

When implementation is delegated to another agent (Claude Code, sub-agent, human contractor), the prompt or brief is the contract. The receiving agent does not have session context, prior cycle learnings, or loaded skills.

The handoff must include:

1. **Active skills by name + location** — not just "follow best practices." The implementer must be told which SKILL.md files constrain the work and where to find them.
2. **Test requirements per module** — which new modules need tests, what coverage shape (unit, integration, expect-test), and what invariants the tests must prove. "Run dune runtest" is a gate, not a test spec.
3. **Engineering conventions from prior cycles** — any relevant precedent that the implementer would not know. Examples: "v3.32.0 removed all bare `with _ ->` catches — do not reintroduce them," "lockfile types live in cn_deps.ml, not cn_lib.ml."
4. **Artifact order** — the handoff must specify tests-before-code (§2.5) or explicitly justify inversion. A prompt that describes only code stages implicitly inverts the pipeline.
5. **Affected project invariants** — if the project maintains an architectural invariants document, name the specific invariants this change touches. The implementer must not violate active invariants or move away from transition constraints. The reviewer will verify (review §2.2.13).

**Why this is mechanical, not judgment:** a checklist on the handoff, not a review finding after the fact. Two agents writing the same handoff should produce the same constraints. Review catching convention violations that the handoff should have prevented is a process bug — the gap is in the handoff, not the review.

**Self-verification gate:** The handoff must require the implementer to produce a self-verification report before declaring completion. The report must include:

1. **Active skill compliance** — for each named active skill, state which rules were followed and whether any were violated. Evidence: grep or line reference, not "I followed it."
2. **Test coverage** — for each new module, state: tests exist (yes/no), what invariants they prove, what is untested and why.
3. **Convention compliance** — for each named convention, state: complied (yes/no), evidence.
4. **Artifact order** — state whether tests preceded code, or justify inversion.

The self-verification report is the implementer's exit gate. Without it, the handoff is incomplete — even if CI passes. CI proves the code compiles. The report proves the code satisfies the project's constraints.

Failure mode: the handoff describes *what to build* but not *how the project constrains building it*. The implementer produces correct features with wrong engineering conventions. Or: the handoff includes constraints but the implementer has no gate requiring them to verify compliance — constraints are sent but never checked.

  - ❌ "Build HTTP restore, command discovery, and doctor validation. Run dune build before committing."
  - ❌ "Build with these constraints: [good list]" (no self-verification gate — constraints sent, never checked)
  - ✅ "Build HTTP restore, command discovery, and doctor validation. Active skills: ocaml (src/agent/skills/eng/ocaml/SKILL.md — §3.1: no bare `with _ ->`, use Result types), testing (test each new module with ppx_expect). Convention: v3.32.0 removed all silent exception swallowing — do not reintroduce. Artifact order: tests before code per CDD §2.5. Before declaring complete: produce a self-verification report covering skill compliance, test coverage per module, convention compliance, and artifact order."

### 2.5b Pre-review (author-side mechanical gate)

Before opening or refreshing the pull request — i.e., before
asking the reviewer to look — the author runs a mechanical
gate. This is a checklist, not judgment; two authors on the
same branch must produce the same answer.

1. **Branch rebased onto current `main` at ready-for-review time.** `git fetch origin main && git rebase origin/main` immediately before requesting review (not just at branch creation). If main moved between PR open and review request, rebase again. The reviewer must see only this cycle's delta. A diff that contains commits already merged into main on a parallel branch is a process bug — it forces the reviewer to mentally subtract noise and risks reverting other cycles' work.
2. **Self-coherence artifact present.** §2.5 step 7 must have produced a SELF-COHERENCE.md (or its equivalent for small-change cycles), and the PR body must link or include the CDD Trace through the current step.
3. **CDD Trace in the PR body.** §5.4 of the canonical spec mandates that for L5/L6 cycles the PR body is the primary branch artifact carrying the trace. For L7 cycles the design artifact carries the trace and the PR body links to it.
4. **Tests reference ACs.** Each AC the cycle promised should have at least one named test or "not applicable, justified" note in the PR body.
5. **Known debt explicit.** Anything intentionally deferred is named in the PR body so the reviewer doesn't waste a round flagging it.
6. **Schema/shape audit across test fixtures.** If this PR changes a JSON schema, manifest shape, op envelope, receipt format, or any string-literal contract that test fixtures construct, grep `test/` for the old shape and audit every match. Update each fixture in the same commit. The §2.2.1b sibling-audit discipline (which historically applied to production modules only) is hereby extended to also cover test fixtures when a contract changes — *"R1 fix only touched the file the reviewer named, R2 found the same root cause in a sibling test file"* is the recurring failure mode this check exists to prevent.
7. **Workspace-global library-name uniqueness.** If this PR adds a new `(library (name X))` stanza to any dune file, grep the entire workspace for existing `(name X)` entries first: `grep -rn "(name X)" src/ test/`. Two libraries cannot share a workspace-global name — dune rejects duplicates at build time. The grep is a once-per-new-library check; rename proactively if there is any collision (e.g. `cn_contract_test` → `cn_contract_pure_test` when a same-named library already exists in a sibling directory). This check exists because a library name collision in `test/lib/dune` reached CI red in PR #195 (v3.39.0) — the §2.5b check set held every semantic check but had no lane for "workspace-global namespace collision", and the no-local-OCaml authoring constraint meant `dune build` was not available to catch it before push.
8. **CI green on the head commit before requesting review.** Before requesting review — `gh pr create` for a new PR, marking a draft PR as "ready for review," or posting a review-request comment — the latest CI run on the head commit must be green. If CI is red (including on initial push), fix the failure and push before requesting review. A red CI state is a mechanical failure the author must resolve; asking the reviewer to act as a compiler wastes their time and review rounds. **Mechanism**: when a local build/test toolchain is unavailable, open the PR as **draft**, wait for CI, then mark ready-for-review. Draft PRs exist specifically for this flow. Do not "just open and hope" — any environmental constraint that prevents local verification (no OCaml toolchain in the sandbox, cross-compilation targets the author cannot exercise, etc.) is absorbed by the draft-until-green pattern rather than leaked into review rounds. This check was added in v3.40.0 after two consecutive cycles (#195 F1 library name collision, #197 F1 expect-test stderr mismatch) where mechanical failures reached the reviewer because the author had no way to verify locally — both would have been caught by a single `dune runtest` that was structurally unavailable.

This gate exists because four failure-mode classes (rebase artifact
in the diff, fixture-drift across multi-file test families,
workspace-global library-name collisions, and mechanical CI failures
reaching the reviewer) recurred across consecutive review rounds
before being mechanized here. Each item is a once-per-PR check that
closes a finding class the reviewer would otherwise have to catch.

  - ❌ Open the PR from a branch cut three days ago without checking whether main has moved.
  - ✅ `git fetch origin main && git rebase origin/main` immediately before `gh pr create`.
  - ❌ R1 finds a stale fixture in `test/cmd/cn_command_test.ml`; you fix only that file; R2 finds the same root cause in `test/cmd/cn_runtime_contract_test.ml`.
  - ✅ R1 finds a stale fixture; you `grep -rn '<old-shape-substring>' test/`; you fix every file in one commit; R2 is approval.
  - ❌ Add `(library (name cn_contract_test) ...)` to `test/lib/dune` without checking `test/cmd/dune`; CI red on dune duplicate-name error.
  - ✅ Before committing, `grep -rn "(name cn_contract_test)" src/ test/` → collision found; rename to `cn_contract_pure_test` in dune stanza + file + library name; commit once.
  - ❌ Open a PR with red CI and wait for the reviewer to report the mechanical failure.
  - ✅ Open the PR as draft; wait for CI green; then mark ready-for-review. The reviewer only sees judgment-level review.

### 2.6 Review

Use CLP. Ask for:

- α / β / γ separately
- weakest-axis diagnosis
- concrete patches
- iterate or converge

### 2.7 Gate

Before release verify:

- required artifacts exist
- ACs accounted for
- docs and code agree
- snapshot ready
- previous release assessed
- known debt explicit

### 2.8 Release

Delegate release mechanics to `cdd/release/SKILL.md`. CDD owns:

- when release is allowed
- what must already be true

### 2.9 Observe, assess, close

After release:

- observe runtime/design alignment
- write the post-release assessment
- if a §9.1 trigger fired (review rounds > 2, mechanical ratio > 20%, avoidable tooling failure, loaded skill failed to prevent a finding): write a `## Cycle Iteration` section in POST-RELEASE-ASSESSMENT.md using the §9.1 template (triggers fired, friction log, root cause, skill impact, MCA, cycle level L5/L6/L7). Also record cycle level in CHANGELOG TSC as suffix `(cycle: LN)`. Patch any skill that failed to prevent a finding it covers as immediate output. Cycle cannot close without this section if triggered. (CDD §9.1, §10.3)
- execute immediate outputs (including skill patches from cycle iteration)
- commit deferred outputs concretely

Skill/spec patches produced as immediate outputs must pass CLP β: does this change create a mismatch with any canonical or derived surface? If the skill has a canonical spec (§5), both must be updated together.

A cycle is not closed until both classes of output are handled.

---

## 3. Rules

### 3.1 Mechanize invariants, not judgment

Mechanical:

- branch naming
- duplicate-branch check
- bootstrap presence
- AC accounting
- stale cross-ref check
- snapshot freeze
- gate checks

Judgment:

- real gap
- MCA vs MCI correctness
- triadic score substance
- review convergence
- stop/continue decision

  - ❌ Ask tooling to decide what the right design is.
  - ✅ Ask tooling to prove that the required artifacts and checks exist.

### 3.2 One canonical source per development fact

Do not duplicate:

- version facts
- capability lists
- contract fields
- AC state
- release metadata

Derive secondary surfaces from the canonical one.

### 3.3 Build-sync source assets

If you edit anything under `src/agent/`, run `cn build` before commit so packaged copies stay in sync.

### 3.3a Authority-sync on skill/spec changes

If you edit an executable skill that declares a canonical source (§5), verify the canonical source is updated in the same commit. If you edit a canonical spec, verify derived skills are updated. One-directional edits to paired surfaces create β drift — the review caught this in `20add78` (skill updated, spec not).

### 3.4 No review without a contract

A reviewer should never have to infer:

- what the gap is
- what the mode is
- what ACs were promised

### 3.5 No release without assessment

A release without assessment is incomplete CDD.

### 3.6 No closure without execution or commitment

Immediate outputs must be executed now. Deferred outputs must be recorded concretely as next-cycle commitments.

### 3.7 No direct-to-main without retro-closure (§12)

If a substantial change lands directly on main without a branch or PR, the canonical spec §12 (retro-packaging rule) requires: retro-snapshot, self-coherence artifact, and version-history entry. In addition, on public repos the author must immediately open a retro-review issue. Content quality does not excuse a skipped review surface. (#137)

---

## 4. Pipeline Reference

The master pipeline tables live in the canonical spec:

- **Step lifecycle:** `docs/gamma/cdd/CDD.md` §4.1 (steps 0–13, purpose, required output)
- **Artifact manifest:** `docs/gamma/cdd/CDD.md` §5.3 (step, evidence, format, owner, producer, skill)

This skill does not duplicate those tables. If this skill and the canonical doc disagree, the canonical doc governs (§6).

---

## 5. Delegation

CDD owns the lifecycle. Sub-skills own execution details:

- design → `cdd/design/SKILL.md`
- review → `cdd/review/SKILL.md`
- release → `cdd/release/SKILL.md`
- post-release assessment → `cdd/post-release/SKILL.md`

CDD defines what must happen and in what order. Sub-skills define how.

---

## 6. Authority

This skill is the executable summary. The canonical algorithm spec is:

```
docs/gamma/cdd/CDD.md
```

If this skill and the canonical doc disagree, the canonical doc governs.

---

## 7. Reference

- canonical spec: `docs/gamma/cdd/CDD.md`
- rationale: `docs/gamma/cdd/RATIONALE.md`
- post-release assessment: `cdd/post-release/SKILL.md`
- review protocol: `cdd/review/SKILL.md`
- design protocol: `cdd/design/SKILL.md`
- release procedure: `cdd/release/SKILL.md`
- coherence history: `CHANGELOG.md`

---

## 8. Kata

### Scenario

A substantial docs/process change has been selected from the lag table and must be carried through to release.

### Task

Produce:

- mode + active skills
- primary branch artifact
- trace through review/gate/release
- post-release assessment closeout

### Governing skills

- cdd
- design
- review
- release
- post-release

### Expected artifacts

- one primary branch artifact with CDD Trace
- one review surface
- one gate surface
- one release surface
- one post-release assessment

### Verification

- lifecycle steps are evidenced
- active skills are explicit
- immediate and deferred outputs are both handled

### Common failures

- release without assessment
- review without contract
- direct-to-main without retro-closure
