## Post-Release Assessment — v3.39.0

**Release commit:** *(pending cut)* — the feature PR #195 merged at `7f2d4b9` on `main`; the formal `release: 3.39.0` VERSION-bump + CHANGELOG row + package stamp commit is a separate track and can reference this assessment once cut.
**Tag:** `3.39.0` (pending cut)
**Cycle:** #194 — #182 Move 2 slice 2: extract runtime contract types into `src/lib/`
**PRs:** #195 (feature) merged at `7f2d4b9` after **2 review rounds** (R1 REQUEST CHANGES — F1 mechanical; R2 APPROVED)
**Branch (this assessment):** `claude/post-release-3.39.0-3.40.0` (stacked with v3.40.0 per CDD §9 cycle economics — both cycles' §9.1 triggers share the same root cause and corrective, so one PR is the honest shape)
**Skill loaded:** `packages/cnos.core/skills/cdd/post-release/SKILL.md` — re-read in full before writing this assessment
**Stacking note:** This assessment was written together with `docs/gamma/cdd/3.40.0/POST-RELEASE-ASSESSMENT.md`. Both cycles' §9.1 cycle iteration sections point to the same corrective — PR #198 (the §2.5b check 7 + check 8 skill patch), which was written in parallel with the v3.40.0 fix commits and shipped ahead of this assessment. Writing both assessments simultaneously avoids duplicating the §12a skill-patch narrative across two separate PRs.

### 1. Coherence Measurement

- **Baseline:** v3.38.0 — C_Σ A · α A · β A · γ A · L5
- **This release:** v3.39.0 — C_Σ A− · α A · β A · γ B+ · L5
- **Delta:**
  - **α held A.** The diff is structural subtraction: 11 pure runtime-contract record types (`package_info`, `override_info`, `zone`, `zone_entry`, `identity`, `extension_contract_info`, `command_entry`, `orchestrator_entry`, `cognition`, `body_contract`, `runtime_contract`) moved byte-for-byte from `src/cmd/cn_runtime_contract.ml` into `src/lib/cn_contract.ml`. The `activation_entry` transitive dependency was pulled through via a chained re-export (`cn_activation.ml → Cn_contract.activation_entry`) because `cognition.activation_index` references it. OCaml type-equality (`type t = Cn_contract.t = { ... }`) preserved compile-time type identity — `Cn_runtime_contract.package_info` and `Cn_contract.package_info` became literally the same type, verified by the fact that existing pattern matches in `render_markdown` and `to_json` closures (still referencing `Cn_activation.activation_entry` by qualified name) continued to compile unchanged. Field names, constructor names, and the `sha256 : string option` shape all preserved exactly.
  - **β held A.** Single canonical authority for the runtime contract types now lives in `Cn_contract`. `Cn_runtime_contract` re-exports each type via type-equality syntax + delegates `zone_to_string` via a one-line let-binding. Every external caller (`cn_runtime_contract_test.ml`, `cn_activation_test.ml`, `cn_runtime_contract.ml`'s own IO-side closures) compiles unchanged because the re-exported type IS the canonical type. The schema/fixture audit (§2.5b check 6 from v3.37.0) was performed inline and came out clean with zero fixture edits required — exactly what type-equality is designed for.
  - **γ regressed A → B+.** **Two review rounds** (at the ≤2 ceiling for code PRs, but with a mechanical finding that shouldn't have reached the reviewer). **One finding** (R1 F1), **100% mechanical ratio** (over the 20% threshold by 80 percentage points). The failure: `test/lib/dune` defined a library named `cn_contract_test`, which collided with the pre-existing `cn_contract_test` in `test/cmd/dune:99` (the I2 protocol-contract invariant tests, completely unrelated). Dune rejects duplicate library names workspace-wide at build time; CI went red on first push. The reviewer reported F1 as a mechanical finding; I renamed the new library to `cn_contract_pure_test` (and the module/file accordingly) in one fix commit; R2 was clean APPROVED. The root cause was not skill-coverage failure — the §2.5b 6-check gate held every semantic check it knew about — but the absence of a workspace-global library-name-uniqueness check. No local OCaml toolchain in the authoring sandbox meant `dune build` was not available to catch it pre-push. Seventh cycle on that environmental constraint.
  - **Level L5.** The cycle was a pure-type extraction — records + variants moved between modules with no new boundary, no new runtime surface, no new primitive introduced. Same L5 label as v3.38.0 slice 1. Move 2 as a whole will be L7 cumulatively when all four slices ship (the friction class "pure types live behind an IO module" becomes structurally impossible), but each individual slice is L5.
- **Coherence contract closed?** **Yes.** All 10 ACs (9 from issue #194 + implementer-added AC10 for the `activation_entry` transitive extraction) met as written. Zero AC deferrals carried into this assessment. Move 2 is now 2/4 slices shipped. The `Cn_activation` dependency was handled cleanly via option (b) per the issue's choice — extract `activation_entry` into `cn_contract.ml`, have `cn_activation.ml` re-export via type-equality — and the cycle established a small principle that proved useful in slice 3: "the consumer analysis decides which types move, not the syntactic purity."

### 2. Encoding Lag

| Issue | Title | Type | Design | Impl | Lag |
|-------|-------|------|--------|------|-----|
| #194 | #182 Move 2 slice 2 — runtime contract types into `src/lib/` | feature | CORE-REFACTOR.md §7 + v3.38.0 status block | **shipped** (#195 → `7f2d4b9`) | none |
| #196 | #182 Move 2 slice 3 — workflow IR into `src/lib/` | feature | CORE-REFACTOR.md §7 + v3.39.0 status block | **shipped** (#197 → `36539d3`, in the v3.40.0 window) | none — the next slice was already in flight by the time this assessment was written |
| — | #182 Move 2 slice 4 — activation evaluator from `cn_activation.ml` | feature | CORE-REFACTOR.md §7 status block | not started — **next MCA** | new |
| #198 | §2.5b checks 7 + 8 (workspace library-name uniqueness + CI-green-before-review) | process | §9.1 learning from this cycle's F1 + v3.40.0 F1 | **shipped** (→ `f3d90b0`) — see §3 below for the stacking narrative | none |
| #193 | `llm` step execution + binding substitution | feature | needs design (PLAN-174 §Risk) | not started | growing (carried from v3.36.0 — now 4 cycles) |
| #175 | CTB → orchestrator IR compiler | feature | CTB-v4.0.0-VISION.md | blocked on `llm` execution (#193) | growing |
| #190 | Agent network — cnos as protocol for peer agents | feature | `docs/alpha/vision/AGENT-NETWORK.md` (vision-tier) | not started | new (pre-converged; not counted in growing) |
| #180 | Beta package-system doc (Move 3) | feature | identified | not started | growing (carried from v3.38.0 post-release) |
| #186 | Package restructuring | feature | design thread | not started | growing (carried from v3.38.0 post-release) |
| #162 | Modular CLI commands (broader umbrella) | feature | Move 1 shipped (#184) | partial | low |
| #168 | L8 candidate tracking | process | observation only | observation only | low |
| #154 / #153 / #100 / #94 | Thread event model P1/P2, memory faculty, cn cdd mechanize | features | various | not started | stale (long-tail) |

**MCI/MCA balance:** **balanced**, though the v3.38.0 post-release had declared **freeze MCI** on the basis of 3+ growing-lag issues (`llm`, `#175`, `#186`, `#180`). That freeze was honored during v3.39.0 — no new design docs landed except the vision-tier `docs/alpha/vision/AGENT-NETWORK.md` (#190) which is pre-converged and doesn't count against the MCI budget. The freeze remains in effect through v3.40.0's next-MCA (slice 4) at minimum.

**Rationale:** The growing-count is 4 (`llm` execution, #175, #186, #180) which meets the ≥3 freeze trigger. Move 2's remaining slice (#4, activation evaluator) is queued as the next-MCA (counted as `new`, not `growing`). The v3.38.0 freeze declaration stands — no new design work until the growing backlog shrinks, which will happen naturally as Move 2 slice 4 closes the core refactor and either `llm` or #180 gets picked up.

### 3. Process Learning

**What went wrong:**

1. **F1 mechanical finding reached the reviewer — library-name collision.** `test/lib/dune` defined `(library (name cn_contract_test) ...)` which collided with the pre-existing `cn_contract_test` library in `test/cmd/dune:99` (protocol-contract I2 invariant tests, unrelated domain). Dune rejects duplicate library names workspace-wide at build time; CI went red on first push. The reviewer reported it as R1 F1. The fix was mechanical: rename the new library + module + file to `cn_contract_pure_test`, one commit. R2 was clean.
2. **The §2.5b 6-check gate as it existed at cycle-start did not cover this failure class.** The 6 checks were: rebase, self-coherence present, CDD trace in PR body, tests reference ACs, known debt explicit, schema/shape fixture audit. None of them said "grep the workspace for existing `(name X)` stanzas before committing a new library." The gap was real and discoverable by post-hoc analysis but not mechanized pre-PR.
3. **Seventh cycle on the no-local-OCaml environmental constraint.** Same as v3.33.0 through v3.38.0. `dune build` is not available in the authoring sandbox; CI is the first compilation oracle on every cycle. That constraint cannot be fixed at the skill level — the real correctives are either provisioning OCaml in the sandbox or writing a preflight test runner, both out of cycle scope. But its downstream impact (mechanical failures reaching the reviewer) is what the §2.5b gate is meant to absorb. For this cycle specifically, the gate absorbed 6 classes but not the 7th (library-name collision), so 1 mechanical failure leaked to review.

**What went right:**

1. **The type-equality re-export pattern held for the second consecutive cycle.** Slice 1 (v3.38.0) proved it on `cn_package.ml`; slice 2 proved it scales to a larger module (`cn_runtime_contract.ml`, 567 LOC, 11 types + 1 variant, with a chained transitive dependency via `activation_entry`). The `Cn_runtime_contract.*` types the test fixtures construct as record literals (e.g. `let lock : Cn_runtime_contract.lockfile_entry list = [ ... ]`) continued to compile without edits because the re-exported type is OCaml-identical to the canonical one.
2. **Tests-first discipline held.** 13 expect-tests in `test/lib/cn_contract_test.ml` (later renamed `cn_contract_pure_test.ml` per the F1 fix) were authored in Stage A before the production module in Stage B. Each test references the API as I designed it; Stage B made them pass by definition.
3. **§2.5b check 6 (schema/fixture audit, added in v3.37.0) correctly identified itself as N/A.** No schema change occurred (field names, types, ordering all preserved byte-for-byte), so no fixture edits were needed. Correctly identifying when a check is N/A is the check working as intended.
4. **R1 → R2 fix-loop was tight.** One fix commit renamed the library + module + file; R2 converged clean at APPROVED. No further findings surfaced. Two rounds is at target for code PRs, though the mechanical root cause of the R1 finding was exactly what the §2.5b gate is supposed to prevent.
5. **Option-(b) decision on `activation_entry` transitive extraction** established a principle that paid dividends in slice 3: the extraction decision is driven by consumer analysis, not by syntactic purity. In slice 2, `activation_entry` moved into `cn_contract.ml` because `cognition.activation_index : activation_entry list` is a pure consumer of it. In slice 3, the symmetric decision went the other way: `load_outcome`/`installed`/`outcome` stayed in `cn_workflow.ml` because no pure consumer exists for them. Same principle, different answer, both structurally correct.

**Skill patches (immediate output, per CDD §12a):**

**Retroactive §12a — the corrective shipped between the feature merge and this assessment.** The F1 failure class ("library name collision reached CI red because no workspace-global uniqueness check existed in §2.5b") was also about to repeat in the v3.40.0 cycle that followed immediately. In the v3.40.0 work, I applied the discipline manually (pre-bootstrap grep for `(name cn_workflow_ir*)` before committing) and flagged the stashed skill patch for check 7 as pending the v3.39.0 post-release PR. Then during v3.40.0's review rounds a second mechanical failure class surfaced (F1 ppx_expect stderr mismatch), and the user proposed check 8 (CI-green-before-review) as the downstream-impact corrective. Both checks landed together via **PR #198** (`f3d90b0` on main) as a standalone skill-patch PR, written in parallel with the v3.40.0 fix commits and shipped ahead of this assessment.

**This means the §12a patch that would normally accompany this v3.39.0 assessment commit is already on main.** The corrective is real, it's shipped, and it closes the exact failure class this cycle's F1 exemplified. The assessment doesn't need to re-ship it — it cites it as closed debt. Per CDD §10.1 ("skill patches identified by cycle iteration must be executed within the same cycle"), there's a subtlety here: the patch DID land within the same CDD lifecycle by shipping ahead of the assessment doc. The ordering is unusual but the closure is valid — cycle iteration's requirement is that the corrective be landed, not that it be landed after the assessment.

**Active skill re-evaluation:**

| Finding | Loaded skill | Would skill have prevented it? | Disposition |
|---------|-------------|-------------------------------|-------------|
| R1 F1 (`test/lib/dune` library-name collision) | cdd (§2.5b 6-check gate at cycle-start), eng/ocaml, eng/testing | **No** — the 6-check gate did not include workspace-global library-name uniqueness; the check was added retroactively as §2.5b check 7 via PR #198 | **Skill patched** via PR #198 (already shipped) |

One skill gap, one patch, already landed. Zero application gaps (the agent followed §2.5b as written; the gap was in what §2.5b covered, not how it was applied).

**CDD improvement disposition:** **Patch landed (via #198).** The §12a requirement is satisfied by the already-shipped skill patch — check 7 directly targets the F1 failure class, with the precedent sentence in the PR body citing this cycle's #195 F1 as the motivating case.

### 4. Review Quality

**PRs this cycle:** 1 (#195)
**Review rounds:** **2** (R1 REQUEST CHANGES F1 mechanical → R2 APPROVED zero findings) — at the ≤2 target ceiling for code PRs
**Superseded PRs:** 0 — within the 0 target
**Finding breakdown:**

| # | Finding | Round | Severity | Type |
|---|---------|-------|----------|------|
| F1 | `test/lib/dune` library name `cn_contract_test` collided with pre-existing `cn_contract_test` in `test/cmd/dune:99`; dune rejected duplicate at build time | 1 | **D** | mechanical |

**Mechanical ratio:** 1 / 1 = **100%** — over the 20% threshold by 80 percentage points.

**Action (per skill §4 rule "filed and referenced, not just noted"):** **Skill patch shipped via PR #198** — §2.5b check 7 (workspace-global library-name uniqueness) directly targets this failure class. See §3 above for the stacking narrative. The corrective is landed; the failure class is structurally closed for future cycles.

### 4a. CDD Self-Coherence

- **CDD α (artifact integrity): 4/4.** All required cycle artifacts present in `docs/gamma/cdd/3.39.0/`: README, SELF-COHERENCE (α A, β A, γ A−), GATE, and now POST-RELEASE-ASSESSMENT (this file). CDD Trace tables in both the README and the PR #195 body, populated through step 9.
- **CDD β (surface agreement): 4/4.** End-to-end agreement between: CORE-REFACTOR.md §7 design + v3.39.0 status block, the `src/lib/cn_contract.ml` canonical types, the `src/cmd/cn_runtime_contract.ml` re-exports, the `src/cmd/cn_activation.ml` `activation_entry` chained re-export, the test coverage in `cn_contract_pure_test.ml` (after the rename), and every external caller verified by grep. Zero schema drift, zero stale references.
- **CDD γ (cycle economics): 2/4.** Two review rounds (at the ≤2 ceiling — not over, but a mechanical finding that should have been caught pre-review). 100% mechanical ratio (over the 20% threshold by 80 percentage points). 7th cycle on the no-local-OCaml environmental constraint. Immediate outputs (this assessment + stacking with v3.40.0) executed in this commit; deferred outputs committed concretely in §7. The §12a skill patch (PR #198) is already landed.
- **Weakest axis:** γ.
- **Action:** **patch landed via #198** — the corrective for the γ regression's root cause (missing workspace library-name check) shipped ahead of this assessment. No further action needed in this assessment commit beyond citing #198 as closed debt.

### 4b. §9.1 Cycle Iteration

Per CDD §9.1, this section is required because multiple triggers fired (mechanical ratio over threshold + loaded skill failed to prevent a finding + soft environmental constraint).

**Triggers fired:**

| Trigger | Fired | Evidence |
|---------|-------|----------|
| Review rounds > 2 | No (exactly 2) | R1 F1 → R2 APPROVED |
| Mechanical ratio > 20% | **Yes** (100%) | F1 was the only finding and it was mechanical |
| Avoidable tooling failure | **Yes (soft, environmental)** | No OCaml toolchain in the authoring sandbox; 7th consecutive cycle; same constraint as v3.33.0 through v3.38.0 |
| Loaded skill failed to prevent a finding | **Yes** | §2.5b 6-check gate at cycle-start covered rebase, self-coherence, CDD trace, test-AC reference, known debt, and schema/fixture audit — but not workspace-global library-name uniqueness. The gap is real; patched retroactively as check 7 via PR #198 |

**Friction log:** The cycle itself was structurally clean through artifact creation (README, SELF-COHERENCE, GATE, bootstrap, Stage A tests, Stage B code, Stage C re-exports, Stage D dune wiring, Stage E caller grep, Stage F CORE-REFACTOR update, Stage G self-coherence + gate, Stage H §2.5b 6-check + commit + push + PR). The §2.5b gate ran all 6 checks green pre-commit. The failure surfaced on CI immediately on first push: `dune build` rejected the duplicate library name. The fix was trivial (rename to `cn_contract_pure_test`, rename the test file to match, update `test/lib/dune`). One fix commit, R2 clean APPROVED. Total elapsed friction: ~20 minutes from R1 posting to R2 merge.

**Root cause:** skill gap (the §2.5b gate's coverage was incomplete for workspace-global namespace collisions) compounded by environmental constraint (no local OCaml to run `dune build` pre-push). Neither cause alone would have produced the finding — if the skill had covered the check, the grep would have caught it before commit; if local OCaml had been available, `dune build` would have caught it before push. Both needed to fail simultaneously for the failure to reach the reviewer.

**Skill impact:** §2.5b check 7 (workspace-global library-name uniqueness). **Patched in PR #198** as an immediate output, landed ahead of this assessment. The skill source is `packages/cnos.core/skills/cdd/SKILL.md` §2.5b (build-sync copy from `src/agent/skills/cdd/SKILL.md`); the canonical spec is `docs/gamma/cdd/CDD.md` §5.3 row 7a (authority-sync); both updated in the same #198 commit.

**MCA:** **PR #198 (shipped)** — the check-7 addition to §2.5b is a mechanical gate that structurally prevents the failure class. Future cycles running the gate will `grep -rn "(name X)" src/ test/` before committing any new library stanza; collisions will be caught pre-commit regardless of local toolchain availability.

**Cycle level:** **L5.** Per ENGINEERING-LEVELS.md §6 "lowest miss": L5 requires local correctness — the code must compile, tests must pass, patterns must be followed. F1 was a compile failure that reached review. Cycle caps at L5. Would have been L6 (cross-surface structural change with clean execution) absent F1; the mechanical failure demotes it one level. The rule is strict by design — L5 must be earned cleanly, not graded on a curve.

**Justification (one line):** Clean feature extraction + clean review-convergence on R2, but a compile-time mechanical failure reached review due to §2.5b skill gap + environmental constraint simultaneously.

### 5. Production Verification

**Scenario:** A consumer hub upgraded to cnos.core 3.39.0 sees **zero behavioral change** in everything that touches `Cn_runtime_contract.*` types (render_markdown output, to_json serialization, gather behavior, classify_zones), because the cycle was a pure-type extraction with caller-compatible re-exports. Simultaneously, a structural property is now true that wasn't before: the 11 runtime-contract record types + `activation_entry` live in `src/lib/cn_contract.ml` and are import-callable from any module without dragging in the `gather`/`write`/`classify_zones` IO surface.

**Before this release (v3.38.0):**
- The 11 pure runtime-contract types lived in `src/cmd/cn_runtime_contract.ml` alongside `gather`, `write`, `render_markdown`, `to_json`, `classify_zones`, and the filesystem walks.
- `activation_entry` lived in `src/cmd/cn_activation.ml` alongside `build_index`, the frontmatter parser, and the SKILL.md readers.
- Any cross-module that wanted to reason about a `package_info` record or match on a `zone` variant had to depend on `Cn_runtime_contract`, which transitively pulled in the entire IO surface.

**After this release (v3.39.0):**
- `src/lib/cn_contract.ml` owns the canonical 11 types + `activation_entry` + `zone_to_string` helper. Imports only stdlib (+ `Cn_json` transitively via the `cn_lib` library).
- `src/cmd/cn_runtime_contract.ml` re-exports each type via OCaml type-equality + delegates `zone_to_string`; every IO function (`gather`, `write`, `render_markdown`, `to_json`, `classify_zones`, `list_md_relative`, `list_skill_overrides`, `extensions_from_registry`, `build_command_registry`, `build_orchestrator_registry`) stays unchanged.
- `src/cmd/cn_activation.ml` has `activation_entry` as a chained type-equality re-export from `Cn_contract`; the IO-side (`build_index`, frontmatter parser, `list_declared_skills`) is unchanged and is the slice-4 candidate.

**How to verify:**

1. **Structural / mechanical (executable in CI, already passed on the merge commit `7f2d4b9`):**
   ```
   grep -n "Cn_ffi\|Cn_executor\|Cn_cmd\|Unix\|Sys\." src/lib/cn_contract.ml
   ```
   Expect: **zero matches.** Verifies the discipline boundary by grep.

2. **Compile-time type identity (executable in CI, already passed):**
   ```
   dune build src/cli/cn.exe
   dune runtest test/lib/cn_contract_pure_test.exe
   dune runtest test/cmd/cn_runtime_contract_test.exe
   dune runtest test/cmd/cn_activation_test.exe
   ```
   Expect: all green. Verifies that the `type t = Cn_contract.t = { ... }` re-export + the chained `Cn_activation.activation_entry = Cn_contract.activation_entry` re-export keep every caller-side pattern match and record literal compiling against the canonical type.

3. **Runtime parity on a real hub (deferred):**
   ```
   cn doctor                # expect: same output as v3.38.0
   cn status                # expect: runtime contract JSON unchanged (cn.runtime_contract.v2 schema stable)
   ```
   Expect: zero behavioral diff against v3.38.0. The IO surface is byte-for-byte unchanged. Deferred to the next sigma hub upgrade.

**Result:** **structural + compile + type-identity verifications PASS on the merge commit** (all CI checks green after the R2 fix). **Runtime parity on a real hub: deferred** — same pattern as v3.38.0. Not blocking this assessment because the cycle is a pure-extraction; any behavioral diff would be a compile-time failure, not a runtime surprise.

### 6. CDD Closeout

| Step | Artifact | Skills loaded | Decision |
|------|----------|---------------|----------|
| 11 Observe | this assessment + PR #195 review thread (R1 F1 mechanical → R2 APPROVED) + CI state on the merge commit (all green) + the merged commit `7f2d4b9` on `main` + the follow-on v3.40.0 cycle already in flight (#197) | post-release | Cycle coherent end-to-end. α held A, β held A, γ regressed A → B+ on the F1 mechanical finding. Shipped state matches contract (all 10 ACs met, zero deferrals). |
| 12 Assess | `docs/gamma/cdd/3.39.0/POST-RELEASE-ASSESSMENT.md` (this file) | post-release | Scoring C_Σ A− · α A · β A · γ B+ · L5. §9.1 cycle iteration section present (3 triggers fired — mechanical ratio, environmental, skill gap). Explicit retroactive §12a disposition citing PR #198 as landed corrective. |
| 12a Skill patch | **PR #198 (already shipped)** — §2.5b check 7 (workspace-global library-name uniqueness) across `src/agent/skills/cdd/SKILL.md`, `packages/cnos.core/skills/cdd/SKILL.md` (build-sync), and `docs/gamma/cdd/CDD.md` §5.3 row 7a (authority-sync) | post-release, cdd | Patch landed ahead of this assessment via a standalone skill-patch PR. The ordering is unusual but the closure is valid — the corrective is real, shipped, and cited by the PR body as targeting this cycle's #195 F1 failure class. |
| 13 Close | this assessment + stacked v3.40.0 assessment + next-MCA commitment (slice 4 activation evaluator) + MCI freeze continued | post-release | Cycle closed. Immediate outputs executed in this commit. Deferred outputs committed concretely in §7. |

### 7. Next Move

**Next MCA:** **#182 Move 2 slice 4 — activation evaluator + frontmatter parser + `build_index` from `cn_activation.ml`**
**Issue:** #182 umbrella; sub-task to be filed (or the next implementer can reference slice 2/3 bootstrap READMEs as pattern precedent)
**Owner:** sigma (delegated via CDD §2.5a as usual)
**Branch:** pending creation (e.g. `claude/182-move2-activation-evaluator`)
**First AC:** Extract the pure helpers from `src/cmd/cn_activation.ml` into `src/lib/cn_activation_ir.ml` (or similar — implementer's call on naming; check 7 applies). Candidates for the pure side: the frontmatter parser (`parse_frontmatter`, `extract_block`, `split_lines`, the `frontmatter` record type), `manifest_skill_ids`, and any additional pure helpers. Candidates for the IO side that stay: `build_index` (reads manifests), `list_declared_skills` (disk walk), `check_frontmatter_file` (reads files). `activation_entry` already moved in slice 2 and lives in `Cn_contract` — no change to that.
**MCI frozen until shipped?** **Yes.** The freeze declared in v3.38.0 post-release stands. Growing-count is 4 (`llm`, #175, #186, #180). Slice 4 is the natural closing move for Move 2 — shipping it closes the refactor and removes one of the blockers for re-evaluating the freeze. If after slice 4 the growing count is still ≥3, the freeze continues.
**Rationale:** Last slice of Move 2. Smallest source module of the four (~260 LOC vs 130 / 567 / 655 for slices 1–3). Smallest pure surface area. The pattern is now fully proven across three cycles; slice 4 is mechanical application of the proven extraction pattern. With slice 4 shipped, Move 2 is complete and the core refactor umbrella (#182) can be reassessed for Move 3 (retire beta package doc, #180) or post-closure.

**Immediate outputs (executed in this commit):**

1. **`docs/gamma/cdd/3.39.0/POST-RELEASE-ASSESSMENT.md`** — this file.
2. **Stacked with `docs/gamma/cdd/3.40.0/POST-RELEASE-ASSESSMENT.md`** — written in the same commit / same PR because both cycles' §9.1 sections point to the same corrective (#198) and writing them together avoids duplicating the §12a narrative. Both files land in the same branch and the same PR.
3. **No new skill patch in this commit** — #198 already shipped the corrective. This assessment is an observation + closure doc, not a change-the-system doc.
4. **CHANGELOG TSC row: pending (separate release-commit track).** The release commit that bumps VERSION to 3.39.0 and adds the CHANGELOG row is a separate track per the v3.38.0 precedent (release commit `3e66b04` was cut independently of the post-release commit `38ec1c2`). This assessment will be cited by the CHANGELOG row when it's eventually written.

**Deferred outputs (committed concretely):**

| # | Output | Trigger / next action |
|---|--------|----------------------|
| 1 | **Move 2 slice 4** — activation evaluator extraction | Next MCA above. Cycle starts when slice 4 is picked up. |
| 2 | **Release commit for v3.39.0** — VERSION bump + CHANGELOG row + packages/index.json + packages/cnos.*/cn.package.json stamps | Separate track; can be cut at any time after this assessment lands. |
| 3 | **`llm` step execution + binding substitution (#193)** | Carried from v3.36.0; now 4 cycles growing. Closes the #174 deferral. Sequenced after Move 2 closes at slice 4. |
| 4 | **#175 CTB → orchestrator IR compiler** | Blocked on item 3. |
| 5 | **#180 beta package-system doc retirement (Move 3)** | Carried from v3.38.0 post-release; growing. Can be picked up any time after Move 2 closes. |
| 6 | **#186 package restructuring** | Carried from v3.38.0 post-release; growing. |
| 7 | **#190 agent network vision** | Pre-converged; becomes a real cycle when a converged design doc lands. |
| 8 | **Tooling gap — no local OCaml in the authoring sandbox** | Carried from v3.33.0 through v3.38.0; now 7 cycles. Environmental. The §2.5b check 8 added via #198 absorbs the downstream impact (mechanical failures reaching reviewers) even though the environmental constraint itself remains. |
| 9 | **MCI freeze re-evaluation after slice 4 ships** | The freeze declared in v3.38.0 post-release stands through slice 4. Re-evaluate after slice 4 based on whether growing-count drops below 3. |

**Closure evidence (CDD §10):**

- **Immediate outputs executed:** **yes**
  - This `POST-RELEASE-ASSESSMENT.md` (committed in this PR)
  - Stacked v3.40.0 assessment in the same PR
  - §12a skill patch already landed via PR #198 (cited as closed debt; does not re-ship)
- **Deferred outputs committed:** **yes**
  - 9 entries above with scope + trigger condition + ownership note
  - Item 1 (slice 4) is the only one without an issue number yet — to be filed when the cycle is picked up, per the pattern from slices 2 and 3 (issues #194, #196 were filed right before each cycle started)
