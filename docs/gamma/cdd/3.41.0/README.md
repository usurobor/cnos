## CDD Bootstrap — v3.41.0 (#182 Move 2 slice 4 — **final slice**)

**Issue:** #201 — #182 Move 2 slice 4: extract activation frontmatter parser + types into `src/lib/`
**Cycle scope:** Fourth and **final** slice of Move 2. After this cycle, every pure type + parser in the codebase lives in `src/lib/` and every IO function lives in `src/cmd/`. Closes the core refactor extraction phase.
**Branch:** `claude/182-move2-activation`
**Design:** `docs/alpha/agent-runtime/CORE-REFACTOR.md` §7 "Move 2 — Pure-model gravity into `src/lib/`" + the v3.38.0 / v3.39.0 / v3.40.0 status blocks (this cycle adds the final status block: **Move 2 complete**)
**Parent sequencing:** v3.40.0 post-release §7 named slice 4 (activation evaluator) as the next MCA, referencing `src/cmd/cn_activation.ml` as the source module. Issue #201 was filed with the full spec. This is the first cycle running end-to-end under the new §1.4 role governance (author = me, reviewer/releaser/assessor = user) + §2.5b checks 7 + 8 as formal gate items (not manual discipline).
**Mode:** MCA
**Level:** L5 — pure-type extraction with no new boundary, same label as slices 1–3. But Move 2 *as a whole* ships as L7 once this slice lands: the friction class "pure types live behind an IO module" becomes structurally impossible everywhere in `src/cmd/`, and the Go kernel rewrite (#192) gets its boundary contract.
**Active skills loaded (and read) before code:** cdd (§1.4 Roles + §2.5b 8-check gate including the new checks 7 + 8), eng/ocaml (§3.1 no bare `with _ ->`, §2.1 disambiguate at definition), eng/testing (ppx_expect per extracted module)

### Gap

`src/cmd/cn_activation.ml` (288 lines) mixes 12 pure surface items with 3 IO functions. The pure surface:

- `frontmatter` record type (3 fields: `fm_name`, `fm_description`, `fm_triggers`)
- `empty_frontmatter` constant
- `split_lines`, `extract_block`, `parse_key_value`, `is_list_item`, `list_item_value` (5 line-level YAML-subset helpers)
- `parse_frontmatter` (the main parser, ~45 lines; uses `Printf.eprintf` for malformed-line warnings — stderr precedent set in v3.40.0 slice 3)
- `manifest_skill_ids` (reads a parsed `cn.package.json` and returns the declared skill IDs; also uses `Printf.eprintf` for malformed entries)
- `issue_kind` variant (3 constructors: `Missing_skill`, `Empty_triggers`, `Trigger_conflict`) — **activation-specific, distinct from `Cn_workflow_ir.issue_kind` introduced in slice 3**
- `issue` record (fields `{ kind : issue_kind; message : string }` — note field name `kind`, not `issue_kind` like the workflow record)
- `issue_kind_label` (3-case pattern match returning `"missing" | "empty" | "conflict"`)

All 12 items depend only on stdlib + `Cn_json` (via the `cn_lib` library). The issue's spec also allows `Cn_contract` as a dependency (since it's in `src/lib/`), but the extraction doesn't actually need it — the `activation_entry` re-export chain from slice 2 stays in `cn_activation.ml` as the IO-side owner of that type reference.

The IO surface that stays in `cn_activation.ml`:
- `activation_entry` re-export from `Cn_contract` (from slice 2, unchanged)
- `read_skill_frontmatter` (uses `Cn_ffi.Fs.exists`, `Cn_ffi.Fs.read`)
- `build_index` (uses `Cn_assets.list_installed_packages`, `Cn_ffi.Path.join`, `Cn_ffi.Fs.exists`, `Cn_ffi.Fs.read`, plus the pure parser + `manifest_skill_ids`)
- `validate` (same IO surface as `build_index` plus the `issue` record construction)

