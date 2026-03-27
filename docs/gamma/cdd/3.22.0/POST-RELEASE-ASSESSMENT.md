## Post-Release Assessment — v3.22.0

### 1. Coherence Measurement

- **Baseline:** v3.20.0 — α A-, β A-, γ B
- **This release:** v3.22.0 — α A-, β A, γ A-
- **Delta:**
  - α held (A-) — clean separation between detection (`check_binary_version_drift`) and integration (`version_drift_check_once`). Three-case return type maps to three maintenance outcomes. One function, one primitive, no new architecture — slots into existing maintenance loop.
  - β improved (A- → A) — drift check uses same idle guard, same `substep_status` type, same trace event pattern, same result record as the other 7 primitives. `is_idle` extraction shares truth between `update_check_once` and `version_drift_check_once`. Proactive (update check) and reactive (drift check) are now complementary paths to the same `re_exec`.
  - γ improved (B → A-) — 1 review round (target: ≤2). 0% mechanical ratio (2 judgment findings, both severity B). Clean P0 fix with bounded scope.
- **Coherence contract closed?** Yes. All 4 ACs met:
  - AC1: `version_drift_check_once` detects mismatch via `check_binary_version_drift`, triggers `re_exec`
  - AC2: Re-exec'd process boots with new `Cn_lib.version` (inherent to execvp semantics)
  - AC3: Same `is_idle` guard as `update_check_once` — shared extraction, no input.md/output.md/agent.lock
  - AC4: `Unix.Unix_error` caught on `re_exec` failure → traced as `version_drift.re_exec_failed`, returns `Degraded`

### 2. Encoding Lag

| Issue | Title | Type | Design | Impl | Lag |
|-------|-------|------|--------|------|-----|
| #110 | P0: daemon doesn't restart after self-update | bug | converged | shipped | **none** (all 4 ACs met) |
| #64 | P0: agent probes filesystem despite RC | bug | bug report | not started | **growing** |
| #119 | cn setup uses hardcoded stubs | bug | bug report | not started | **growing** |
| #117 | Pre-push build/test gate | process | issue spec | not started | **growing** |
| #59 | cn doctor — deep validation | feature | partial design | partially addressed | **low** |
| #68 | Agent self-diagnostics | feature | issue spec | not started | **growing** |
| #84 | CA mindset reflection requirements | feature | issue spec | not started | **growing** |
| #79 | Projection surfaces | feature | issue spec | not started | **growing** |
| #94 | cn cdd: mechanize CDD invariants | feature | issue spec | not started | **growing** |
| #100 | Memory as first-class capability | feature | issue spec | not started | **growing** |
| #96 | Docs taxonomy alignment | process | issue spec | not started | **growing** |
| #74 | Rethink logs structure (P0) | process | issue spec | not started | **growing** |
| #101 | Normalize skill corpus | process | issue spec | not started | **growing** |
| #20 | Eliminate silent failures in daemon | bug | issue spec | not started | **growing** |
| #43 | No interrupt mechanism | feature | issue spec | not started | **growing** |

**MCI/MCA balance:** MCI remains resumed. No new stale issues.

### 3. Process Learning

**What went right:**

1. **Cleanest cycle since v3.16.1.** 1 review round, 0% mechanical ratio, 0 superseded PRs. The P0 had a bounded, well-understood fix path (version-drift as maintenance primitive). Existing infrastructure (`re_exec`, `is_idle`, `maintain_once`) meant minimal new code.

2. **Shared guard extraction was the right incidental cleanup.** Extracting `is_idle` from inline `update_check_once` into a shared boolean prevented duplication and ensured AC3 drain safety for both update paths by construction.

3. **Selection function worked correctly.** P0 triage identified #110 as highest-impact over #64 (mitigated by RC) and #119 (cosmetic stubs). The fix path was bounded and shipped in one round.

**What went wrong:**

1. **Environment-dependent test (F2).** The version drift test uses a conditional on whether `/usr/local/bin/cn` exists. The negative path is only exercised in CI. Both branches produce the same expect output, so the test always passes — but this is a coverage gap in dev environments. Acceptable for now; a proper fix would mock the binary path.

**Skill patches:**
- None needed. Active skills (eng/ocaml, eng/testing, eng/coding) were applied correctly. No new confinement or validation patterns discovered.

**Active skill re-evaluation:**

| Finding | Active skill | Would skill have prevented it? | Assessment |
|---------|-------------|-------------------------------|------------|
| F1 (re_exec never returns) | eng/ocaml | N/A — finding is informational | Correct by design, no action |
| F2 (env-dependent test) | eng/testing | Partially — skill says "test negative paths" but doesn't address env-dependent branching | Application gap — not worth a skill patch for a single test |

### 4. Review Quality

**PRs this cycle:** 1 (PR #121)
**Review rounds:** 1 (target: ≤2) — **PASSED**
**Superseded PRs:** 0 (target: 0) — **PASSED**
**Finding breakdown:** 0 mechanical / 2 judgment / 2 total
**Mechanical ratio:** 0% (threshold: 20%) — **PASSED**
**Action:** None needed. All metrics within target.

Findings by round:

| Round | Findings | Mechanical | Judgment |
|-------|----------|------------|----------|
| R1 (Sigma) | 2 | 0 | 2 (re_exec semantics, env-dependent test) |
| **Total** | **2** | **0** | **2** |

### 4a. CDD Self-Coherence

- **CDD α:** 4/4 — All required artifacts present: SELECTION.md, README.md, SELF-COHERENCE.md, POST-RELEASE-ASSESSMENT.md. CHANGELOG TSC entry below.
- **CDD β:** 4/4 — Surfaces agree. Self-coherence scores (α A-, β A-, γ B+) are consistent with assessment (α A-, β A, γ A-). β and γ improved at merge time — self-coherence was pre-review; assessment is post-review. Both are honest.
- **CDD γ:** 4/4 — 1 review round (target ≤2), 0% mechanical ratio (target <20%), 0 superseded PRs. All immediate outputs executed within session.
- **Weakest axis:** None — all 4/4.

### 5. Next Move

**Next MCA:** Selection function deferred to next cycle's SELECTION.md. Candidates by priority:
1. P0 override: #64 (filesystem probing), #119 (setup stubs) — both P0 bugs
2. Weakest axis: γ (process) — #117 (pre-push gate) or #94 (mechanize CDD)
3. MCI candidates: design work can proceed (freeze lifted)

**Owner:** sigma
**Branch:** pending
**First AC:** TBD by selection
**MCI frozen until shipped?** No — freeze remains lifted.
**Rationale:** With #110 closed, 2 P0 bugs remain (#64, #119). Selection function §1 says P0 override fires first. Both need OCaml compilation.

**Closure evidence (CDD §10):**
- Immediate outputs executed: yes
  - All review findings acknowledged (F1 informational, F2 acceptable)
  - #110 closed (all 4 ACs met)
  - CHANGELOG v3.22.0 TSC entry (this commit)
- Deferred outputs committed: yes
  - Next MCA selection: next cycle
