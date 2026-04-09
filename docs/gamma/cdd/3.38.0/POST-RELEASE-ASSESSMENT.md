## Post-Release Assessment — v3.38.0

**Release commit:** `3e66b04`
**Tag:** `3.38.0`
**Cycle:** #182 Move 2 first slice — pure package model into `src/lib/cn_package`
**PRs:** #188 (refactor) merged at `5825285` after 1 review round
**Branch (this assessment):** `claude/post-release-3.38.0`
**Skill loaded:** `packages/cnos.core/skills/cdd/post-release/SKILL.md`

### 1. Coherence Measurement

- **Baseline:** v3.37.0 — C_Σ A− · α A · β A · γ B+ · L6
- **This release:** v3.38.0 — C_Σ A · α A · β A · γ A · L5
- **Delta:**
  - **α held A.** Six types and seven pure helpers extracted from `cn_deps.ml` into `cn_package.ml`. Type-equality re-export (`type t = Cn_package.t = { ... }`) preserves caller type identity — zero migration required. The extraction is pure subtraction: `cn_deps.ml` loses 64 lines, gains 7 one-line delegations + 6 type re-exports. No new ambiguity introduced.
  - **β held A.** Single source of truth moved cleanly. `cn_package.ml` is now the canonical owner of manifest, lockfile, and index types. `cn_deps.ml` re-exports for compatibility. Dune lib comment documents the no-IO constraint. Only stdlib + `Cn_json` imported — purity discipline enforced structurally, not by convention.
  - **γ improved (B+ → A).** One review round (under the ≤2 target). Zero findings. Zero superseded PRs. The §2.5b 6-check pre-review gate was dogfooded clean — check 6 (schema/shape fixture audit) was N/A because type-equality preserves identity across all callers including test fixtures. The fixture-drift failure class that caused γ regression in v3.37.0 did not fire because the extraction technique structurally prevents it.
  - **Level L5.** This is a local-correctness extraction — no boundary moved, no new primitive, no cross-surface change. The types moved from one module to another within the same build. L5 is the honest label; the architectural significance is in establishing the pattern for the three remaining slices, not in the scope of this single extraction.
- **Coherence contract closed?** **Yes.** The first AC of Move 2 (extract one canonical pure-type module into `src/lib/`) is met. CORE-REFACTOR.md §7 status block updated with three remaining slices. The pattern (type-equality re-export, purity-enforced dune lib, test-first) is now established and repeatable.

### 2. Encoding Lag

| Issue | Title | Type | Design | Impl | Lag |
|-------|-------|------|--------|------|-----|
| #182 | Core refactor Move 2 — 3 remaining slices (runtime contract, workflow IR, activation) | feature | CORE-REFACTOR.md §7 | first slice shipped, 3 remaining | low |
| #180 | Package system doc incoherence (Move 3) | feature | identified | not started | growing |
| #193 | `llm` step execution + binding substitution | feature | needs design | not started | growing (carried 3 cycles) |
| #175 | CTB → orchestrator IR compiler | feature | CTB-v4.0.0-VISION.md | blocked on `llm` | growing |
| #162 | Modular CLI commands | feature | Move 1 shipped (#184) | partial | low |
| #186 | Package restructuring | feature | design thread exists | not started | growing |
| #168 | L8 candidate tracking | process | observation | observation only | low |
| #154 | Thread event model P1 | feature | converged | not started | stale |
| #153 | Thread event model | feature | converged | not started | stale |
| #100 | Memory as first-class faculty | feature | partial | not started | stale |
| #94 | cn cdd: mechanize CDD invariants | feature | partial | not started | stale |