Same inverted-abstraction problem as slices 1–3: the pure model sits inside the IO wrapper. Any consumer of `frontmatter`, `issue`, or `issue_kind_label` has to depend on `Cn_activation`, which transitively pulls in `Cn_assets`, `Cn_ffi`, and the `build_index` walk.

### What fails if skipped

- **#192 (Go kernel rewrite) stays blocked.** The Go rewrite's boundary contract requires every pure type + parser to live in `src/lib/`. Slices 1–3 covered package types, runtime contract types, and workflow IR. Slice 4 is the last source module with pure helpers still living behind IO wrappers. Skip it and the Go rewrite has 3 of 4 pure modules + one that's still mixed.
- **Move 2 stays at 3/4 slices forever.** There is no natural milestone for the core refactor if the last slice isn't landed. CORE-REFACTOR.md §7 would read as an incomplete move indefinitely.
- **The doctor validation surface stays coupled to IO.** `Cn_doctor` currently consumes `Cn_activation.issue`, `Cn_activation.issue_kind_label`, and `Cn_activation.Trigger_conflict` directly. Without the extraction, any future doctor refactor has to wrestle with the pure/IO mix.

### Scope for this cycle

**The last Move 2 slice.** After this cycle merges, Move 2 is complete. The CORE-REFACTOR.md §7 status block grows by one entry ("v3.41.0: fourth slice shipped — Move 2 complete"), and the "remaining candidates" list becomes empty.

This cycle does NOT:
- Move any IO function (`read_skill_frontmatter`, `build_index`, `validate` all stay per AC4)
- Touch the `activation_entry` re-export (already owned by `Cn_contract` from slice 2; `cn_activation.ml` retains the one-line `type activation_entry = Cn_contract.activation_entry = { ... }` re-export)
- Refactor the `Printf.eprintf` calls in `parse_frontmatter` or `manifest_skill_ids` — stderr precedent is documented in CORE-REFACTOR.md §7 (added in fix commit `7844a34` during the v3.40.0 cycle). The warnings move as-is.
- Refactor the two distinct `issue_kind` types to share a common base — they're genuinely different validation categories (workflow has 7, activation has 3) and the field naming (`issue_kind` vs `kind`) is deliberately preserved
- Create `src/core/` — explicit no per CORE-REFACTOR.md §7

### Acceptance Criteria (matching #201 spec)

- [ ] **AC1** New `src/lib/cn_frontmatter.ml` contains the pure surface:
  - Types: `frontmatter`, `issue_kind`, `issue`
  - Constants: `empty_frontmatter`
  - Parsers: `parse_frontmatter`, `extract_block`, `split_lines`, `parse_key_value`, `is_list_item`, `list_item_value`
  - Helpers: `manifest_skill_ids`, `issue_kind_label`
- [ ] **AC2** Purity discipline: only stdlib + `Cn_json`. No `Cn_ffi`, `Cn_executor`, `Cn_cmd`, `Cn_contract` (allowed by issue but not actually needed this cycle), `Unix`, `Sys`, filesystem, git, process, HTTP, or LLM code. Verified by grep. (`Printf.eprintf` for stderr diagnostics is permitted per the CORE-REFACTOR.md §7 discipline clarification added in v3.40.0 — not an IO side-effect in the forbidden sense.)
- [ ] **AC3** `cn_activation.ml` re-exports all 3 types via OCaml type-equality (`type frontmatter = Cn_frontmatter.frontmatter = { ... }` + variants/records for `issue_kind`, `issue`) and delegates all 8 pure functions via one-line `let` bindings. Zero caller migration.
- [ ] **AC4** `cn_activation.ml` retains all IO functions unchanged: `read_skill_frontmatter`, `build_index`, `validate`. `activation_entry` re-export from `Cn_contract` stays untouched.
- [ ] **AC5** `test/lib/cn_frontmatter_test.ml` covers the pure module with ppx_expect tests: frontmatter parsing happy path, missing markers, empty block, block-list triggers, inline-list warning suppression, `manifest_skill_ids` happy + missing-field + malformed, `issue_kind_label` exhaustive over 3 variants, `issue` record construction + field-read.
- [ ] **AC6** Dune wiring: `cn_frontmatter` registered in `src/lib/dune` modules list; `cn_frontmatter_test` library registered in `test/lib/dune`. §2.5b check 7 pre-verified: `grep -rn "(name cn_frontmatter" src/ test/` returned zero collisions (re-verifying at Stage H).
- [ ] **AC7** Existing tests pass unchanged. Verified external caller sites:
  - `src/cmd/cn_doctor.ml` (4 refs — `issue`, `Trigger_conflict`, `issue_kind_label`, `i.kind` field access): works via type-equality re-export
  - `test/cmd/cn_activation_test.ml` (5 `parse_frontmatter` calls + 3 `issue` annotations + 6 `issue_kind` constructor matches): works via re-export + delegation
