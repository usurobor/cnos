## CDD Bootstrap — v3.40.0 (#182 Move 2 slice 3)

**Issue:** #196 — #182 Move 2 slice 3: extract workflow IR types + parser + validator into `src/lib/`
**Cycle scope:** third slice of Move 2 — 6 pure IR types + 10 pure functions (parsers, validator, helpers, result combinator) extracted from `src/cmd/cn_workflow.ml` (655 lines) into `src/lib/cn_workflow_ir.ml`
**Branch:** `claude/182-move2-workflow-ir`
**Design:** `docs/alpha/agent-runtime/CORE-REFACTOR.md` §7 "Move 2 — Pure-model gravity into `src/lib/`" + the v3.39.0 status block naming slice 3 as next
**Parent sequencing:** v3.39.0 (#194 / PR #195) merged `7f2d4b9` — the runtime-contract types + `activation_entry` extraction; #196 was then filed with the full spec for the workflow IR extraction
**Mode:** MCA
**Level:** L6 — cross-module refactor with no new boundary; largest Move 2 slice so far (655 LOC source module, 6 types + 10 pure functions + 16 variant/constructor re-exports). Execution quality target L6 (earn it cleanly, no mechanical misses after the slice-2 library-name collision lesson)
**Active skills loaded (and read) before code:** cdd (§2.5b gate + new check 7 for library name uniqueness, though the check 7 patch is stashed pending the 3.39.0 post-release PR — the discipline is applied manually this cycle), eng/ocaml (§3.1 no bare `with _ ->`, §2.1 disambiguate at definition), eng/testing (ppx_expect per extracted module)

### Gap

`src/cmd/cn_workflow.ml` (655 lines) is the largest of the Move 2 candidate modules. It mixes:

- **6 pure types** (`trigger`, `permissions`, `step` as a 6-variant sum, `orchestrator`, `issue_kind` as a 7-variant sum, `issue`) — no IO references
- **10 pure functions** (`let ( let* )` result combinator, `require_string`, `parse_string_list`, `parse_trigger`, `parse_permissions`, `parse_step`, `parse`, `step_id`, `validate`, `manifest_orchestrator_ids`) — stdlib + `Cn_json` only
- **Heavy IO surface** (`parse_file`, `discover`, `doctor_issues`, `execute_step`, `execute`, `typed_op_of_op_step`, `trace_event`, `find_step`, `env_get`, `as_bool`, `as_string`) — uses `Cn_ffi.Fs`, `Cn_assets.list_installed_packages`, `Cn_shell`, `Cn_trace.gemit`, `Cn_executor.execute_op`
- **Three IO-transit types** (`load_outcome`, `installed`, `outcome`) — pure by shape but only consumed by IO functions in `cn_workflow.ml` (`discover`, `execute`) and by `cn_runtime_contract.ml::build_orchestrator_registry` which pattern-matches on the `load_outcome` constructors (`Loaded`, `Load_error`)

Same inverted-abstraction problem slices 1–2 solved for `cn_deps.ml` and `cn_runtime_contract.ml`: the pure IR model sits inside the IO wrapper instead of the IO wrapper sitting on top of the pure model. Any consumer of the workflow types transitively depends on the full execution engine (`Cn_executor`, `Cn_shell`, `Cn_trace`, `Cn_ffi`, `Cn_assets`) even when they only need to read record fields or pattern-match on a variant.

### What fails if skipped

- Every new cross-module that needs to reason about workflow IR shape (future CTB → IR compiler #175, doctor validation enhancements, runtime contract projection enhancements, Go kernel rewrite #192) has to depend on `Cn_workflow`, which drags in the entire execution + discovery + doctor + trace surface as a transitive dependency.
- Move 2 stalls at 2/4 slices. The pattern is proven on two modules (130 LOC cn_deps, 567 LOC cn_runtime_contract) but not yet on the largest candidate (655 LOC cn_workflow with complex variant types). Without scaling to this slice, the pattern's applicability to slice 4 (activation evaluator, which has a frontmatter parser and walk logic) is uncertain.
- The boundary map needed for the Go kernel rewrite (#192, referenced in #196's Impact section) stays ambiguous — workflow IR types are the largest pure surface in `src/cmd/` after the contract types already extracted in slice 2.

### Scope for this cycle

**Slice 3 of Move 2: the workflow IR types + parsers + validator + helpers.** Remaining after this:

- Slice 4: activation evaluator (frontmatter parser + `build_index` + `list_declared_skills`) from `cn_activation.ml`. Last Move 2 slice.

This cycle does NOT:
- Move any IO function (`parse_file`, `discover`, `doctor_issues`, `execute_step`, `execute`, `typed_op_of_op_step`, `trace_event`, `find_step`, `env_get`, `as_bool`, `as_string` — all stay per AC4)
- Move `load_outcome`, `installed`, or `outcome` types (decision: **option (b)** per the issue's choice — see §"load_outcome/installed/outcome decision" below)
- Create `src/core/` — per CORE-REFACTOR.md §7, widen `src/lib/` instead
- Refactor any caller-side record literal, variant construction, or field access (the re-export mechanism is the compatibility shim)
- Change any runtime semantics (pure extraction, byte-for-byte field and constructor preservation)

### `load_outcome` / `installed` / `outcome` decision

The issue offered two options for these types (which are pure records but referenced by IO functions). This cycle takes **option (b): keep them in `cn_workflow.ml`**. Rationale:

1. **`load_outcome`** is only consumed by:
   - `discover` in `cn_workflow.ml` (IO — produces it)
   - `doctor_issues` in `cn_workflow.ml` (IO — consumes it)
   - `cn_runtime_contract.ml::build_orchestrator_registry` (IO — pattern-matches on `Loaded`/`Load_error` constructors)
   Moving it would either force `cn_runtime_contract.ml` to migrate its pattern match (violating "zero caller churn") or require a type-equality re-export from `cn_workflow.ml`. But the type is *only* used by IO sites — there is no pure consumer benefit.

2. **`installed`** has the same coupling shape: only IO producers and IO consumers.

3. **`outcome`** is only used by `execute` (IO) and is returned by `execute` to its caller (IO).

4. Moving them would widen the `Cn_workflow_ir` surface by 3 types that no pure code needs. The pattern in slice 2 was *inverted*: `activation_entry` moved *because* a pure consumer (`cognition.activation_index`) needed it. Here, no pure consumer needs these three — they're a pure shape serving IO code. The discipline argument goes the other way.

Option (b) keeps the boundary sharp: `Cn_workflow_ir` = "the minimal pure model a CTB compiler or future IR consumer needs"; `Cn_workflow` = "everything else including the IO-side type definitions that happen to be pure by shape."

### Acceptance Criteria (matching #196 spec)

- [ ] **AC1** New `src/lib/cn_workflow_ir.ml` contains:
  - Types: `trigger`, `permissions`, `step` (6-variant), `orchestrator`, `issue_kind` (7-variant), `issue`
  - Parsers: `require_string`, `parse_string_list`, `parse_trigger`, `parse_permissions`, `parse_step`, `parse`
  - Validator: `validate`
  - Helpers: `step_id`, `manifest_orchestrator_ids`
  - Result combinator: `let ( let* )`
- [ ] **AC2** Purity discipline: only stdlib + `Cn_json`. No `Cn_ffi`, `Cn_executor`, `Cn_shell`, `Cn_trace`, `Cn_assets`, `Unix`, `Sys`. Verified by grep.
- [ ] **AC3** `cn_workflow.ml` re-exports all 6 types via OCaml type-equality (`type t = Cn_workflow_ir.t = { ... }` for records; `type t = Cn_workflow_ir.t = Ctor1 | ...` for variants) and delegates all 10 pure functions via one-line let-bindings. Zero caller migration.
- [ ] **AC4** `cn_workflow.ml` retains all IO functions unchanged: `parse_file`, `discover`, `doctor_issues`, `execute_step`, `execute`, `typed_op_of_op_step`, `trace_event`, `find_step`, `env_get`, `as_bool`, `as_string`, plus the three IO-transit types (`load_outcome`, `installed`, `outcome` — per option (b) above).
- [ ] **AC5** `test/lib/cn_workflow_ir_test.ml` covers the pure module with ppx_expect tests: record construction for the 4 record-shaped types (`trigger`, `permissions`, `orchestrator`, `issue`); step variant construction (one per variant kind — `Op_step`, `Llm_step`, `If_step`, `Match_step`, `Return_step`, `Fail_step`); issue_kind variant construction (one per kind); parser round-trips covering each `kind` branch of `parse_step` + the top-level `parse`; `validate` for the happy path and 4 issue classes (empty_steps, duplicate_step_id, invalid_step_ref, permission_gap); `step_id` exhaustive over all 6 step variants; `manifest_orchestrator_ids` for the happy path and a malformed payload.
- [ ] **AC6** Dune wiring: `cn_workflow_ir` registered in `src/lib/dune` modules list alongside `cn_package` and `cn_contract`; `cn_workflow_ir_test` library registered in `test/lib/dune` with `(libraries cn_lib)` + `(preprocess (pps ppx_expect))`. Library name grep-verified against workspace — no collision with `cn_workflow_test` in `test/cmd/dune:173` (§2.5b check 7, applied manually pending the stashed skill patch).
- [ ] **AC7** Existing `test/cmd/cn_workflow_test.ml` passes unchanged. All external references verified by grep — `Cn_workflow.parse` × 6, `Cn_workflow.validate` × 5, 6 step variant pattern matches, 5 issue_kind variant pattern matches, `Cn_workflow.issue` type annotations × 5, plus 6 retained `installed`/`Loaded`/`Load_error` sites (option b). All resolve either through type-equality re-exports or through unchanged retained types.
- [ ] **AC8** `docs/alpha/agent-runtime/CORE-REFACTOR.md` §7 Move 2 status block updated: slice 3 shipped, 1 remaining (activation evaluator).

### Non-goals (this cycle)

- Extracting the `cn_activation.ml` evaluator (slice 4, next cycle)
- Moving `load_outcome` / `installed` / `outcome` (option (b) — see decision above)
- Moving `find_step`, `env_get`, `as_bool`, `as_string` — these are pure by shape but per AC4 stay in `cn_workflow.ml` because their only consumer is `execute_step` (IO). Same rationale as option (b) for the transit types.
- Refactoring the `let ( let* )` result combinator into a standalone utility module — it moves inline with the parser per AC1, no extraction into a generic `Result` helper
- Forcing caller migrations from `Cn_workflow.step` to `Cn_workflow_ir.step` — the re-export is the compatibility shim, callers stay on `Cn_workflow.*`
- Creating `src/core/` — explicit no per CORE-REFACTOR.md §7
- Changes to the `cn.orchestrator.v1` wire schema, the `parse_step` field surface (including the `inputs` deferral), or the `execute_step` runtime behavior

### Plan

| Stage | Scope | ACs |
|-------|-------|-----|
| A | Tests first: `test/lib/cn_workflow_ir_test.ml` with expect-tests for types + parsers + validator + step_id + manifest_orchestrator_ids | AC5 |
| B | Create `src/lib/cn_workflow_ir.ml` with the 6 types + 10 pure functions + discipline comment (no IO) | AC1, AC2 |
| C | Rewrite `src/cmd/cn_workflow.ml`: delete the 6 type defs + 10 pure functions, replace with type re-exports (`type t = Cn_workflow_ir.t = { ... }`) + delegating let-bindings; retain every IO function and the 3 IO-transit types unchanged | AC3, AC4 |
| D | Register `cn_workflow_ir` in `src/lib/dune` modules list; register `cn_workflow_ir_test` library in `test/lib/dune` | AC6 |
| E | Verify no caller churn: grep for every external reference to `Cn_workflow.{type}` and confirm re-exports cover each site | AC7 |
| E' | **Manual §2.5b check 7** (workspace library name uniqueness): `grep -rn "(name cn_workflow_ir\|cn_workflow_ir_test)" src/ test/` — already performed pre-bootstrap, zero collisions | — (manual, pending merged skill patch) |
| F | Update `docs/alpha/agent-runtime/CORE-REFACTOR.md` §7 Move 2 status: slice 3 shipped, 1 remaining (activation evaluator) | AC8 |
| G | Self-coherence report + GATE | — |
| H | §2.5b 6-check pre-review gate + manual check 7 + commit + push + PR | — |

### Impact Graph

**New files:**
- `src/lib/cn_workflow_ir.ml` (6 types + 10 pure functions)
- `test/lib/cn_workflow_ir_test.ml` (ppx_expect tests)

**Touched modules:**
- `src/cmd/cn_workflow.ml` — delete 6 type defs + 10 pure function bodies; add type re-exports + delegating let-bindings; retain all IO functions unchanged
- `src/lib/dune` — register `cn_workflow_ir` module (alongside `cn_package`, `cn_contract`)
- `test/lib/dune` — register `cn_workflow_ir_test` library

**Touched docs:**
- `docs/alpha/agent-runtime/CORE-REFACTOR.md` — §7 Move 2 status block (slice 3 shipped)

**Compatibility-preserved (verified by grep, not changed):**
- `test/cmd/cn_workflow_test.ml` — moved-type reference sites: `Cn_workflow.parse` × 6, `Cn_workflow.validate` × 5, 6 step variant pattern matches, 5 issue_kind variant pattern matches, `Cn_workflow.issue` × 5 type annotations. All resolve through type-equality re-export. Plus 6 retained-type sites: `Cn_workflow.installed` × 3, `Cn_workflow.Loaded` × 1, `Cn_workflow.Load_error` × 2 (per option b — these types stay in `cn_workflow.ml` so the sites are trivially stable).
- `src/cmd/cn_doctor.ml` — calls `Cn_workflow.discover` + `Cn_workflow.doctor_issues` (both IO functions, stay in `Cn_workflow`). No type references.
- `src/cmd/cn_runtime_contract.ml::build_orchestrator_registry` — calls `Cn_workflow.discover` and pattern-matches on `Cn_workflow.installed` + `Cn_workflow.Load_error` / `Cn_workflow.Loaded`. These are the IO-transit types staying in `Cn_workflow` per option (b). Zero impact.

### CDD Trace

| Step | Artifact | Skills loaded | Decision |
|------|----------|---------------|----------|
| 0 Observe | v3.39.0 post-release §7 naming workflow IR as next MCA + #196 spec + `cn_workflow.ml` current shape + caller grep across `src/cmd/` + `test/cmd/` | cdd, post-release | Next MCA per v3.39.0 assessment is slice 3; #196 was filed with the full spec including the library-naming warning learned from #195 |
| 1 Select | #196 (#182 Move 2 slice 3) | cdd | L6 structural subtraction on the largest Move 2 candidate (655 LOC source module, 6 types + 10 pure functions) |
| 2 Branch | `claude/182-move2-workflow-ir` | — | Cut from current main (`8b04e30` = eng/go skill v2 on top of #195) |
| 3 Bootstrap | `docs/gamma/cdd/3.40.0/` | — | this file + SELF-COHERENCE + GATE |
| 4 Gap | this file §Gap | cdd | `cn_workflow.ml` owns 6 pure types + 10 pure functions behind an IO wrapper; slice 3 extracts them |
| 5 Mode | this file §Active skills | cdd, eng/ocaml, eng/testing | MCA, L6, work shape "cross-module refactor"; skills loaded-and-read-before-code |
| 6 Artifacts | tests → code → docs → self-coherence | eng/ocaml, eng/testing | Stage A tests precede Stage B code |
| 7 Self-coherence | `SELF-COHERENCE.md` | cdd | Written after Stages A–F complete |
| 7a Pre-review | §2.5b 6-check gate + manual check 7 (workspace library name uniqueness — the v3.39.0 post-release skill patch is stashed pending its own PR, so check 7 is applied manually this cycle) | cdd | Check 7 performed pre-bootstrap, zero collisions for `cn_workflow_ir` / `cn_workflow_ir_test` |
| 8 Review | PR body | cdd/review | Pending |
| 9 Gate | `GATE.md` | cdd/release | HOLD until CI + review converge |
| 10 Release | — | — | Next release train (v3.40.0) |
