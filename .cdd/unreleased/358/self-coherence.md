# Self-Coherence Report — Issue #358

## §Gap

**Issue:** #358 - cdd(cross-repo): proposal lifecycle — STATUS file + feedback loop for satellite repos

**Version/Mode:** substantial cycle / docs+skills (design converged in R3)

**Gap Analysis:**

**What exists:**
- Cross-repo proposals exist as useful issue packs in tsc  
- Existing `.cdd/iterations/proposals/` structure in tsc
- Current informal proposal submission/feedback process via direct communication

**What is expected:**
- Systematic lifecycle tracking for cross-repo proposals
- Reliable feedback flow from target back to source repos
- Audit trail of proposal decisions and outcomes
- Minimal overhead STATUS file format that agents can maintain

**Where they diverge:**
- Proposal lifecycle state becomes stale after submission
- Target decisions don't reliably flow back to source repo  
- No systematic way to track proposal outcomes
- Missing integration with CDD skills for systematic observation and close-out

**Impact:**
This gap affects cnos ecosystem coherence — satellite repos propose valuable changes but the lifecycle tracking is informal and feedback is unreliable. This leads to stale proposals, lost coordination context, and missed opportunities for cross-repo improvements.

**Root cause:** Missing protocol for systematic proposal lifecycle management with bidirectional feedback between source and target repos.

## §Skills

**Active Skills:**

**Tier 1:**
- `CDD.md` — canonical lifecycle and role contract
- `alpha/SKILL.md` — α role surface and algorithm
- `issue/SKILL.md` — for interpreting issue quality and AC boundaries

**Tier 2:**
- `cnos.core/skills/write/SKILL.md` — for writing skill artifacts
- `cnos.core/skills/skill/SKILL.md` — for authoring and modifying skills

**Tier 3:**
- `cross-repo-proposal/SKILL.md` — new skill being implemented
- `gamma/SKILL.md`, `post-release/SKILL.md`, `issue/SKILL.md` — skills being updated

**Skills application:**
This cycle produces documentation and skill updates, not runtime code. Write skill constrains documentation authoring for clarity and precision. The issue skill guides template updates. The cross-repo proposal skill defines the new protocol being implemented.

## §ACs

**AC1: Add STATUS file format spec and lifecycle to appropriate CDD skill files**
- Evidence: Created `src/packages/cnos.cdd/skills/cdd/cross-repo-proposal/SKILL.md` with comprehensive STATUS format specification
- Evidence: Created `src/packages/cnos.cdd/skills/cdd/cross-repo-proposal/EXAMPLES.md` with concrete usage examples
- Status: ✅ COMPLETE

**AC2: Update gamma/SKILL.md with cross-repo proposal scanning in observation/selection**
- Evidence: Updated `gamma/SKILL.md` §2.1 to add cross-repo proposal scanning to observation surfaces
- Evidence: Added scanning for both `.cdd/iterations/proposals/*/STATUS` and `.cdd/proposals/{target}/*/STATUS` formats
- Status: ✅ COMPLETE

**AC3: Update gamma/SKILL.md with close-out obligation for landed proposals**
- Evidence: Updated `gamma/SKILL.md` §2.7 to add mandatory cross-repo proposal status update step
- Evidence: Added requirement to append `landed` events to source STATUS or emit feedback patches
- Status: ✅ COMPLETE

**AC4: Update post-release/SKILL.md with proposal status checklist item**
- Evidence: Updated `post-release/SKILL.md` pre-publish gate checklist
- Evidence: Added "Cross-repo proposal status updated or feedback patch emitted" checklist item
- Status: ✅ COMPLETE

**AC5: Update issue/SKILL.md with optional Source Proposal block**
- Evidence: Updated `issue/SKILL.md` minimal output pattern template
- Evidence: Added optional "Source Proposal" section with source, commit, disposition, and delta fields
- Status: ✅ COMPLETE

**AC6: Keep changes minimal (docs+skill issue)**
- Evidence: Implementation focused solely on skill updates and format specification
- Evidence: No runtime code changes, no automation, no CI integration per non-goals
- Status: ✅ COMPLETE

## §Self-check

**Did α's work push ambiguity onto β?**

No. The implementation is complete and self-contained:
- All skill updates follow established patterns and conventions
- New cross-repo-proposal skill has comprehensive documentation with examples
- Changes are additive to existing skills without breaking existing functionality
- All file references and paths are concrete and verifiable

**Is every claim backed by evidence in the diff?**

Yes:
- Each AC maps to specific file changes in the diff
- STATUS format specification is fully documented with examples
- Skill integrations are explicit and follow CDD patterns
- No implementation claims without corresponding file evidence

**Clarity for β review:**

The implementation follows standard CDD skill authoring patterns:
- Skill files use established frontmatter format
- Documentation follows CDD writing conventions  
- Integration points are explicit in gamma, post-release, and issue skills
- Examples provide concrete usage guidance for future implementers

## §Debt

**Known limitations:**

1. **No migration tooling** — Implementation provides protocol but no automated migration from existing tsc proposal status tracking. This is intentional per issue non-goals ("No broad migration").

2. **No CI validation** — STATUS format is documented but not validated by CI. This is intentional per R3 decision to avoid automation until manual protocol proves stable.

3. **Transport dependency** — Protocol assumes git access between repos. If git access is unavailable, fallback to manual patch application is required.

**Acceptable technical debt:**

All identified limitations align with issue R3 convergence decision to implement minimal viable protocol without over-engineering. Future automation can be added after manual protocol validation.

## §CDD-Trace

**CDD Algorithm trace through step 7:**

**Step 1 - Receive:** ✅ Received dispatch for issue #358, configured alpha git identity, checked out cycle/358 branch

**Step 2 - Issue interpretation:** ✅ Read issue #358 fully, identified gap in cross-repo proposal lifecycle, loaded required skills per Tier 1/2/3 specification

**Step 3 - Design:** ✅ Design converged in issue R3 — minimal STATUS format + CDD skill integrations. No separate design artifact required.

**Step 4 - Plan:** ✅ Implementation sequence: skill updates → new cross-repo-proposal skill → examples → self-coherence. No complex sequencing required.

**Step 5 - Tests:** ⚠️ No automated tests applicable — this is docs+skills work. Manual verification via skill integration points and example validation.

**Step 6 - Implementation artifacts:**

Files created/modified:
- `src/packages/cnos.cdd/skills/cdd/gamma/SKILL.md` — Added cross-repo proposal observation + close-out
- `src/packages/cnos.cdd/skills/cdd/post-release/SKILL.md` — Added checklist item
- `src/packages/cnos.cdd/skills/cdd/issue/SKILL.md` — Added Source Proposal template block
- `src/packages/cnos.cdd/skills/cdd/cross-repo-proposal/SKILL.md` — New comprehensive skill
- `src/packages/cnos.cdd/skills/cdd/cross-repo-proposal/EXAMPLES.md` — Concrete usage examples
- `.cdd/unreleased/358/gamma-scaffold.md` — Validation artifact
- `.cdd/unreleased/358/self-coherence.md` — This file

**Peer enumeration:** All CDD skill files that needed integration have been updated. No missing sibling surfaces.

**Step 7 - Docs:** ✅ Comprehensive documentation provided via new cross-repo-proposal skill and examples. All existing skills updated with integration points.

**Step 7a - Self-coherence:** ✅ This artifact documents gap closure, AC mapping, and review readiness.