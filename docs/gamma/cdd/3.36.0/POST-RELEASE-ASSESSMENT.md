## Post-Release Assessment — v3.36.0

**Release commit:** 4ac06a6
**Cycle:** #174 — Orchestrator IR runtime
**PRs:** #179 (feature) merged at e1fe3f8
**Branch (this assessment):** claude/post-release-3.36.0
**Skill loaded:** `packages/cnos.core/skills/cdd/post-release/SKILL.md` (re-read in full this session)

### 1. Coherence Measurement

- **Baseline:** v3.35.0 — C_Σ A− · α A · β A− · γ B+ · L6
- **This release:** v3.36.0 — C_Σ A · α A · β A · γ A− · L7
- **Delta:**
  - **α held A.** Type design is clean: polymorphic-variant stepper
    (`` `Terminal | `Continue | `Jump ``), bounded `outcome`, pure
    parser returning `result` (never raises), exhaustive variant
    coverage on every step kind. The naming-collision resolution
    (`Cn_workflow` vs the pre-existing `Cn_orchestrator` for the
    N-pass LLM bind loop) is documented in both the module
    docstring and the self-coherence — not a hidden trap.
  - **β improved (A− → A).** The dueling-schema problem from
    #173 was resolved: `build_orchestrator_registry` rewritten to
    consume `Cn_workflow.discover` instead of reading inline
    `[{name, trigger_kinds}]` objects from `sources.orchestrators`.
    `sources.orchestrators` is now a string-id array per
    ORCHESTRATORS.md §9, the per-orchestrator metadata lives in the
    orchestrator.json file, and the runtime contract projects
    trigger_kinds from `orch.trigger.kind`. Three obsolete tests
    replaced with new-schema equivalents. Single reader, single
    schema, single source of truth.
  - **γ improved (B+ → A−).** Review converged in 2 rounds (within
    target ≤2). Sibling audit on `cn_build.ml` held — 5 pre-existing
    bare catches caught and cleaned during the touched-file sweep.
    The minus is honest: mechanical ratio 40% (2/5 findings) is over
    the 20% threshold, and one of those mechanical findings (F1
    rebase artifact) is the v3.35.0 post-release corrective not
    holding — same failure class two cycles in a row. See §3 + §4.
- **Coherence contract closed?** Partially. All seven #174 ACs were
  met as written, but two carry honest deferrals:
  - **AC3** (step execution): 5 of 6 step kinds execute
    (`op`, `if`, `match`, `return`, `fail`). The `llm` step is a
    guarded stub — parsed, validated, permission-checked, emits
    "not yet implemented in this release" at runtime with a
    matching test (X5). The prompt + context injection mechanism is
    next cycle's design work.
  - **AC7** (real orchestrator shipped): `daily-review` parses and
    `cn doctor`-validates cleanly, but its step 2 is an `llm` step,
    so end-to-end execution would fail at runtime today. Schema-
    clean, not run-clean. The next cycle closes this gap.

  The coherence contract for #174 is met as a workflow IR runtime;
  it is not yet met as an executable workflow surface for the
  shipped orchestrator. §7 Next Move addresses this directly.

### 2. Encoding Lag

| Issue | Title | Type | Design | Impl | Lag |
|-------|-------|------|--------|------|-----|
| #174 | Orchestrator IR runtime | feature | ORCHESTRATORS.md §7–8 | **shipped** (5 of 6 step kinds; `llm` deferred) | none (partial) |
| TBD | Orchestrator runtime: `llm` step execution + binding substitution | feature | needs design (PLAN-174 §Risk) | not started — **next MCA** | new |
| #175 | CTB → orchestrator IR compiler | feature | CTB-v4.0.0-VISION.md | not started (depends on `llm` execution) | growing |
| #162 | Modular CLI commands | feature | converged | not started | growing |
| #168 | L8 candidate tracking | process | adhoc thread | observation only | low |
| #154 | Thread event model P1 | feature | converged | not started | stale |
| #153 | Thread event model | feature | converged | not started | stale |
| #100 | Memory as first-class faculty | feature | partial | not started | stale |
| #94 | cn cdd: mechanize CDD invariants | feature | partial | not started | stale |

**MCI/MCA balance:** **balanced**, not at freeze threshold but
approaching. 2 issues at growing (#175, #162) — below the ≥3
freeze trigger. 1 partial-shipped (#174's `llm` gap), 4 stale, 1
low. The stale set is the long-tail concern but does not by itself
trigger freeze under the post-release skill's §4 rules.

**Rationale:** #170's pipeline ordering held this cycle: #173
shipped the registries (v3.35.0), #174 shipped the workflow runtime
(v3.36.0). #175 (CTB compiler) is unblocked at the IR-shape level
but blocked at the execution level by the `llm` gap. Closing the
`llm` gap is the next concrete capability — that's why §7 names it
as next MCA rather than picking #175 directly.

### 3. Process Learning

**What went wrong:**

1. **PR #179 was opened without rebasing onto current main.**
   F1 was a D-level mechanical finding: the diff carried reversed
   v3.35.0 assessment files because the branch was cut from
   `29eeb29` before `9d27558` (the v3.35.0 post-release squash)
   landed. **This is the v3.35.0 post-release corrective NOT
   HOLDING** — the v3.35.0 assessment §7 explicitly named
   "rebase before opening PR" as the next-cycle discipline. Two
   cycles in a row, same failure class.
2. **README impact graph carried stale module names** through to
   review. F2 (D, mechanical): four references to `cn_orchestrator
   .ml` / `cn_orchestrator_test.ml` after the naming-collision
   resolution renamed them to `cn_workflow.ml`, plus
   `cn_runtime_contract.ml` listed under "Untouched" while the
   diff had 92 changed lines. The README was drafted before the
   rename and not re-read after.
3. **`Op_step.inputs` and `Llm_step.inputs` were dead code at
   author time.** F3 (C, judgment): both fields were parsed but
   never read by the executor. A "every parsed field is consumed"
   audit during type design would have caught it. The reviewer
   correctly named this as architecturally interesting — the
   binding-substitution mechanism it implies is the same gap that
   blocks `llm` step execution (next cycle's headline).
4. **Top-level `inputs: {requires_hub: true}` in daily-review.json
   was unvalidated.** F4 (B, judgment): aspirational field that
   the parser silently ignored. Test against the parser's actual
   field set, not against an aspirational schema, would have
   caught it.
5. **`match` step had no direct execution test at gate time.**
   F5 (B, judgment): self-coherence at gate time explicitly named
   this as a known gap, but the gap itself was not closed before
   opening review. "Self-acknowledged at gate" is not the same as
   "fixed before review."

**What went right:**

1. **Naming collision resolved cleanly at authoring time.**
   `Cn_workflow` vs the pre-existing `Cn_orchestrator` was caught
   before any code was written; the new module took the new name;
   the in-module docstring + the self-coherence both name the
   distinction. Zero downstream confusion.
2. **Dueling-schema elimination held.** The #173 inline-object
   `sources.orchestrators` schema was rewritten end-to-end to the
   §9 string-id-array shape. `build_orchestrator_registry`
   consumes `Cn_workflow.discover`; three obsolete tests replaced
   with new-shape equivalents in the same diff. No flag-day
   migration drama.
3. **Sibling audit on `cn_build.ml` actually happened.** Touching
   the module triggered the §2.2.1b sweep and surfaced 5
   pre-existing bare `with _ ->` catches in `copy_tree`,
   `rm_tree`, wildcard copy, `discover_packages`, and the
   `diff_tree` error path. All cleaned with logged context. This
   is the discipline the v3.35.0 cycle's R2 round flagged as
   missing — held this cycle.
4. **Test-first held.** 18 ppx_expect tests for the workflow
   surface authored before any executor code. Three more (X6, X7,
   X8) added in R2 to close the F5 gap, bringing the total to 21.
5. **Review converged in 2 rounds.** R1 surfaced 5 findings in
   one fix commit (`0d4ba38`). R2 was a clean approval. No
   superseded PRs.
6. **`llm` deferral was honest.** Parsed, validated, permission-
   checked, returns "not yet implemented" at runtime with a
   matching test (X5). Not silently broken; the runtime gives a
   clear failure message.

**Skill patches (immediate output, mandatory per skill §3):**

The recurring rebase-artifact failure (F1 in v3.35.0 cycle, F1 in
v3.36.0 cycle) is a **repeatable failure mode**. Per the
post-release skill's §3 rule ("If a repeatable failure mode is
identified, patch the skill NOW — not next session"), this
assessment commit also includes a skill patch:

- **Patch:** `src/agent/skills/cdd/SKILL.md` and the mirrored
  `packages/cnos.core/skills/cdd/SKILL.md` (build-sync per CDD
  §3.3) gain a new pre-PR mechanical gate under §2.6 Review:
  the author must rebase the branch onto current main before
  asking for review, so the reviewer sees only this cycle's
  delta. The corresponding row is added to `docs/gamma/cdd/CDD.md`
  §5.3 step table per the §3.3a authority-sync rule. The patch
  is co-committed with this assessment.
- **Why a skill patch and not just a noted commitment:** the same
  corrective was already noted as a deferred output in the
  v3.35.0 assessment §7. Nothing landed at the skill level, and
  the v3.36.0 cycle reproduced the failure. A noted commitment is
  insufficient when the failure mode is recurring.
- **What this does NOT patch:** the underlying tooling gap (no
  OCaml in the authoring sandbox) is unchanged — that's an
  environment constraint, not a skill specification gap. Soft
  trigger remains for the fourth cycle in a row.

**Active skill re-evaluation:**

| Finding | Loaded skill | Would skill have prevented it? | Disposition |
|---------|-------------|-------------------------------|-------------|
| F1 (rebase artifact) | cdd | Partially — §2.1 covers branch creation, not pre-PR rebase | **Skill patched this commit** (new pre-PR gate in §2.6 + canonical spec) |
| F2 (stale README refs) | eng/coding "read twice" + cdd | Yes — re-read after rename would have caught it | Application gap |
| F3 (dead `inputs` field) | eng/ocaml §2.1 "every field is consumed" | Yes — basic type hygiene during design | Application gap |
| F4 (unvalidated daily-review `inputs`) | eng/ocaml + eng/testing | Yes — parser-output happy-path test would have caught it | Application gap |
| F5 (no `match` execution test) | eng/testing "every branch tested" | Yes — self-coherence already named this at gate | Application gap (self-acknowledged) |

One skill gap (F1 → patched this commit), four application gaps
(skill was right, author didn't apply it deeply enough). No
further skill patches required by F2–F5.

### 4. Review Quality

**PRs this cycle:** 1 (#179)
**Review rounds:** 2 (R1 request changes → R2 approved) — within
the ≤2 target for code PRs
**Superseded PRs:** 0 — within the 0 target
**Finding breakdown:**

| # | Finding | Severity | Type |
|---|---------|----------|------|
| F1 | Rebase artifact (reversed v3.35.0 assessment files) | D | mechanical |
| F2 | Stale README impact graph (`cn_orchestrator.ml` references; `cn_runtime_contract.ml` mis-classified) | D | mechanical |
| F3 | `Op_step.inputs` / `Llm_step.inputs` dead in executor | C | judgment |
| F4 | Top-level `inputs` field in daily-review.json unvalidated | B | judgment |
| F5 | `match` step has no direct execution test | B | judgment |

**Mechanical ratio:** 2/5 = **40%** — over the 20% threshold.

**Action (per skill §4 rule "filed and referenced, not just noted"):**
The corrective is not a deferred issue — it is **executed immediately
in this commit** as a skill patch (cdd/SKILL.md §2.6 + CDD.md §5.3).
The patch closes the recurring rebase-artifact failure class at the
skill specification level. F2 (stale README) does not require a skill
patch — eng/coding §"read twice" already covers it; the gap was
application, not specification.

This is the §3 / §4 rule in action: a recurring mechanical failure
mode triggers an immediate skill-level fix; non-recurring mechanical
findings get noted as application gaps.

### 4a. CDD Self-Coherence

- **CDD α (artifact integrity): 4/4.** All required cycle artifacts
  present in `docs/gamma/cdd/3.36.0/`: README, SELF-COHERENCE, GATE,
  and now POST-RELEASE-ASSESSMENT (this file). PLAN-174 lives at
  `docs/alpha/agent-runtime/PLAN-174-orchestrator-runtime.md` (a
  legitimate variant — design-adjacent plans live in the alpha tree
  when they're closer to the design than to the cycle ledger). CDD
  Trace table present in both the README and the PR #179 body
  through step 9.
- **CDD β (surface agreement): 3/4.** One β miss surfaced in review:
  the README impact graph (F2) diverged from the code surface after
  the naming-collision rename was applied without a re-read pass.
  The substantive surfaces — ORCHESTRATORS.md §9 schema, parser,
  validator, runtime contract registry, doctor, and the daily-review
  manifest — all agree end-to-end after the dueling-schema fix. The
  4-vs-3 split is not for the doc-vs-code drift alone; it's because
  the same drift class (docs lagging code rename) is exactly the
  gap eng/coding §"read twice" covers and was not applied.
- **CDD γ (cycle economics): 3/4.** Review converged in 2 rounds
  (within target). Superseded PRs 0 (target met). Mechanical ratio
  40% — over the 20% threshold (γ hit). Tooling gap (no local
  OCaml) for the fourth cycle in a row (γ hit). Immediate outputs
  executed in this commit (skill patch + post-release file).
  Deferred outputs committed concretely in §7.
- **Weakest axis:** γ (mechanical ratio + tooling gap).
- **Action:** **patched this commit** — `cdd/SKILL.md` + `CDD.md`
  gain the pre-PR rebase mechanical gate. The tooling gap is an
  environment constraint, not a skill gap; no skill action available
  beyond the existing post-release acknowledgement.

### 5. Production Verification

**Scenario:** A consumer hub upgraded to cnos.core 3.36.0 can
discover, validate, and dispatch the shipped `daily-review`
orchestrator end-to-end **except** at its `llm` step. The agent's
runtime contract on wake includes `body.orchestrators` with the
daily-review entry, and `cn doctor` reports the orchestrator
healthy.

**Before this release:**
- No workflow runtime existed.
- `cn doctor` had no orchestrator surface.
- `body.orchestrators` in the runtime contract was populated from
  the inline `[{name, trigger_kinds}]` schema in
  `sources.orchestrators` (#173 dueling-schema), which no real
  package conformed to — so the registry was always empty.

**After this release:**
- `Cn_workflow.discover` walks
  `.cn/vendor/packages/<name>@<v>/orchestrators/<id>/orchestrator.json`
  and loads each one.
- `cn doctor` reports `Orchestrators: 1 healthy` for cnos.core (the
  daily-review manifest parses + schema-validates).
- The runtime contract's `body.orchestrators` projects each loaded
  orchestrator to `{name, source, package, trigger_kinds}` with
  `trigger_kinds` derived from `orch.trigger.kind` (a one-element
  list in v1).
- A consumer attempting to actually run daily-review end-to-end
  hits the `llm` step and gets the documented "not yet implemented
  in this release" failure with a `workflow.step.complete`
  trace event tagged `Error_status` + `reason="llm_not_implemented"`.

**How to verify:**
1. On a hub with cnos.core 3.36.0 installed:
   `cat .cn/vendor/packages/cnos.core@3.36.0/orchestrators/daily-review/orchestrator.json`
   → confirms the manifest is present
2. `cn doctor` → expect a line `Orchestrators: 1 healthy`
3. After a real wake, `cat state/runtime-contract.json | jq '.body.orchestrators'`
   → expect one entry: `{name: "daily-review", source: "package",
   package: "cnos.core", trigger_kinds: ["command"]}`
4. (Negative path) Manually trigger the daily-review orchestrator
   end-to-end → expect failure at the `llm` step with the
   "not yet implemented" message + a matching trace event in
   `logs/events/`

**Result:** **deferred** until the first sigma hub upgrade after
v3.36.0 publishes the package index back to main. Steps 1–3 are
expected pass; step 4 is expected fail-as-designed (the AC3
deferral). Tracked out-of-band; not blocking this assessment.

### 6. CDD Closeout

| Step | Artifact | Skills loaded | Decision |
|------|----------|---------------|----------|
| 11 Observe | this assessment + PR #179 review thread + CHANGELOG row + GATE | post-release | Cycle coherent; β improved on the dueling-schema fix; γ held with one repeating mechanical failure (rebase artifact); shipped state matches contract minus the documented `llm` deferral |
| 12 Assess | `docs/gamma/cdd/3.36.0/POST-RELEASE-ASSESSMENT.md` (this file) | post-release | Scoring matches CHANGELOG row (C_Σ A · α A · β A · γ A− · L7); §9.1 triggers identified; recurring failure named and patched at the skill level |
| 13 Close | skill patch (`cdd/SKILL.md` §2.6 + `CDD.md` §5.3) + this assessment + next-MCA commitment | post-release | Cycle closed; immediate outputs executed in this commit; deferred outputs committed concretely in §7 |

### 7. Next Move

**Next MCA:** **Orchestrator runtime: `llm` step execution + binding substitution**
**Issue:** to be filed (no number yet — file alongside this assessment merge)
**Owner:** sigma (handoff likely delegated via §2.5a)
**Branch:** pending creation
**First AC:** `llm` step calls into the existing LLM client (`Cn_llm`) with a prompt template + bound `inputs` resolved from the workflow environment, and a happy-path test locks the daily-review end-to-end run (replacing the current X5 "not yet implemented" stub test).
**MCI frozen until shipped?** **Yes.** No new design docs until this gap closes. #175 (CTB → orchestrator IR compiler) depends on the runtime being end-to-end runnable; opening #175 before the `llm` execution lands would design on top of an unfinished surface.
**Rationale:** The orchestrator runtime is shipped but the first deployed orchestrator (`daily-review`) cannot run end-to-end. Closing the gap is the minimum bar for v1 to be honestly complete. F3 from PR #179's review (the dead `inputs` field) and the `llm` deferral are the two halves of the same design problem: how does a bound value from a prior step flow into a later step's args / prompt? The next cycle answers that question concretely with code.

**Immediate fixes (executed in this commit):**

1. **`docs/gamma/cdd/3.36.0/POST-RELEASE-ASSESSMENT.md`** — this file.
2. **Skill patch: pre-PR rebase mechanical gate.** Files modified in this commit:
   - `src/agent/skills/cdd/SKILL.md` §2.6 — new "Pre-review (author-side)" subsection
   - `packages/cnos.core/skills/cdd/SKILL.md` — same edit (mirrored, build-sync per CDD §3.3)
   - `docs/gamma/cdd/CDD.md` §5.3 step table or §5.4 — corresponding row/note (authority-sync per CDD §3.3a)
3. **CHANGELOG TSC row:** unchanged. The release-time row already
   matches this assessment's scoring (C_Σ A · α A · β A · γ A−
   · L7); no revision needed.

**Deferred outputs (committed concretely):**

| # | Output | Trigger / next action |
|---|--------|----------------------|
| 1 | **`llm` step execution + binding substitution** (next MCA above) | File issue at merge time; open branch from current main; first AC drives the test |
| 2 | **`parallel` step kind** | cnos has no async model. Defer until either (a) the runtime gains an async substrate or (b) a real workflow needs concurrent steps. Not blocking. |
| 3 | **#175 CTB → orchestrator IR compiler** | Blocked on next MCA. Resume once `llm` execution lands. |
| 4 | **Frontmatter inline list form** `triggers: [a, b]` | Carried from v3.35.0. File when a real package author requests inline form; no speculative work. |
| 5 | **Pre-existing bare catches in unrelated `src/cmd/` modules** (`cn_maintenance`, `cn_logs`, `cn_indicator`, `cn_trace`, `cn_executor`, `cn_context`) | Carried from v3.35.0. Schedule as a dedicated `#152 v2` audit cycle. Six modules; not in the touch scope of any current MCA. |
| 6 | **Built-in command migration** (`daily` / `weekly` / `save` / `release` → `packages/cnos.core/commands/`) | Carried from v3.34.0. Pick one in a follow-up cycle after `llm` execution lands. The commands content class is shipped; only consumers are missing. |
| 7 | **Modular refactor — direction capture** | The user posted an architectural review (docs describe a more modular system than `src/cmd/` layout suggests). User will write the design doc separately and share next. No CDD cycle opened yet — direction capture lives outside the v3.36.0 post-release. |

**Closure evidence (CDD §10):**

- **Immediate outputs executed:** yes
  - This POST-RELEASE-ASSESSMENT.md (committed in this PR)
  - Skill patch: cdd/SKILL.md §2.6 + canonical-spec sync (committed in this PR)
- **Deferred outputs committed:** yes
  - 7 entries above with scope + trigger condition + ownership note
  - The `llm` execution next-MCA is the only one without an issue
    number yet — to be filed at merge time
