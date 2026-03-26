## Post-Release Assessment — v3.19.0

### 1. Coherence Measurement

- **Baseline:** v3.18.0 — α A-, β B+, γ B-
- **This release:** v3.19.0 — α A, β A-, γ B+
- **Delta:**
  - α improved (A- → A) — integrity hash design is structurally clean (sorted tree walk, deterministic digest, prefixed format for migration). Doctor validates the full desired→resolved→installed chain. Runtime Contract type expansion propagated through all three consumers (gather, render_markdown, to_json). No structural debt introduced.
  - β improved (B+ → A-) — all three ACs connect: lock generation → integrity hash → restore verification → doctor validation → Runtime Contract exposure. Single hash truth flows from lock through install to agent self-model. Multi-format parity confirmed (markdown + JSON carry equivalent provenance). One gap: md5 is drift-grade not adversarial-grade, but threat model is documented and prefix enables migration.
  - γ improved (B- → B+) — 1 review round (target: ≤2) — first cycle to meet the target since v3.16.1. 3 findings, 33% mechanical ratio (below 50% for first time in 3 cycles). No superseded PRs. Skills declared and applied during generation. Self-review caught 2 of the 3 findings (nested match parens, Str dependency) before external review.
- **Coherence contract closed?** Yes. AC5 (integrity generated and verified), AC6 (doctor validates package-system truth), AC7 (Runtime Contract package truth complete). #113 now has AC3-AC7 shipped across v3.18.0 and v3.19.0.

### 2. Encoding Lag

| Issue | Title | Type | Design | Impl | Lag |
|-------|-------|------|--------|------|-----|
| #113 | Package System Substrate | feature | converged (#113 spec) | AC3-AC7 shipped | **low** (AC8 remains) |
| #73 | Runtime Extensions | feature | converged | Phase 1+2 partial shipped | **low** |
| #59 | cn doctor — deep validation | feature | partial design | partially addressed by AC6 | **low** |
| #65 | Communication — surfaces, transport | feature | converged (issue spec) | not started | **stale** |
| #67 | Network access as CN Shell capability | feature | converged (subsumed by #73) | not started | **stale** |
| #64 | P0: agent probes filesystem despite RC | process | bug report | not started | growing |
| #68 | Agent self-diagnostics | feature | converged (issue spec) | not started | growing |
| #84 | CA mindset reflection requirements | feature | design (issue spec) | not started | growing |
| #79 | Projection surfaces | feature | design (issue spec) | not started | growing |
| #94 | cn cdd: mechanize CDD invariants | feature | design (issue spec) | not started | growing |
| #100 | Memory as first-class capability | feature | design (issue spec) | not started | growing |
| #96 | Docs taxonomy alignment | process | design (issue spec) | not started | growing |
| #74 | Rethink logs structure (P0) | process | design (issue spec) | not started | growing |
| #101 | Normalize skill corpus | process | design (issue spec) | not started | growing |
| #20 | Eliminate silent failures in daemon | bug | issue spec | not started | growing |
| #43 | No interrupt mechanism | feature | issue spec | not started | growing |

**MCI/MCA balance:** Freeze MCI — 2 stale issues remain (#65, #67). Freeze holds.

**Rationale:** #113 AC5-AC7 shipped. #59 partially addressed (AC6 doctor depth). Neither moves #65 or #67 directly. #73 completion would unblock #67 (subsumed), but #73 Phase 2 still has remaining work absorbed into #113. After #113 AC8 ships, the package substrate is complete and #67 can be addressed.

### 3. Process Learning

**What went right:**

1. **First cycle to meet review round target.** 1 round (target: ≤2). Self-review caught 2 of 3 eventual findings before external review. Active skill application during generation prevented the mechanical cascade seen in v3.17.0 and v3.18.0.

2. **Mechanical ratio dropped below 50%.** 33% (1 mechanical / 3 total). The `List.hd` finding was genuine eng/ocaml debt but not a build-breaking issue. The bare catch and md5 documentation findings were judgment calls, not compilation errors.

3. **Clean AC chain.** All three ACs implemented in one commit, one review round, no scope creep. The integrity→doctor→RC truth chain was designed at bootstrap and executed without deviation.

4. **CDD selection document proved useful.** The SELECTION.md (written at cycle start) correctly identified the gap, mode, and skills. No mid-cycle pivot needed.

**What went wrong:**

1. **Still no OCaml toolchain.** The `List.hd` finding (F1) would have been caught by a linter. The bare catch pattern (F2) might have been caught by `-w +52` warning. Environmental debt persists.

2. **md5 vs sha256 acknowledged but not resolved.** Using stdlib Digest (md5) avoids a dependency but leaves a known weakness. Documented with migration prefix — acceptable for now but should be tracked.

**Skill patches:** None needed. eng/ocaml, eng/testing, eng/coding were correctly loaded and applied.

### 4. Review Quality

**PRs this cycle:** 1 (PR #115)
**Review rounds:** 1 (target: ≤2) — **PASSED**
**Superseded PRs:** 0 (target: 0) — **PASSED**
**Finding breakdown:** 1 mechanical / 2 judgment / 3 total
**Mechanical ratio:** 33% (threshold: 20%) — improved but still above threshold
**Action:** Ratio improved from 57% → 33%. Root cause (no OCaml toolchain) unchanged but impact reduced by better self-review. Continue applying eng/ocaml actively during generation rather than relying on post-hoc review.

Findings by round:

| Round | Findings | Mechanical | Judgment |
|-------|----------|------------|----------|
| R1 (Sigma) | 3 | 1 (List.hd partial function) | 2 (bare catches, md5 threat model docs) |
| **Total** | **3** | **1** | **2** |

### 5. Next Move

**Next MCA:** #113 AC8 — Extensions and future bundles/apps sit above package substrate without redesign
**Owner:** sigma
**Branch:** pending
**Rationale:** AC3-AC7 shipped. AC8 is the final AC for #113 — validates that the substrate supports extensions and future content types without requiring package system changes. After AC8, #113 closes and MCI freeze can be re-evaluated.

**Alternative:** If AC8 is already met by existing extension architecture (extensions already sit above packages), close #113 and move to MCI freeze resolution — address #65 or #67 directly.

**MCI frozen until shipped?** Yes — freeze holds from v3.16.2 assessment. Must resolve after #113 closes.

**Closure evidence (CDD §10):**
- Immediate outputs executed: yes
  - All review findings resolved (F1-F3)
  - CHANGELOG v3.18.0 TSC entry added (committed in earlier push)
  - CHANGELOG v3.17.0 TSC corrected (committed in earlier push)
- Deferred outputs committed: yes
  - #113 AC8 evaluation: next cycle
  - MCI freeze re-evaluation: after #113 closes
  - md5 → sha256 migration: when crypto library added to deps