**MCI/MCA balance:** **Freeze MCI.** Three issues at growing lag (`llm` execution carried 3 cycles, #175 blocked on it, #186 design committed but no implementation). Plus #180 at growing. The ≥3 growing threshold is met. No new design docs until the growing backlog is reduced.

**Rationale:** The vision doc (AGENT-NETWORK.md) and refactor design (CORE-REFACTOR.md) shipped in prior cycles. The design frontier is well ahead of implementation. Move 2 remaining slices, `llm` execution, and #180 doc coherence are all implementation work that reduces this lag. New designs would widen it.

### 3. Process Learning

**What went wrong:** Nothing significant. The cycle was clean — one review round, zero findings, CI green throughout. The only observation is that this is the sixth consecutive cycle without a local OCaml toolchain (environmental constraint, not a process gap).

**What went right:**
1. **Type-equality re-export technique proved out.** The extraction pattern structurally prevents the fixture-drift failure class that hit v3.37.0 — callers (including test fixtures) compile unchanged because the types are identical, not just structurally compatible. This is the right technique for the remaining three slices.
2. **§2.5b 6-check gate held clean on first application of check 6.** The new schema/shape fixture audit check (added in v3.37.0 post-release) was correctly evaluated as N/A for this PR because type-equality means no fixture edits were needed. The check exists to catch the case where they *are* needed; correctly identifying when it's N/A is also the gate working.
3. **Test-first held.** 11 ppx_expect tests authored before the production module per §2.5 artifact order. Coverage: round-trips (R1–R4), parsing (P1–P3), lookup (L1–L2), first-party check (F1–F2).
4. **One review round, zero findings.** Best cycle execution since v3.36.0. The reviewer noted "textbook extraction" — the pattern is clean and repeatable.

**Skill patches:** None needed this cycle. Justification below.

**Active skill re-evaluation:** No review findings to evaluate. The zero-finding outcome validates that the existing skill corpus (including the v3.37.0 §2.5b check 6 patch) adequately covers pure-type extraction work.

**CDD improvement disposition:** No patch needed. Justification: (a) zero review findings this cycle, (b) no recurring failure mode identified, (c) the environmental constraint (no local OCaml) is not addressable at the skill specification level. The self-learning loop closes with "existing skills adequate for this work shape."

### 4. Review Quality

**PRs this cycle:** 1 (#188)
**Avg review rounds:** 1.0 (within ≤2 target for code PRs)
**Superseded PRs:** 0 (within 0 target)
**Finding breakdown:** 0 mechanical / 0 judgment / 0 total
**Mechanical ratio:** N/A (0/0)
**Action:** none

### 4a. CDD Self-Coherence

- **CDD α:** 4/4 — All required artifacts present: README (CDD trace + impact graph), SELF-COHERENCE, GATE, POST-RELEASE-ASSESSMENT (this file). CORE-REFACTOR.md §7 status block updated.
- **CDD β:** 4/4 — End-to-end agreement: CORE-REFACTOR.md design → `cn_package.ml` implementation → `cn_deps.ml` re-exports → test coverage → CHANGELOG row → this assessment. No authority conflicts or stale references.
- **CDD γ:** 4/4 — One review round (under target). Zero findings. Zero superseded PRs. Immediate outputs executed in this commit. MCI freeze declared based on lag table evidence.
- **Weakest axis:** none below 3
- **Action:** none

### 5. Production Verification

**Scenario:** `cn_package.ml` is the canonical authority for package manifest, lockfile, and index types. All callers that previously referenced `Cn_deps` types now transparently use `Cn_package` types via re-export.

**Before this release:** Package types lived in `cn_deps.ml` alongside IO functions (download, restore, doctor). No structural separation between pure model and effectful operations. `src/lib/` existed but contained only `cn_json.ml`.

**After this release:** `src/lib/cn_package.ml` owns 6 types + 7 pure helpers + JSON round-trips. `src/lib/` now has two modules (`cn_json`, `cn_package`), establishing the pattern for further extraction. `cn_deps.ml` retains all IO functions and re-exports types via equality.

**How to verify:**
1. `dune build` succeeds — all callers compile against the re-exported types
2. `dune runtest` passes — 11 new tests in `test/lib/cn_package_test.ml` + all existing tests unchanged
3. `grep -rn 'Cn_ffi\|Cn_executor\|Unix\.\|Sys\.' src/lib/cn_package.ml` returns empty — purity holds
4. `grep -rn 'Cn_package\.' src/cmd/cn_deps.ml` shows type-equality re-exports and delegations only

**Result:** Pass (via CI). Release run 24175755233 succeeded — all 3 checks green (ocaml build+test, protocol contract, package drift). Items 1–4 are structurally verified by the CI pipeline. No runtime behavioral change to verify in production — this is a code organization change with identical runtime semantics.

### 6. CDD Closeout

| Step | Artifact | Skills loaded | Decision |
|------|----------|---------------|----------|
| 11 Observe | this assessment + PR #188 review (R1 APPROVED, 0 findings) + CHANGELOG row + release artifacts | post-release | Cycle coherent. All axes held or improved. Type-equality extraction pattern validated. |
| 12 Assess | `docs/gamma/cdd/3.38.0/POST-RELEASE-ASSESSMENT.md` (this file) | post-release | Scoring: C_Σ A · α A · β A · γ A · L5. MCI freeze declared (≥3 growing lag items). No skill patches needed. |
| 13 Close | this assessment + next-MCA commitment | post-release | Cycle closed. Immediate outputs executed. Deferred outputs committed in §7. |

### 7. Next Move

**Next MCA:** #182 Move 2 second slice — runtime contract record types into `src/lib/cn_runtime_contract_types.ml` (or similar)
**Owner:** sigma
**Branch:** pending creation
**First AC:** Extract the pure record types from `cn_runtime_contract.ml` into a new `src/lib/` module using the same type-equality re-export pattern established by `cn_package.ml`. No IO code moves.
**MCI frozen until shipped?** Yes — freeze declared in §2 based on ≥3 growing lag items.
**Rationale:** Continue the established extraction pattern. Runtime contract types are the second-largest pure surface in `src/cmd/` after package types. Extracting them consolidates the model layer that `llm` execution and future work will build against.

**Closure evidence (CDD §10):**
- Immediate outputs executed: yes
  - This `POST-RELEASE-ASSESSMENT.md`
  - CHANGELOG TSC row verified (matches assessment scoring — no revision needed)
- Deferred outputs committed: yes
  - #182 Move 2 slices 2–4 (runtime contract types, workflow IR, activation evaluator)
  - `llm` step execution (carried 3 cycles, growing lag)
  - #175 CTB compiler (blocked on `llm`)
  - #180 doc coherence (growing)
  - #186 package restructuring (growing)

**Immediate fixes (executed in this commit):**
1. This `POST-RELEASE-ASSESSMENT.md`
2. CHANGELOG TSC row: verified accurate, no revision needed
