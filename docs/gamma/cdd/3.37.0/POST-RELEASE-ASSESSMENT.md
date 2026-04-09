## Post-Release Assessment — v3.37.0

**Release commit:** `7d14dc2`
**Tag:** `3.37.0`
**Cycle:** #184 — Command pipeline symmetry (Move 1 of #182 core refactor)
**PRs:** #185 (feature) merged at `30fa8de` after 3 review rounds
**Branch (this assessment):** `claude/post-release-3.37.0`
**Skill loaded:** `packages/cnos.core/skills/cdd/post-release/SKILL.md` — re-read in full this session

### 1. Coherence Measurement

- **Baseline:** v3.36.0 — C_Σ A · α A · β A · γ A− · L7
- **This release:** v3.37.0 — C_Σ A− · α A · β A · γ B+ · L6
- **Delta:**
  - **α held A.** The type changes were strict subtraction (`Daily`, `Weekly`, `Save of string option` removed from `Cn_lib.command`; `run_daily`/`run_weekly` deleted; two dead `Cn_hub` bindings cleaned). Every removal had a verified empty call site at commit time. The one addition (`Cn_build.source_decl.commands : string list`) mirrors the existing pattern for `skills` and `orchestrators`. No type ambiguity introduced; `string_of_command` and `parse_command` stayed exhaustive with the catchall `_ -> None`.
  - **β held A.** Single source of truth held end-to-end. The dual-field manifest design (`sources.commands` as a string-id array for `cn build`, top-level `commands` as `{id: {entrypoint, summary}}` for `Cn_command` discovery) follows CORE-REFACTOR.md §2 verbatim and mirrors the `sources.orchestrators` precedent from #174. `Cn_command.parse_package_commands` and `Cn_command.validate` were both updated to read from the top-level field in the same diff — no dueling-schema drift in production code.
  - **γ regressed (A− → B+).** Three review rounds against a target of ≤2. The mechanical ratio was 1/1 = **100%** — over the 20% threshold. Both rounds (R1 and R2) were the same recurring failure class: test fixtures still wrote the legacy nested `sources.commands` shape that this cycle's feature commit had retired in production. R1 fixed `cn_command_test.ml`. R2 found the same pattern in `cn_runtime_contract_test.ml::with_activation_hub`. R3 was clean. The feature itself was correct from PR-open time; the gap was author-side fixture sweeping.
  - **Level dropped L7 → L6.** This is a scope shift, not a regression. v3.36.0 was an L7 boundary move (introducing the orchestrator IR runtime as a new execution surface). v3.37.0 is an L6 cross-surface change (extending the existing build pipeline by one content class + migrating three commands). Move 1 of the #182 refactor is structurally smaller than the orchestrator runtime introduction; the L6 label is honest.
- **Coherence contract closed?** **Yes.** All seven #184 ACs were met as written, no AC deferrals carried into this assessment. The package system no longer has any structural exception for commands — every content class flows through `src/agent/<class>/` → `cn build` → `packages/<name>/<class>/`. The "biggest structural asymmetry" called out in the issue is gone. Move 1 of #182 is shipped; Moves 2+ remain pending.

### 2. Encoding Lag

