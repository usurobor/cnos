## Post-Release Assessment — v3.41.0

**Release commit:** `b3b2e95`
**Tag:** `3.41.0`
**Cycle:** #201 / PR #202 — Move 2 slice 4 (final): activation frontmatter parser into `src/lib/cn_frontmatter`
**Branch (this assessment):** `claude/post-release-3.41.0`
**Skill loaded:** `src/agent/skills/cdd/post-release/SKILL.md`
**Assessor role:** Reviewer (Sigma) — default releaser per CDD §1.4

### 1. Coherence Measurement

- **Baseline:** v3.40.0 — C_Σ A · α A · β A · γ A · L6
- **This release:** v3.41.0 — C_Σ A · α A · β A+ · γ A · L7
- **Delta:**
  - **α held A.** 12 pure surface items extracted byte-for-byte from `cn_activation.ml` into `cn_frontmatter.ml`. Type-equality re-export pattern applied for the fourth time. 3 type re-exports + 9 delegating let-bindings. 21 ppx_expect tests. The pattern is now rote — no design novelty, pure execution.
  - **β improved (A → A+).** Move 2 is complete. `src/lib/` holds 5 pure modules covering every pure type and parser in the codebase. `src/cmd/` holds only IO functions. The boundary is structural (dune library cannot import IO modules), not conventional. This is the first time `src/lib/` ↔ `src/cmd/` separation is mechanically enforced across the full model layer. Additionally: CDD §1.4 Roles formalized with explicit role ownership per step, Role column in §5.3 lifecycle table, reviewer-default-releaser principle, and small-change exception. The TypeScript skill adds a second engineering language skill alongside the Go skill. Authority surfaces are more aligned than any prior release.
  - **γ held A.** 1 review round, zero findings — the first Move 2 cycle with none. §2.5b checks 7 (library-name uniqueness) and 8 (CI-green-before-review) both validated: the mechanical failure classes from slices 2+3 did not recur. Check 8 was formal for the first time and the author achieved first-push-green with zero draft iterations. 0 superseded PRs. The CDD role model reaching its final form in the same cycle demonstrates process maturity — we codified who does what because we had evidence of where handoffs were ambiguous.
  - **Level L7.** Move 2 completion is a method-shaping milestone: it establishes the boundary map that the Go rewrite (#192) will implement against. The TypeScript skill + Go skill together provide the engineering skill corpus for the two-language runtime future. CDD §1.4 Roles shapes every future cycle. This is architectural leverage, not just a code extraction.
- **Coherence contract closed?** **Yes.** #201 AC8 required CORE-REFACTOR.md §7 status block to read "Move 2 complete." It does. The extraction phase of #182 is closed. What remains is Move 3 (#180, doc coherence) and the Go rewrite (#192) — both are follow-on work, not open debt from this cycle.

### 2. Encoding Lag

| Issue | Title | Type | Design | Impl | Lag |
|-------|-------|------|--------|------|-----|
| #192 | Runtime kernel rewrite: OCaml → Go | feature | decision captured + Go skill converged | not started | growing |
| #193 | `llm` step execution + binding substitution | feature | needs design | not started | growing (carried 6 cycles) |
| #180 | Package system doc incoherence (Move 3) | feature | identified | not started | growing |
| #186 | Package restructuring | feature | design thread exists | not started | growing |
| #175 | CTB → orchestrator IR compiler | feature | CTB-v4.0.0-VISION.md | blocked on #193 | growing |
| #182 | Core refactor (umbrella) | feature | CORE-REFACTOR.md | Move 2 complete, Move 3 pending | low |
| #162 | Modular CLI commands | feature | Move 1 shipped | partial | low |
| #168 | L8 candidate tracking | process | observation | observation only | low |
| #154 | Thread event model P1 | feature | converged | not started | stale |
| #153 | Thread event model | feature | converged | not started | stale |
| #100 | Memory as first-class faculty | feature | partial | not started | stale |
| #94 | cn cdd: mechanize CDD invariants | feature | partial | not started | stale |

**MCI/MCA balance:** **Freeze MCI continues.** 5 issues at growing lag (#192, #193, #180, #186, #175). The freeze declared in v3.38.0 post-release remains valid. The Go skill and TypeScript skill are not new design commitments — they are engineering reference material that enables the next MCA. No new design docs until growing backlog is reduced.

**Rationale:** The design frontier (Go rewrite decision, package restructuring plan, CORE-REFACTOR.md) is well ahead of implementation. The next MCA must be implementation, not design.

### 3. Process Learning

**What went wrong:** Nothing significant. The cycle was the cleanest of all 4 Move 2 slices. The only observation is environmental: 9th consecutive cycle without local OCaml toolchain. Check 8 (draft-until-green) absorbs this — the author achieved first-push-green, so the toolchain gap caused zero downstream friction.

**What went right:**
1. **Zero review findings.** The first Move 2 cycle with none. Checks 7 and 8 are validated as correctives for the failure classes that hit slices 2 and 3.
2. **First-push CI green.** The author dogfooded check 8 formally and passed on the first attempt. The test/expect block stderr issue from slice 3 didn't recur because the author either avoided `Printf.eprintf` in test paths or accounted for it.
3. **CDD §1.4 Roles converged in the same session.** The ambiguity around "who merges, who releases, who assesses" was identified, discussed, and codified with evidence from this cycle's handoff. The rule emerged from practice, not theory.
4. **Reviewer-as-releaser validated.** This assessment is the first written by the reviewer (not the operator or the author). The independent evaluation context from the review carries directly into the assessment — no context transfer cost.

**Skill patches:** None needed this cycle.

**Active skill re-evaluation:** No review findings to evaluate. Zero findings means the skill corpus (including checks 7+8 from #198) adequately covers pure-type extraction work. The check 8 hypothesis ("mechanical failures should not reach the reviewer if the author verifies CI first") is confirmed for n=1 cycle.

**CDD improvement disposition:** No patch needed. Justification: (a) zero review findings, (b) no recurring failure mode, (c) the environmental constraint (no local OCaml) is fully absorbed by check 8. The CDD §1.4 Role updates shipped on main as direct-to-main small-change commits during the session, which is correct — they are governance/process changes that qualified under §1.2.

### 4. Review Quality

**PRs this cycle:** 1 (#202)
**Avg review rounds:** 1.0 (within ≤2 target for code PRs)
**Superseded PRs:** 0 (at 0 target)
**Finding breakdown:** 0 mechanical / 0 judgment / 0 total
**Mechanical ratio:** N/A (0/0)
**Action:** none

### 4a. CDD Self-Coherence

- **CDD α:** 4/4 — All required artifacts present: README (CDD trace + impact graph), SELF-COHERENCE, GATE (8-check gate, all formal), POST-RELEASE-ASSESSMENT (this file). CORE-REFACTOR.md §7 updated with "Move 2 complete" status block.
- **CDD β:** 4/4 — End-to-end agreement: CORE-REFACTOR.md design → `cn_frontmatter.ml` implementation → `cn_activation.ml` re-exports → test coverage → CHANGELOG row → this assessment. CDD §1.4 Roles codified and applied in this cycle (reviewer released and is now assessing). No authority conflicts.
- **CDD γ:** 4/4 — One review round (under target). Zero findings. Zero superseded PRs. Immediate outputs executed in this commit. First cycle where all 8 §2.5b checks were formal gate items. Process overhead for this cycle: minimal — the extraction pattern is now rote.
- **Weakest axis:** none below 4
- **Action:** none

### 5. Production Verification

**Scenario:** `cn_frontmatter.ml` is the canonical authority for frontmatter parsing and activation validation types. All callers that previously used `Cn_activation` functions now transparently use `Cn_frontmatter` functions via re-export.

**Before this release:** The frontmatter parser, `manifest_skill_ids`, `issue_kind`/`issue`/`issue_kind_label`, and `empty_frontmatter` lived in `cn_activation.ml` alongside IO functions (`read_skill_frontmatter`, `build_index`, `validate`). `src/lib/` held 4 modules.

**After this release:** `src/lib/cn_frontmatter.ml` owns all 12 pure surface items. `src/lib/` holds 5 modules. `cn_activation.ml` retains 3 IO functions + the slice-2 `activation_entry` re-export. The extraction boundary is mechanically verified: `grep -rn 'Cn_ffi\|Cn_executor\|Unix\.\|Sys\.' src/lib/cn_frontmatter.ml` returns empty.

**How to verify:**
1. `dune build` succeeds — all callers compile against re-exported types
2. `dune runtest` passes — 21 new tests in `test/lib/cn_frontmatter_test.ml` + all existing tests unchanged
3. `grep -rn 'Cn_ffi\|Cn_executor\|Unix\.\|Sys\.' src/lib/` returns empty across ALL 5 modules — the entire `src/lib/` is IO-free
4. `grep -rn '^type ' src/lib/` shows the complete pure type surface

**Result:** Pass (via CI). Release run 24223861504 succeeded. Items 1–4 are structurally verified by the CI pipeline + the purity grep. The boundary is structural (dune library cannot import IO modules), not just verified by grep — but the grep confirms the dune discipline holds.

**Move 2 cumulative verification:** After this slice, a new structural property holds: `src/lib/` IS the pure model layer and `src/cmd/` IS the IO layer. This can be verified by:
- `grep -c '^type ' src/lib/*.ml` → shows all canonical types
- `grep -rn 'Cn_ffi\|Cn_executor\|Cn_Shell\|Cn_Trace\|Cn_Assets\|Unix\.\|Sys\.' src/lib/` → empty (purity holds across all 5 modules)
- Each `src/cmd/` module that was extracted now contains only: type re-exports + delegating let-bindings + IO functions

### 6. CDD Closeout

| Step | Artifact | Skills loaded | Decision |
|------|----------|---------------|----------|
| 11 Observe | this assessment + PR #202 review (R1 APPROVED, 0 findings) + CHANGELOG row + release artifacts | post-release | Cycle coherent. All axes held or improved. Move 2 complete. Zero findings — checks 7+8 validated. |
| 12 Assess | `docs/gamma/cdd/3.41.0/POST-RELEASE-ASSESSMENT.md` (this file) | post-release | Scoring: C_Σ A · α A · β A+ · γ A · L7. MCI freeze continues. No skill patches needed. |
| 13 Close | this assessment + next-MCA commitment | post-release | Cycle closed. Immediate outputs executed. Deferred outputs committed in §7. |

### 7. Next Move

**Next MCA:** #180 — Package system doc incoherence (Move 3: retire beta package doc)
**Owner:** sigma (or delegated to Claude Code for implementation)
**Branch:** pending creation
**First AC:** Replace the beta package doc with a redirect stub pointing to the alpha doc and the actual package system as implemented.
**MCI frozen until shipped?** Yes — freeze continues from v3.38.0 (5 growing lag items remain).
**Rationale:** #180 is the last Move prerequisite before the Go rewrite (#192). It aligns documentation with the artifact-first reality that Moves 1+2 established. After #180, the Go rewrite has both a clean code boundary (Move 2) and a coherent doc surface (Move 3) to work from.

**Closure evidence (CDD §10):**
- Immediate outputs executed: yes
  - This `POST-RELEASE-ASSESSMENT.md`
  - CHANGELOG TSC row: verified matches assessment scoring (β A+ is the delta; self-score at release was A — assessment upgrades to A+ based on Move 2 completion + §1.4 formalization being a β improvement beyond what a single slice would earn). CHANGELOG to be updated in this commit.
- Deferred outputs committed: yes
  - #180 doc coherence (Move 3, growing lag — next MCA)
  - #192 Go kernel rewrite (growing, blocked on #180)
  - #193 `llm` step execution (growing, carried 6 cycles)
  - #186 package restructuring (growing)
  - #175 CTB compiler (growing, blocked on #193)

**Immediate fixes (executed in this commit):**
1. This `POST-RELEASE-ASSESSMENT.md`
2. CHANGELOG TSC row revision: update coherence note to reflect β A+ and L7 (Move 2 milestone)
