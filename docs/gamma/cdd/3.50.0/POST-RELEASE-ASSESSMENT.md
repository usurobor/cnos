# Post-Release Assessment — v3.50.0

## 1. Coherence Measurement

- **Baseline:** v3.49.0 — α A+, β A, γ A+
- **This release:** v3.50.0 — α A+, β A+, γ A+
- **Delta:** β improved A→A+ (design-principles skill + architecture review gate close the "how do we evaluate design coherence" gap). α held (all 8 kernel commands, dispatch boundary CI-enforced). γ held (full CDD invariants chain: author→handoff→review→close→CI).
- **Coherence contract closed?** Yes. Phase 3 complete — all 8 kernel commands implemented and deployed. The Go kernel can now manage its own lifecycle (init, setup, deps, status, doctor, build, update, help). 63 tests.

## 2. Encoding Lag

| Issue | Title | Type | Design | Impl | Lag |
|-------|-------|------|--------|------|-----|
| #193 | Orchestrator llm step | feature | converged | not started | growing (13 cycles) |
| #186 | Package restructuring | feature | design doc shipped | not started | growing |
| #175 | CTB → orchestrator IR compiler | feature | converged | not started | growing |
| #218 | cnos.transport.git | feature | design doc shipped | not started | growing |
| #216 | Kernel command migration | feature | design doc shipped | depends on Phase 4 | growing |
| #224 | src/packages/ layout migration | feature | BUILD-AND-DIST shipped | not started | growing |
| #192 | Go kernel rewrite | feature | converged | Phase 3 complete | low |

