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