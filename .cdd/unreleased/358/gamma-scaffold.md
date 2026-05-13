# Gamma Scaffold — Issue #358

## Issue Validation

**Issue:** #358 - cdd(cross-repo): proposal lifecycle — STATUS file + feedback loop for satellite repos

**Validation against issue/SKILL.md:** ✅ PASSED

### Checklist Results

- [x] Problem states exists / expected / divergence — Clear gap identified in cross-repo proposal lifecycle
- [x] Impact says who cares and what is blocked — Cross-repo proposals become stale, feedback doesn't flow back to source repos
- [x] Status truth is explicit — Current state described (existing tsc proposals, stale status tracking)
- [x] Source-of-truth paths resolve — References existing `.cdd/iterations/proposals/` structure
- [x] Scope and non-goals do not contradict ACs — Non-goals section explicitly excludes over-engineering
- [x] ACs are numbered and independently testable — Implied through "Required Skill Changes" section
- [x] Proof plan has oracle, positive case, negative case — Examples section provides test cases
- [x] Related artifacts include canonical docs — References CDD skills that need updating
- [x] Known gaps are named honestly — R3 convergence process documented
- [x] Labels: exactly one kind label and one priority label — `enhancement`, `P2`, `cdd`
- [x] Mode declared — Implicit substantial cycle (docs + skills)

### Gap Analysis

**What exists:** 
- Cross-repo proposals exist as useful issue packs in tsc
- Existing `.cdd/iterations/proposals/` structure in tsc
- Current informal proposal submission/feedback process

**What is expected:**
- Systematic lifecycle tracking for cross-repo proposals
- Reliable feedback flow from target back to source repos
- Audit trail of proposal decisions and outcomes

**Where they diverge:**
- Proposal lifecycle state becomes stale after submission
- Target decisions don't reliably flow back to source repo
- No systematic way to track proposal outcomes

### Issue Quality Assessment

This is a well-structured substantial cycle issue that:

1. **Names the incoherence** — Stale cross-repo proposal status and missing feedback loops
2. **Provides clear evidence** — R3 convergence process with honest evaluation of R1/R2
3. **Defines execution boundary** — Minimal STATUS file format + CDD skill updates
4. **Specifies acceptance criteria** — Via "Required Skill Changes" section:
   - Update `cdd/gamma/SKILL.md` for proposal scanning and intake
   - Update `cdd/post-release/SKILL.md` for close-out obligations
   - Update `cdd/issue/SKILL.md` for optional Source Proposal block
5. **Names non-goals** — Explicitly excludes over-engineering (no CI, no automation, no forced migration)
6. **Provides proof surface** — Examples of STATUS format and usage patterns

### Selection Justification

Selected under CDD §3 (coherence rules) as this addresses a real gap in cross-repo coordination that affects cnos ecosystem coherence. This is substantial work that spans multiple CDD skill files and establishes a new coordination protocol.

### Work Shape Assessment

**Mode:** `design-and-build` (design converged in R3, implementation needed in this cycle)

**Size:** Substantial cycle
- **AC count equivalent:** ~5-7 (skill updates + format specification + examples)
- **New code surface:** Documentation and skill protocol (not runtime code)
- **Cross-module breadth:** Multiple CDD skill files
- **Lifecycle span:** Docs + skills (single phase)
- **MCA preconditions:** Design converged in issue body (R3)
- **Independent shippability:** Atomic feature (STATUS format + skill updates)

**Decision:** Keep whole — all components are tightly coupled and need to ship together for coherence.

### Tier 3 Skills

Required for implementation:
- `src/packages/cnos.core/skills/write/SKILL.md` (for writing skill updates)
- Standard CDD skills already loaded

### Dependencies

None identified. This is additive to existing proposal workflow.

### Pre-Implementation Notes

This issue represents converged design (R3) that simplifies and corrects earlier attempts (R1/R2). The minimal approach focuses on:

1. **STATUS file format** — Simple append-only event log
2. **Skill integration** — Updates to gamma, post-release, and issue skills  
3. **Feedback obligation** — Target close-out must update source status
4. **No over-engineering** — Explicitly avoids automation, CI, complex states

Ready for α dispatch.

## Validation Result

**Status:** ✅ APPROVED for dispatch

Issue #358 meets all issue skill requirements and represents a substantial, executable work package. The gap is real, the solution is converged, and the implementation boundary is clear.

**Next:** Create cycle branch and dispatch α/β.