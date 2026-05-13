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