**MCI freeze:** active. 6 growing items (was 5 — #224 added). #212 closed (Phase 3 complete). #192 drops to low.

**MCI/MCA balance: Freeze MCI** — 6 items at growing lag. No new design commitments until implementation catches up. Next MCA: #224 (layout migration).

**Rationale:** Phase 3 closes the "can the Go binary manage itself" question. The design frontier is well ahead of implementation. #224 is prerequisite infrastructure for #186 and #216. Ship layout before new designs.

## 3. Process Learning

**What went wrong:** Last session's post-deploy verification was incomplete — chained SSH commands masked individual command failures. `cn update --check` was tested but `--check` is a `cn build` flag, not `cn update` flag. The flag confusion came from the summary context, not from the code.

**What went right:**
- PR #225 review caught `marshalDeps` manual JSON construction (F1) — fixed with `json.MarshalIndent`. 1 finding, 1 round to fix.
- I1 coherence CI caught design-principles manifest drift on main (`eccdd92`) — first real coherence CI catch. The tool enforced the principle before the author did.
- CDD §2.2.14 architecture check (7 questions A-G) shipped as a mechanical review gate — turns design principles into verdict-blocking questions.
- BUILD-AND-DIST migration steps made explicit — 6 sequenced steps from current to target layout.
- T-004 premature canonicalization fixed — both current and target layouts now explicitly named.

**Skill patches:** CDD review §2.2.14 + §2.3.5 shipped in this cycle (`c3c5123`). eng/design-principles skill shipped (`d63d0ca`). Both synced.

**Active skill re-evaluation:** F1 (marshalDeps manual JSON) — eng/go skill already covers stdlib preference (§2.1). This was an application gap, not a skill gap. The implementer used `fmt.Sprintf` where `encoding/json` was the obvious stdlib tool. No skill patch needed.

**CDD improvement disposition:** Two patches landed this cycle:
1. §2.2.14 architecture check — turns design principles into 7 concrete review questions (A-G)
2. §2.3.5 verdict gate — any "no" on architecture questions blocks approval

These close the gap between "we have design principles" and "design principles affect review outcomes."

## 4. Review Quality

**PRs this cycle:** 1 (PR #225 — update + setup commands)
**Avg review rounds:** 2.0 (R1: 1 finding, R2: fixed — at target for code PRs)
**Superseded PRs:** 0
**Finding breakdown:** 1 judgment / 0 mechanical / 1 total
**Mechanical ratio:** 0% (well under 20% threshold)
**Action:** none

### 4a. CDD Self-Coherence

- **CDD α:** 4/4 — All required artifacts present. Bootstrap complete. Self-coherence tracked.
- **CDD β:** 4/4 — Canonical doc, executable skill, PR artifacts, changelog, and assessment agree. §2.2.14 + §2.3.5 shipped and synced across all surfaces. Triadic role model converged (post-release cleanup: `c7a64db` removed duplication).
- **CDD γ:** 4/4 — 1 review round to fix, 0 superseded PRs, 0% mechanical ratio. Immediate outputs executed (skill patches in-cycle). Deferred outputs committed (#224).
- **Weakest axis:** none (all 4/4)
- **Action:** none

## 5. Production Verification

**Scenario:** All 8 Go kernel commands execute on production VPS.

**Before this release:** `cn update` and `cn setup` did not exist in Go binary.

**After this release:** Both commands work. `cn update` checks GitHub releases, verifies SHA-256, performs atomic install. `cn setup` creates hub structure with default deps.

**How to verify:** SSH to VPS, run each command in a real hub.

**Result:** PASS
- `cn --version` → `cn 3.50.0 (f780d8d)` ✓
- `cn doctor` → 16 pass, 2 known failures (version drift — packages at 3.16.2, expected given no package rebuild since then) ✓
- `cn setup` → "Hub setup complete!" ✓
- `cn status` → hub state displayed with version drift warnings ✓
- `cn update` → "Already up to date (3.50.0 f780d8d)", auto-committed runtime state ✓

**Note:** `cn update --check` is not a valid flag (that's `cn build --check`). The flag was misidentified in the prior session. No code bug — operator error in testing.

## 6. CDD Closeout

| Step | Artifact | Skills loaded | Decision |
|------|----------|--------------|----------|
| 11 Observe | VPS production verification | post-release | all 8 commands pass |
| 12 Assess | POST-RELEASE-ASSESSMENT.md | post-release | assessment completed |
| 12a Skill patch | §2.2.14 + §2.3.5 | post-release, review | architecture review gate shipped in-cycle |
| 13 Close | #224 next MCA | post-release | cycle closed, deferred outputs committed |

### 6a. Invariants Check

| Constraint | Touched? | Status |
|---|---|---|
| INV-001 (single config authority) | No | preserved |
| INV-002 (content-class closed set) | No | preserved |
| INV-003 (pure model gravity) | No | preserved |
| INV-004 (NDJSON transport) | No | preserved |
| INV-005 (manifest schema) | No | preserved |
| INV-006 (coherence CI) | Yes — first real catch | preserved (validated by `eccdd92` fix) |
| T-001 (Go extraction) | Yes — Phase 3 complete | preserved |
| T-002 (cli/ dispatch) | No | preserved (CI-enforced) |
| T-003 (package migration) | No | preserved |
| T-004 (source layout) | Yes — current+target named | tightened (`310ec2f`) |
| T-005 (OCaml deprecation) | No | preserved |

## 7. Next Move

**Next MCA:** #224 — migrate to src/packages/ layout
**Owner:** Claude (implementor), Sigma (reviewer)
**Branch:** pending creation
**First AC:** Move `packages/cnos.core/` to `src/packages/cnos.core/`, update `cn build` to read from new location
**MCI frozen until shipped?** Yes
**Rationale:** #224 eliminates the manual sync between `src/agent/` and `packages/` — the source of the drift that I1 caught. It's prerequisite to #186 (package restructuring) and #216 (command migration). Infrastructure before features.

**Closure evidence (CDD §10):**
- Immediate outputs executed: yes
  - CDD review §2.2.14 + §2.3.5 (`c3c5123`)
  - eng/design-principles skill (`d63d0ca`)
  - I1 drift fix (`eccdd92`)
  - T-004 canonicalization fix (`310ec2f`)
  - BUILD-AND-DIST migration steps (`9830cc2`)
  - CDD §1.4 duplication cleanup (`c7a64db`)
- Deferred outputs committed: yes
  - #224 — src/packages/ layout migration (owner: Claude+Sigma, MCI frozen)

**Immediate fixes** (executed this session):
- CDD §1.4 triadic role duplication cleanup (`c7a64db`)

## 8. Hub Memory

- **Daily reflection:** `cn-sigma/threads/reflections/daily/20260411-a.md`
- **Adhoc thread(s) updated:** `cn-sigma/threads/adhoc/20260409-go-kernel-rewrite.md` (Phase 3 complete entry already present from release session)