- [ ] **AC8** `docs/alpha/agent-runtime/CORE-REFACTOR.md` §7 Move 2 status block updated: **Move 2 complete (0 remaining slices)**. The status block grows a v3.41.0 entry; the "remaining candidates" line becomes "(none — Move 2 complete)."

### Non-goals (this cycle)

- Moving `read_skill_frontmatter`, `build_index`, or `validate` — these are IO functions that stay in `src/cmd/` per AC4.
- Changing the `activation_entry` re-export chain — it already lives in `Cn_contract` from slice 2.
- Refactoring the `Printf.eprintf` calls — stderr precedent is documented and the warnings move as-is.
- Unifying `Cn_workflow_ir.issue_kind` and `Cn_frontmatter.issue_kind` — genuinely different validation categories; the visual similarity is coincidence, not duplication.
- Starting the Go kernel rewrite (#192) — that's the next-next-MCA, unblocked by this cycle but not started in it.
- Declaring "Move 2 complete" celebratory wording in places other than CORE-REFACTOR.md §7 status block — the milestone is real but the narrative belongs in the post-release assessment (written by the releasing agent per §1.4), not in the feature PR.

### Plan

| Stage | Scope | ACs |
|-------|-------|-----|
| A | Tests first: `test/lib/cn_frontmatter_test.ml` with expect-tests for types, parser happy/sad paths, `manifest_skill_ids` variants, `issue_kind_label` exhaustive, `issue` record construction | AC5 |
| B | Create `src/lib/cn_frontmatter.ml` with the 12 surface items + discipline comment (no IO beyond stderr diagnostics) | AC1, AC2 |
| C | Rewrite `src/cmd/cn_activation.ml`: delete the 12 moved surface items, replace with type-equality re-exports (3 types) + delegating let-bindings (1 constant + 8 functions); retain the 3 IO functions + the `activation_entry` re-export from slice 2 unchanged | AC3, AC4 |
| D | Register `cn_frontmatter` in `src/lib/dune` modules list; register `cn_frontmatter_test` library in `test/lib/dune`. Re-verify §2.5b check 7 (workspace library-name uniqueness grep) | AC6 |
| E | Verify no caller churn: grep for every external reference to `Cn_activation.{moved surface}` and confirm re-exports cover each site | AC7 |
| F | Update `docs/alpha/agent-runtime/CORE-REFACTOR.md` §7 Move 2 status: v3.41.0 block added, naming Move 2 as complete and referencing #192 as the now-unblocked next track | AC8 |
| G | Self-coherence report + GATE | — |
| H | §2.5b 8-check pre-review gate + manual check-7 re-verification + **open PR as draft** + wait for CI green + mark ready-for-review (first cycle running check 8 as a formal gate item) | — |

### Impact Graph

**New files:**
- `src/lib/cn_frontmatter.ml` (pure frontmatter parser + validation types)
- `test/lib/cn_frontmatter_test.ml` (ppx_expect tests)

**Touched modules:**
- `src/cmd/cn_activation.ml` — delete 12 moved surface items; add 3 type re-exports + 1 constant delegation + 8 function delegations; retain `read_skill_frontmatter`, `build_index`, `validate` + the `activation_entry` re-export from slice 2
- `src/lib/dune` — register `cn_frontmatter` module
- `test/lib/dune` — register `cn_frontmatter_test` library

**Touched docs:**
- `docs/alpha/agent-runtime/CORE-REFACTOR.md` — §7 Move 2 status block (v3.41.0 entry: Move 2 complete)

**Compatibility-preserved (verified by grep, not changed):**
- `src/cmd/cn_doctor.ml` — 4 reference sites (`Cn_activation.issue`, `Cn_activation.Trigger_conflict`, `Cn_activation.issue_kind_label`, `i.kind` field access). All resolve through type-equality re-export of `issue` + `issue_kind` and the delegating let-binding for `issue_kind_label`.
- `test/cmd/cn_activation_test.ml` — 14 reference sites across 3 categories: (a) 5 `parse_frontmatter` calls delegated via let-binding, (b) 3 `Cn_activation.issue` type annotations via type-equality re-export, (c) 6 `issue_kind` constructor pattern matches (`Missing_skill`, `Empty_triggers`, `Trigger_conflict` × 2 each) re-exposed through the variant type-equality re-export.

### CDD Trace

| Step | Artifact | Skills loaded | Decision |
|------|----------|---------------|----------|
| 0 Observe | v3.40.0 post-release §7 naming slice 4 as next MCA + #201 spec + `cn_activation.ml` current shape + caller grep across `src/cmd/` and `test/cmd/` + v3.40.0 release tag landed + §1.4 Roles governance rule added to CDD.md | cdd, post-release | Next MCA per v3.40.0 assessment is slice 4; #201 filed with full spec; first cycle running under formalized §2.5b checks 7 + 8 + §1.4 roles |
| 1 Select | #201 (#182 Move 2 slice 4 — final slice) | cdd | L5 structural subtraction, smallest Move 2 source module (288 LOC vs 130 / 567 / 655 for slices 1–3); closes Move 2 |
| 2 Branch | `claude/182-move2-activation` | — | Cut from current main (post-v3.40.0 release + §1.4 rule merge) |
| 3 Bootstrap | `docs/gamma/cdd/3.41.0/` | — | this file + SELF-COHERENCE + GATE |
| 4 Gap | this file §Gap | cdd | 12 pure surface items mixed with 3 IO functions in `cn_activation.ml`; last Move 2 source module still mixed |
| 5 Mode | this file §Active skills | cdd (§1.4 + §2.5b 8-check), eng/ocaml, eng/testing | MCA, L5 per-slice (but Move 2 ships L7 cumulatively); skills loaded-and-read-before-code |
| 6 Artifacts | tests → code → docs → self-coherence | eng/ocaml, eng/testing | Stage A 14+ expect-tests precede Stage B code |
| 7 Self-coherence | `SELF-COHERENCE.md` | cdd | Written after Stages A–F complete |
| 7a Pre-review | §2.5b 8-check gate (checks 7 + 8 formal this cycle); check 7 pre-verified at bootstrap time; check 8 governs the draft-PR-until-green mechanism for Stage H | cdd | First cycle where check 8 is a formal gate item — author opens PR as draft, waits for CI green, then marks ready-for-review |
| 8 Review | PR body (by user per §1.4) | cdd/review (reviewer-side) | Pending |
| 9 Gate | `GATE.md` | cdd/release | HOLD until CI + review converge |
| 10 Release | by user per §1.4 releasing-agent ownership | cdd/release | Deferred to releasing agent |
| 11–13 Observe/Assess/Close | by user per §1.4 (assessor = releasing agent = user for manual releases) | cdd/post-release | **NOT written by me** — explicit §1.4 compliance: author does not assess cycles they authored |