| Issue | Title | Type | Design | Impl | Lag |
|-------|-------|------|--------|------|-----|
| #184 | Command pipeline symmetry (Move 1 of #182) | feature | CORE-REFACTOR.md §2 + §7 | **shipped** | none |
| #182 | Core refactor — Move 2 (`src/lib/` pure-model gravity) | feature | CORE-REFACTOR.md §7 | not started — **next MCA** | new |
| TBD | Orchestrator runtime: `llm` step execution + binding substitution | feature | needs design (PLAN-174 §Risk + #185 R1 F3 design note) | not started | growing (carried from v3.36.0) |
| #175 | CTB → orchestrator IR compiler | feature | CTB-v4.0.0-VISION.md | not started (depends on `llm` execution) | growing |
| #162 | Modular CLI commands (broader umbrella) | feature | first step shipped via #184 | partial — bootstrap kernel still wider than design target | low |
| #168 | L8 candidate tracking | process | adhoc thread | observation only | low |
| #154 | Thread event model P1 | feature | converged | not started | stale |
| #153 | Thread event model | feature | converged | not started | stale |
| #100 | Memory as first-class faculty | feature | partial | not started | stale |
| #94 | cn cdd: mechanize CDD invariants | feature | partial | not started | stale |

**MCI/MCA balance:** **balanced**, still approaching the freeze
threshold but not at it. Two issues at growing (`llm` execution +
#175, both on the same dependency chain), one new (#182 Move 2 as
the next MCA), one partial (#162), one low (#168), four stale.
The growing-count of two is below the ≥3 freeze trigger. The four
stale items are the long-tail concern but do not by themselves
trigger freeze under the post-release skill's §4 rules.

**Rationale:** #170's pipeline ordering continues to hold. #173
shipped the registries (v3.35.0); #174 shipped the workflow
runtime (v3.36.0); #184 shipped the command pipeline symmetry
(v3.37.0). Move 2 of #182 (`src/lib/` extraction) is the natural
follow-on to Move 1 — same refactor umbrella, same scope discipline
(subtraction over addition; no `src/core/` until evidence demands
it). The `llm` execution gap is also still open and is a legitimate
alternative next-MCA, but Move 2 is sequenced ahead in §7 because
it consolidates the pure-model surface area that the `llm` work
will eventually reach into.

### 3. Process Learning

**What went wrong:**

1. **Three review rounds — over the ≤2 target.** R1 found a stale `sources.commands` test fixture in `cn_command_test.ml` and I fixed it. R2 found the **same** stale shape in `cn_runtime_contract_test.ml::with_activation_hub` and I fixed that. R3 was a clean approval. Both R1 and R2 are the same root cause (test fixtures use legacy nested manifest shape after a production-side schema change), and the R1 fix only touched one of the two affected files because my own self-verification grep was scoped to the file the reviewer had named — not to *all* test files that construct manifests.
2. **The §2.5b mechanical gate (committed in v3.36.0 PR #183) caught the rebase-artifact failure class but did NOT catch this fixture-drift class.** The five existing checks are: rebase, self-coherence present, CDD Trace in PR body, tests reference ACs, known debt explicit. None of them say "if you changed a manifest schema, audit every test fixture that constructs one." The gap is real and recurring — it landed twice in two consecutive review rounds of the same PR.
3. **§2.2.1b sibling-audit currently scopes to production modules only.** When I touched `cn_build.ml`, the sibling sweep correctly caught five pre-existing bare catches in adjacent production code. But the sibling sweep doesn't extend to test fixtures, so the fact that two test files constructed the same manifest shape was invisible to my self-audit.
4. **Tooling gap (no local OCaml) for the fifth cycle in a row.** Same environment constraint as v3.34.0 / v3.35.0 / v3.36.0 / v3.37.0 author-time. CI is the only true compilation oracle on this branch family. The §2.5b mechanical gate is doing some of the work that local `dune runtest` would otherwise do, but it cannot substitute for actually running the tests. R1 and R2 both fired *only* on CI red, not on local pre-push.

**What went right:**

1. **§2.5b dogfood held its existing five checks.** Both at PR-open time and on each fix-push, the checklist ran cleanly: rebase onto current main, self-coherence present, CDD Trace in body, tests tagged with ACs, known debt named. The mechanical discipline is now routine — one cycle in, the gate is being consulted, not skipped.
2. **R1 → R2 → R3 fix-loop economics were tight.** Each fix commit was one file, one targeted change. R2 was driven by the same root-cause analysis as R1 (grep for the legacy shape across the broader test surface). R3 was a clean approval with no new findings. Three rounds is over target by one, but the loop velocity was good — not "review found a structural problem we have to redesign," more "review found two instances of the same plumbing miss."
3. **Sibling audit on production modules continued to hold.** Touching `cn_gtd.ml` to delete `run_daily`/`run_weekly` triggered the sweep that caught two dead bindings in `cn_hub.ml` (`threads_reflections_daily`, `threads_reflections_weekly`). Both cleaned in the same commit. The §2.2.1b discipline works for production code; what's missing is the test-fixture extension.
4. **Manifest schema reconciliation was clean.** The dual-field shape (`sources.commands` as a string-id array for `cn build` + top-level `commands` as `{id: {entrypoint, summary}}` for `Cn_command`) follows CORE-REFACTOR.md §2 verbatim and mirrors the v3.36.0 orchestrators precedent. Both production readers (`parse_package_commands` and `validate`) were updated in the same diff — no production-side dueling-schema drift, only the test-side fallout.
5. **#182 Move 1 actually shipped.** The refactor umbrella moved from "design committed, no implementation" to "Move 1 done, four ACs landed cleanly." The package system no longer has any structural exception for commands. The biggest single asymmetry the design called out is gone.

**Skill patches (immediate output, mandatory per skill §3):**

The fixture-drift failure mode — *"R1 fix only touched one of the two affected test files"* — is **recurring**. v3.35.0 had F5 (`list_skill_overrides` reviewer-noted as having a bare catch that R1's fix didn't sweep adjacent for); v3.37.0 has the same shape applied to test fixtures. Per the post-release skill's §3 rule (*"If a repeatable failure mode is identified, patch the skill NOW — not next session"*), this assessment commit also lands a skill patch.

**Patch:** `src/agent/skills/cdd/SKILL.md` §2.5b gains a **sixth** mechanical check, mirrored to `packages/cnos.core/skills/cdd/SKILL.md` (build-sync per CDD §3.3) and noted in `docs/gamma/cdd/CDD.md` §5.3 step row 7a (authority-sync per CDD §3.3a):

> **6. Schema/shape audit across test fixtures.** If this PR changes a JSON schema, manifest shape, or any string-literal contract that test fixtures construct, grep `test/` for the old shape (`grep -rn '<old-shape-substring>' test/`) and audit every match. Update each fixture in the same commit. The sibling-audit discipline (§2.2.1b) is hereby extended from production-module scope to *also* cover test fixtures when a contract changes.

**Why a skill patch and not just a noted commitment:** the same root cause (single-file fix on a multi-file gap) has now landed in two consecutive cycles' review rounds (v3.35.0 F5, v3.37.0 R1→R2). A noted commitment is insufficient when the failure mode is recurring — the fix must be at the skill specification level.

**What this does NOT patch:** the tooling gap (no local OCaml) is still an environment constraint, not a skill specification gap. The §9.1 soft trigger keeps firing for the fifth cycle. No skill-level mitigation is available beyond the existing post-release acknowledgement; the real fix is OCaml in the authoring sandbox or a preflight test runner that the agent can invoke.

**Active skill re-evaluation:**

| Finding | Loaded skill | Would skill have prevented it? | Disposition |
|---------|-------------|-------------------------------|-------------|
| F1 R1 (`cn_command_test.ml` fixture stale) | cdd, eng/ocaml, eng/testing | Partially — eng/testing covers "test fixtures track production schema" in spirit, but no specific check for "audit test fixtures when schema changes" | **Skill patched this commit** (new §2.5b check 6) |
| F1 R2 (`cn_runtime_contract_test.ml::with_activation_hub` carries the same drift) | cdd | Same as R1 — the *first-fix scoped too narrow* sub-pattern is the new specific check | Same patch covers it |

One skill gap (recurring fixture drift across PRs → patched this commit). Zero application gaps for which the skill text was already adequate. The minus is on the tooling side, not the skill side.

### 4. Review Quality

**PRs this cycle:** 1 (#185)
**Review rounds:** **3** (R1 request changes → R2 request changes → R3 approved) — over the ≤2 target for code PRs by one
**Superseded PRs:** 0 — within the 0 target
**Finding breakdown:**

| # | Finding | Round | Severity | Type |
|---|---------|-------|----------|------|
| F1 R1 | `cn_command_test.ml` test fixture used legacy `sources.commands` nested object shape | 1 | D | mechanical |
| F1 R2 | `cn_runtime_contract_test.ml::with_activation_hub` carries the same drift (first-fix scope was too narrow) | 2 | D | mechanical |

**Mechanical ratio:** 2 / 2 = **100%** — over the 20% threshold, by a wide margin.

**Action (per skill §4 rule "filed and referenced, not just noted"):** the corrective is **executed immediately in this commit** as the skill patch (§2.5b check 6 + canonical-spec sync). This is the §3 / §4 / §12a rule in action: a recurring mechanical failure mode triggers an immediate skill-level fix. The patch is co-committed with this assessment, not deferred.

### 4a. CDD Self-Coherence

- **CDD α (artifact integrity): 4/4.** All required cycle artifacts present in `docs/gamma/cdd/3.37.0/`: README, SELF-COHERENCE, GATE, and POST-RELEASE-ASSESSMENT (this file). PLAN lives inline in README §Plan because the cycle was small enough to not warrant a separate `PLAN-184-…md`. CDD Trace tables in both the README and PR #185 body, populated through step 9.
- **CDD β (surface agreement): 4/4.** End-to-end agreement between: ORCHESTRATORS.md / CORE-REFACTOR.md design, manifest schema (`sources.commands` + top-level `commands`), `cn_build.ml` parser, `cn_command.ml` reader, `cn_command.ml` validator, runtime command-registry projection, `PACKAGE-SYSTEM.md` §1.1 doc, the shipped `cnos.core` manifest. The dueling-schema problem from #173 (orchestrators inline vs id-array) was avoided in advance by following the orchestrators precedent verbatim — no β drift created.
- **CDD γ (cycle economics): 2/4.** Three review rounds (over the ≤2 target by one). 100% mechanical ratio (over the 20% threshold). Tooling gap soft-fired for the fifth cycle in a row. Immediate outputs (this assessment + skill patch) executed in this commit; deferred outputs committed concretely in §7.
- **Weakest axis:** γ.
- **Action:** **patched this commit** — `cdd/SKILL.md` §2.5b gains a sixth check covering schema/shape fixture audit across `test/`, plus mirror to `cnos.core` package + canonical spec note. The patch is the recurring-failure corrective; the tooling gap is environmental and remains.

### 4b. §9.1 Cycle Iteration

**Triggers fired:**

| Trigger | Fired | Evidence |
|---------|-------|----------|
| Review rounds > 2 | **Yes** (3) | R1 + R2 + R3 |
| Mechanical ratio > 20% | **Yes** (100%) | F1 R1 + F1 R2, both mechanical |
| Avoidable tooling failure | **Yes (soft)** | No OCaml in the authoring sandbox; fifth cycle in a row |
| Loaded skill failed to prevent a finding | **Yes** | §2.5b mechanical gate is correct as far as it goes but does not yet have the manifest-fixture audit check; §2.2.1b sibling audit applies to production modules only, not test fixtures. The skill-coverage gap is real, named, and patched in this commit. |

**Cycle level (L5 / L6 / L7):** **L6**. The architectural scope is L6 (cross-surface change to build pipeline + manifest schema + CLI dispatch + docs, no new boundary). Execution quality matches scope — the recurring failure was author-side fixture sweeping, the fix loop was tight per round, and the recoveries were all clean. No downgrade to L5 because the structural change is real (the package system gains its 7th and final symmetric content class) and the final merged state is coherent. No upgrade to L7 because there is no new primitive — Move 1 is, by design, structurally smaller than #174 was.

### 5. Production Verification

**Scenario:** A consumer hub upgraded to cnos.core 3.37.0 can run the migrated `daily`, `weekly`, and `save` commands as **package commands** (not built-ins), with file layout and behavior identical to the pre-migration built-in implementations.

**Before this release:**
- `cn daily` and `cn weekly` were OCaml functions in `cn_gtd.ml`, dispatched directly from `cn.ml`'s built-in match arm. Adding a new operator-facing command meant editing core OCaml code.
- `cn save` was a built-in compound that called `Cn_commands.run_commit` then `Cn_commands.run_push` inline in the dispatch arm.
- The package-system content-class table had a "(commands are the exception)" footnote — the only one of seven classes that bypassed `cn build`.
- `Cn_command.parse_package_commands` read `sources.commands` as an inline object map, but no first-party package used it (no command had ever flowed through the discovery path in production).

**After this release:**
- `cn daily` runs `src/agent/commands/daily/cn-daily` (POSIX shell script), copied by `cn build` to `packages/cnos.core/commands/daily/cn-daily` and installed to `.cn/vendor/packages/cnos.core@3.37.0/commands/daily/cn-daily` with the executable bit preserved.
- Same shape for `weekly` and `save`. `cn save "msg"` chains `cn commit "msg"` + `cn push` from inside the shell script (commit + push remain built-in per the issue's explicit non-goal).
- `Cn_lib.command` no longer has `Daily`, `Weekly`, `Save` constructors; `parse_command` returns `None` for those tokens; `cn.ml`'s `None` branch hands off to `Cn_command.find` → `dispatch`, which now finds the package command via the top-level `commands` field in cnos.core's manifest.
- The package-system content-class table has the "exception" paragraph removed: all seven classes use the same `src/agent/<class>/` → `cn build` → `packages/<name>/<class>/` → `cn deps restore` → vendor pipeline.

**How to verify:**
1. On a hub with cnos.core 3.37.0 installed:
   ```
   cn doctor
   ```
   Expect: `Commands: 3 healthy` (or whatever count of discovered package commands the hub has installed) without any "missing entrypoint" or "not executable" complaints for daily/weekly/save.
2. Touch a fresh date and confirm `cn daily` creates the day's reflection file:
   ```
   cn daily
   ls threads/reflections/daily/
   ```
   Expect: a file named `YYYYMMDD.md` (today's date) with the same template structure as the pre-migration built-in (date frontmatter + Done / In Progress / Blocked / α / β / γ headings).
3. Same for `cn weekly`:
   ```
   cn weekly
   ls threads/reflections/weekly/
   ```
   Expect: a file named `YYYY-WNN.md` with the weekly template (Summary / Key Accomplishments / Challenges / Next Week Focus).
4. With staged changes in the hub repo:
   ```
   cn save "test save command"
   ```
   Expect: `cn commit` runs and reports its commit hash, then `cn push` runs and pushes to origin. Behavior identical to the pre-migration `Save` dispatch arm.
5. Negative path — confirm there is no built-in fallback:
   ```
   grep -n 'Daily\|Weekly\|Save of' $(which cn) || true
   ```
   Expect: nothing referencing them as `Cn_lib.command` constructors.

**Result:** **deferred** until the first sigma hub upgrade after v3.37.0. The post-merge CI run is the only end-to-end verification that has executed so far (CI's `dune runtest` covers the unit-level shape but does not run the actual shell scripts against a real hub). Tracked out-of-band; not blocking this assessment.

### 6. CDD Closeout

| Step | Artifact | Skills loaded | Decision |
|------|----------|---------------|----------|
| 11 Observe | this assessment + PR #185 review thread (R1+R2+R3) + CHANGELOG row + GATE.md + the v3.37.0 release artifacts (binaries × 4 targets, packages × 2, RELEASE.md) | post-release | Cycle coherent. β held A on the dueling-schema avoidance; γ regressed to B+ on the recurring fixture-drift failure mode that landed across two review rounds of the same PR. Shipped state matches contract (all 7 ACs met as written, zero AC deferrals carried). The package system no longer has a structural exception for commands. |
| 12 Assess | `docs/gamma/cdd/3.37.0/POST-RELEASE-ASSESSMENT.md` (this file) | post-release | Scoring matches CHANGELOG row (C_Σ A− · α A · β A · γ B+ · L6); §9.1 triggers identified (3 firm + 1 soft); recurring failure mode named explicitly and patched at the skill level in this same commit. |
| 12a Skill patch | `src/agent/skills/cdd/SKILL.md` §2.5b check 6 + `packages/cnos.core/skills/cdd/SKILL.md` (build-sync) + `docs/gamma/cdd/CDD.md` §5.3 step row 7a note (authority-sync per CDD §3.3a) | post-release, cdd | Patch closes the recurring fixture-drift failure class at the skill specification level by extending §2.5b's mechanical pre-review checklist with a sixth check covering schema/shape audit across `test/`. Justified in §3 above. Mirror + canonical-spec sync done in the same commit per CDD §3.3 + §3.3a. |
| 13 Close | this assessment + skill patch + next-MCA commitment | post-release | Cycle closed; immediate outputs executed in this commit; deferred outputs committed concretely in §7. |

### 7. Next Move

**Next MCA:** **Move 2 of #182 — Pure-model gravity into `src/lib/`**
**Issue:** #182 (umbrella; Move 2 sub-task to be filed at merge time of this assessment, paralleling how #184 was filed for Move 1)
**Owner:** sigma (handoff likely delegated via CDD §2.5a)
**Branch:** pending creation (e.g. `claude/182-move2-src-lib-gravity`)
**First AC:** Extract one canonical pure-type module (suggested: package manifest types from `cn_deps.ml`) into `src/lib/`. The extracted module is the system's authority for that type; `src/cmd/cn_deps.ml` re-exports or imports it. No filesystem / git / process / HTTP / LLM code may move into `src/lib/`.
**MCI frozen until shipped?** **Yes.** No new design docs until Move 2 ships. The `llm` execution gap (carried from v3.36.0) and #175 (CTB compiler, blocked on `llm`) both wait — `llm` work would benefit from the cleaner pure-model surface area Move 2 produces.
**Rationale:** Move 1 (#184) shipped the structural symmetry the package system needed; Move 2 is the natural follow-on per CORE-REFACTOR.md §7. Extracting pure types into `src/lib/` consolidates the model surface so the next round of work (whatever it is) operates against a cleaner base. Discipline: subtraction over addition; widen `src/lib/` rather than create `src/core/` until evidence of crowding demands it.

**Immediate fixes (executed in this commit):**

1. **`docs/gamma/cdd/3.37.0/POST-RELEASE-ASSESSMENT.md`** — this file.
2. **Skill patch: §2.5b check 6 (schema/shape fixture audit).** Files modified in this commit:
   - `src/agent/skills/cdd/SKILL.md` §2.5b — append a sixth mechanical check covering schema/shape audit across `test/` when a PR changes a manifest or string-literal contract that test fixtures construct
   - `packages/cnos.core/skills/cdd/SKILL.md` — same edit, mirrored (build-sync per CDD §3.3)
   - `docs/gamma/cdd/CDD.md` §5.3 step table row `7a Pre-review` — note that the pre-review checklist now has six items (authority-sync per CDD §3.3a)
3. **CHANGELOG TSC row:** unchanged. The release-time row for v3.37.0 already matches this assessment's scoring (C_Σ A− · α A · β A · γ B+ · L6) and explicitly records "3 review rounds (over ≤2 target ... fix only caught one in R1), 1 finding (100% mechanical)". No revision needed.

**Deferred outputs (committed concretely):**

| # | Output | Trigger / next action |
|---|--------|----------------------|
| 1 | **Move 2 of #182** (`src/lib/` pure-model gravity) — next MCA above | File sub-issue under the #182 umbrella at merge time of this assessment; first AC extracts one pure-type module |
| 2 | **`llm` step execution + binding substitution** | Carried from v3.36.0. Closes the #174 deferral so `daily-review` becomes end-to-end runnable. Sequenced after Move 2 in the recommended pipeline; alternative ordering is acceptable if a real demand for `llm` execution surfaces. |
| 3 | **#175 CTB → orchestrator IR compiler** | Carried from v3.36.0. Blocked on item 2. |
| 4 | **`parallel` step kind** | Carried from v3.36.0. Needs an async substrate cnos does not yet have. Defer until either (a) the runtime gains async or (b) a real workflow needs concurrent steps. |
| 5 | **Frontmatter inline list form** `triggers: [a, b]` | Carried from v3.35.0. File on demand from a package author; no speculative work. |
| 6 | **Pre-existing bare catches in 6 unrelated `src/cmd/` modules** (`cn_maintenance`, `cn_logs`, `cn_indicator`, `cn_trace`, `cn_executor`, `cn_context`) | Carried from v3.35.0 / v3.36.0. Schedule as a dedicated `#152 v2` audit cycle. |
| 7 | **Built-in command migration follow-on** (`commit` / `push` / `peer` / `send` / `reply` → package commands) | The next "shrink the bootstrap kernel" pass after #184 proves clean. v3.37.0 migrated daily/weekly/save and the path is now exercised; the harder cases (commit/push touch git transport, peer/send/reply touch the inbox protocol) need separate design before migration. |
| 8 | **`cn help` dynamic command listing** | The current help text has a placeholder note pointing at the external command listing rather than dynamically merging the built-in + discovered set into one rendered table. Cosmetic; carried as a known limitation. |

**Closure evidence (CDD §10):**

- **Immediate outputs executed:** yes
  - This `POST-RELEASE-ASSESSMENT.md` (committed in the same diff as the skill patch)
  - Skill patch: `cdd/SKILL.md` §2.5b check 6 + cnos.core mirror + CDD.md canonical-spec note (committed in the same diff)
- **Deferred outputs committed:** yes
  - 8 entries above with scope + trigger condition + ownership note
  - Item 1 (Move 2 next MCA) is the only one without an issue number yet — to be filed under the #182 umbrella at merge time of this assessment
