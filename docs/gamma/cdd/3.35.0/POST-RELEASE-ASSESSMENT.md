## Post-Release Assessment — v3.35.0

**Scope:** Runtime contract activation index + command/orchestrator registries (#173), plus retro-review + review fixes from PR #176 and PR #177.

### 1. Coherence Measurement

- **Baseline:** v3.34.0 — C_Σ A− · α A− · β A− · γ B+ · L7
- **This release:** v3.35.0 — C_Σ A− · α A · β A− · γ B+ · L6
- **Delta:**
  - α improved (A− → A). The `frontmatter`, `activation_entry`, `command_entry`, `orchestrator_entry`, and `issue` records compose without overlapping field names (eng/ocaml §2.1). The parser is a pure function with bounded output; exceptions do not escape. `Cn_command.discover` was reused verbatim instead of duplicated — a #167 precedent that held here.
  - β held (A−). Started strong (every surface touched had one authority; JSON schema tag unchanged; markdown renders only non-empty sections for cache safety), then took one notch back on the R1 markdown/JSON shape divergence (F3 — "Skills:" header vs `activation_index.skills` in JSON). Fixed in the retro PR; markdown now mirrors the JSON nesting byte-for-byte. Net A−.
  - γ held (B+). Same triggers as last cycle (tooling gap — no local OCaml toolchain), plus the process violation of merging PR #176 without a formal review, plus the F1/F2/F4 findings that §2.2 sibling audit would have caught at authoring time. Review rounds were 3 effective (0 on #176 before merge → retro-review after → R1 on #177 → R2 on #177), over the L6 target of ≤2.
- **Coherence contract closed?** Yes. All 6 ACs met:
  - AC1 `cognition.activation_index` from exposed skills — `Cn_activation.build_index`
  - AC2 triggers from SKILL.md frontmatter — `Cn_activation.parse_frontmatter` (line-based YAML subset, no library)
  - AC3 `body.commands` registry reusing `Cn_command.discover` (#167)
  - AC4 `body.orchestrators` registry from `sources.orchestrators`
  - AC5 `cn doctor` validates activation (missing / empty triggers / conflicting triggers, conflict is fail-stop)
  - AC6 15 new tests + runtime contract tests updated

### 2. Encoding Lag

| Issue | Title | Type | Design | Impl | Lag |
|-------|-------|------|--------|------|-----|
| #173 | Runtime contract: activation index + registries | feature | ORCHESTRATORS.md §4 | **shipped** | **none** |
| #170 | Orchestrator + command provider model | design | shipped | partial (registry shipped; execution via #174) | low |
| #172 | ORCHESTRATORS.md CTB/effect-plan doc fix | doc | shipped | shipped | none |
| #174 | Orchestrator IR runtime | feature | ORCHESTRATORS.md §7–8 | not started (next MCA) | growing |
| #175 | CTB → orchestrator IR compiler | feature | CTB-v4.0.0-VISION.md | not started (depends #174) | growing |
| #162 | Modular CLI commands | feature | converged | not started | growing |
| #168 | L8 candidate tracking | process | adhoc thread | observation only | low |
| #154 | Thread event model P1 | feature | converged | not started | stale |
| #153 | Thread event model | feature | converged | not started | stale |
| #100 | Memory as first-class faculty | feature | partial | not started | stale |
| #94 | cn cdd: mechanize CDD invariants | feature | partial | not started | stale |

**MCI/MCA balance:** balanced, approaching freeze. Three issues at
growing (#174, #175, #162), four stale. #174 is the committed next
MCA; #175 depends on #174; the growing count reflects planned
sequencing rather than neglect.

**Rationale:** #170's decomposition established a clear pipeline:
#173 ships the registries (this release), #174 is the orchestrator
runtime, #175 compiles CTB to that runtime. No new design work until
#174 ships.

Two known-debt items surfaced during this cycle but are not yet
filed as issues — they are recorded as deferred outputs in §7 rather
than encoding-lag rows:

1. Frontmatter inline list form `triggers: [a, b]` — v1 parser
   accepts block lists only. File when a package author requests it.
2. Pre-existing bare `with _ ->` catches in six unrelated `src/cmd/`
   modules — a v3.32.0 audit gap, not a #173 regression. Schedule
   as a dedicated audit cycle (`#152 v2`).

### 3. Process Learning

**What went wrong:**

1. **PR #176 merged without CDD review.** The review skill was not loaded. A spot-check (bare catches, test count, CI green) was performed instead of the protocol: AC coverage table, doc check, CDD artifact check, sibling audit, evidence-traced findings. This is a §2.6 violation. Corrected by the retro-review protocol — retro-review posted on the merged PR, findings tracked, fix PR #177 opened.

2. **R1 review on #177 was lazy.** The reviewer pattern-matched "looks right" and stamped the PR without performing §2.2 sibling audit. The R2 review caught the leaf-value silent coercions (`| _ -> None` / `| _ -> []` on already-validated trigger_kinds entries) that R1 should have found. The reviewer acknowledged this in the R2 comment: "First pass was lazy — I read the diff, pattern-matched on 'looks right,' and stamped it. The §2.2 sibling audit is where reviews earn their keep."

3. **§2.2 sibling audit miss at author time.** When the initial #173 PR logged manifest parse errors in `build_orchestrator_registry`, the same pattern in `manifest_skill_ids` was not updated. The retro and R2 rounds eventually caught it, but the author should have done the sibling sweep. This is the same pattern the v3.34.0 post-release called out for #167 ("active skills named in PLAN but not loaded before writing").

**What went right:**

1. **Tests-first discipline held.** 11 `cn_activation_test` + 4 initial `cn_runtime_contract_test` additions + later test additions — all authored before or alongside the corresponding production code. This is the explicit corrective from the v3.34.0 post-release. It held.

2. **Active skills loaded and read before writing.** Eng/ocaml and eng/testing were read in this session, not just named in the PLAN. Zero bare `with _ ->` in any of the touched modules from the first commit onward — the v3.34.0 corrective held.

3. **Retro-review pattern worked.** A post-merge review surface exists (the PR comment) and produced a clean findings list that a follow-up PR (#177) could address. The merged change was not locked in amber.

4. **R2 fix round was thorough.** When R2 surfaced the leaf-value finding, the §2.2 sibling audit was done properly: fixed `build_orchestrator_registry`, then fixed the matching pattern in `manifest_skill_ids`, then added explanatory comments on the two intentional fall-throughs so the next audit doesn't re-flag them.

**Skill patches (immediate output):** none. Both process failures
(merge-without-review, lazy-review-R1, author-side sibling-audit-miss)
are application gaps, not skill content gaps. The review skill already
mandates §2.2 sibling audit. The CDD §2.6 review protocol is already
explicit. The corrective action is at execution time.

**Active skill re-evaluation:**

| Finding | Active skill | Would skill have prevented it? | Assessment |
|---------|-------------|-------------------------------|------------|
| Merge without review | cdd, cdd/review | Yes — §2.6 explicitly requires review | **Execution gap.** Skill not loaded before merge. Same shape as v3.34.0 #167 F1 (skill not loaded before writing). |
| F1/F2 silent parse error + missing-name skip | eng/ocaml | Yes — §2.6.2 "log + fallback" rule | **Audit gap at author time.** Skill was loaded; sibling sweep was not performed. |
| F3 markdown/JSON shape divergence | eng/ocaml + cdd/review | Partly — β "surface agreement" check applies | **Application gap.** α and β were scored A− / A at gate time; the β check missed the markdown/JSON divergence. |
| F4 orchestrator path untested | eng/testing | Yes — every new pure function should have at least one dedicated test | **Author-side oversight.** The happy-path was asserted via count=1 only. |
| F5 (stale) — no actual code change | — | n/a | First-round reviewer misread. |
| R2 leaf-value coercions | eng/ocaml §2.6.2 | Yes | **Author-side + reviewer-side miss.** Author didn't sweep; R1 reviewer didn't audit. R2 caught it. |

### 4. Review Quality

**PRs this cycle:** 2 (PR #176 for #173 implementation, PR #177 for retro findings)
**Review rounds:** 3 effective (0 on #176 pre-merge → retro post-merge → R1 on #177 → R2 on #177) — target ≤2 — **exceeded**
**Superseded PRs:** 0 — target 0 — **passed**

**Finding breakdown:**

| # | PR | Finding | Type |
|---|----|---------|------|
| F1 | #176 retro | `build_orchestrator_registry` silent parse skip | judgment (C) |
| F2 | #176 retro | Orchestrator entry missing-name silent skip | judgment (B) |
| F3 | #176 retro | Markdown/JSON activation_index shape divergence | judgment (B) |
| F4 | #176 retro | No dedicated test for `build_orchestrator_registry` | mechanical (C) |
| F5 | #176 retro | (stale) `list_skill_overrides` bare catch | mechanical (B) — not reproducible |
| R2 | #177 R2 | `trigger_kinds` leaf-value silent coercions | judgment (B) |

**Mechanical ratio:** 1 / 6 = **17%** (F4 is the only clean mechanical; F5 is stale and doesn't count against authoring). Under the 20% threshold.

**Action:** None. The ratio is fine; the problem is the **review round count**, not the finding mix. Three effective rounds on an L6 change is one above budget, driven by the process violation (merge without review) rather than by genuine finding density. The corrective is the process fix noted in §3 above: always load the review skill before stamping a PR.

### 4a. CDD Self-Coherence

The bootstrap artifacts for the #173 cycle — `README.md`, `PLAN-runtime-activation.md`, `SELF-COHERENCE.md`, `GATE.md` under `docs/gamma/cdd/3.35.0/`, plus the RUNTIME-CONTRACT-v2.md §4 schema update — were authored on the `claude/173-runtime-contract-activation` branch (merged into v3.35.0 via PR #176) **and are off-branch relative to this PR** (this PR is `claude/post-release-3.35.0`, a docs-only follow-up adding the post-release assessment). Rows below reference the merged state of main, not this PR's diff.

- **CDD α:** 4/4 — all required artifacts present on main for v3.35.0: README + PLAN + SELF-COHERENCE + GATE under `docs/gamma/cdd/3.35.0/`, plus RUNTIME-CONTRACT-v2.md §4 schema update. CDD Trace rendered in both README and PR #176 body. Scored against the released state, not against this PR's diff.
- **CDD β:** 3/4 — one β miss: the R1 `Skills:` markdown header diverged from the JSON `activation_index.skills` nesting. Both surfaces described the same data but used different labels. Fixed in F3.
- **CDD γ:** 2/4 — the process violation (merge without review) is the γ hit. Without the retro-review pattern, the cycle would have closed with no review surface at all. Retro worked, but that's recovery, not clean execution.
- **Weakest axis:** γ.
- **Action:** no skill patch. The corrective is "load the review skill before merging, same as the v3.34.0 corrective about loading skills before writing." Record the pattern in this assessment for the next cycle's bootstrap to pick up as a pre-merge gate. Workspace-level mitigation (`WORKFLOW_AUTO.md`) was already created alongside the superseded assessment.

### 4b. §9.1 Cycle Iteration

**Triggers fired:**

| Trigger | Fired | Evidence |
|---------|-------|----------|
| Review rounds > 2 | **Yes** (3 effective) | #176 merge-without-review → retro → R1 → R2 |
| Mechanical ratio > 20% | No (17%) | F4 is the only mechanical finding |
| Avoidable tooling failure | **Yes (soft)** | No OCaml toolchain in the authoring sandbox — same as v3.34.0 |
| Loaded skill failed to prevent a finding | **Yes** | eng/ocaml § 2.6.2 covers F1/F2/R2; cdd/review covers the whole merge-without-review |

**Cycle level (L5 / L6 / L7):** **L6**. The architectural scope is L6 (cross-surface change to runtime contract + doctor, no new boundary). Execution quality matches scope — the process violations were recovered via retro-review, the β miss was recovered via F3 fix, the sibling-audit miss was recovered in R2. No downgrade to L5 because the recoveries were clean and the final merged state is coherent. No upgrade to L7 because the scope genuinely is L6 — this is an additive runtime contract extension, not a boundary move.

### 5. Production Verification

**Scenario:** An agent wakes in a hub with `cnos.core` installed. Its packed context should show explicit activation metadata for exposed skills, explicit command registry, and explicit orchestrator registry (currently empty).

**Before this release:** cognition contained `installed_packages` and `active_overrides` only. Body contained `capabilities` and `peers` only. The agent had no declarative surface for skill activation or operator-facing commands — it reasoned from hidden prompt conventions.

**After this release:** `state/runtime-contract.json` on a wake contains:
- `cognition.activation_index.skills[]` — one entry per exposed skill with a SKILL.md `triggers:` frontmatter
- `body.commands[]` — union of repo-local `.cn/commands/cn-*` and package-declared commands
- `body.orchestrators[]` — entries from any package's `sources.orchestrators` (currently empty across all installed packages, as expected)

**How to verify:**
1. On a hub with cnos.core 3.35.0 installed, trigger a wake
2. `cat state/runtime-contract.json | jq '.cognition.activation_index'` → non-empty if any exposed skill carries a `triggers:` frontmatter
3. `cat state/runtime-contract.json | jq '.body.commands'` → matches `cn help`'s external command list
4. `cn doctor` on a hub with deliberately conflicting triggers → fails with `Trigger_conflict` and exit 1

**Result:** **deferred** until the first agent wake on an upgraded hub. Not blocking this assessment.

### 6. CDD Closeout

| Step | Artifact | Skills loaded | Decision |
|------|----------|---------------|----------|
| 11 Observe | this assessment + PR review threads + CHANGELOG row | post-release | Cycle coherent; process violations recovered via retro; β and γ both one notch below α |
| 12 Assess | `POST-RELEASE-ASSESSMENT.md` (this file) | post-release | Scoring matches CHANGELOG row; §9.1 triggers named; corrective recorded |
| 13 Close | immediate fixes below + deferred outputs named | post-release | Cycle closed |

### 7. Next Move

**Next MCA:** #174 — Orchestrator IR runtime
**Owner:** sigma (handoff delegated to Claude Code via §2.5a)
**Branch:** `claude/174-orchestrator-runtime` (to be created from main)
**First AC:** AC2 — `cn.orchestrator.v1` JSON schema defined and validated by the runtime
**MCI frozen until shipped?** Yes — no new design docs until #174 ships. #175 waits on #174.
**Rationale:** The activation + registry surface (#173) is the prerequisite. Orchestrator runtime is the next concrete capability on the #170 pipeline. Design already exists in ORCHESTRATORS.md §7–8; implementation is the gap. PLAN-174-orchestrator-runtime.md committed at 29eeb29 defines the three stages (content class, execution engine, shipped daily-review orchestrator) and the active-skills list.

**Immediate fixes (executed in this session):**
- This POST-RELEASE-ASSESSMENT.md.
- No CHANGELOG TSC row revision — existing scores (A− · A · A− · B+ · L6) are correct per this assessment.

**Deferred outputs (committed concretely):**
1. **Frontmatter inline list form** `triggers: [a, b]`. The line-based YAML subset parser accepts only block lists. File as a new issue when a package author requests it; trigger = real demand, not speculative. No number assigned yet.
2. **Pre-existing bare catches in six unrelated `src/cmd/` modules** (`cn_maintenance`, `cn_logs`, `cn_indicator`, `cn_trace`, `cn_executor`, `cn_context`). A v3.32.0 #152 audit gap, not a #173 regression. Schedule as a dedicated `#152 v2` audit cycle. No issue number yet.
3. **Built-in command migration** (`daily` / `weekly` / `save` / `release` → `packages/cnos.core/commands/`). Commands content class is shipped (v3.34.0) but no built-in has been migrated. Still deferred from v3.34.0. Pick one in a follow-up cycle after #174 ships.
4. **"Load review skill before merging" process gate.** Record in the next cycle's bootstrap template: before clicking merge on any substantial PR, the cdd/review skill must have been loaded and the §6 output format produced. Not a skill patch — a CDD bootstrap template change. Tracked as a §9.1 corrective in this assessment; no separate issue filed. Workspace-level mitigation already in place via `WORKFLOW_AUTO.md` per the superseded committed assessment.

**Closure evidence (CDD §10):**
- Immediate outputs executed: yes (this commit)
- Deferred outputs committed: yes (four entries above with scope + trigger + owner note)

---

## Supersedes

An earlier assessment was committed at `docs/gamma/cdd/post-release/3.35.0.md` (commit `d2a3e2e`) using the `post-release/<version>.md` path convention. This file at `docs/gamma/cdd/3.35.0/POST-RELEASE-ASSESSMENT.md` follows the per-version directory convention already established by 3.19.0 / 3.28.0, so that old file is removed in the same commit as this one is corrected. The review on PR #178 (round 1) explicitly offered this resolution path. The technical scoring and next-MCA selection in this assessment match the superseded file; earlier drafts of this file carried fabricated issue numbers and a wrong next-MCA (review F1 + F2), which are corrected here.
