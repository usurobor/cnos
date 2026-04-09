## CDD Bootstrap — v3.39.0 (#182 Move 2 slice 2)

**Issue:** #194 — #182 Move 2 slice 2: extract runtime contract types into `src/lib/`
**Cycle scope:** second slice of Move 2 — 11 runtime contract record types + `activation_entry` + `zone_to_string` extracted into `src/lib/cn_contract.ml`
**Branch:** `claude/182-move2-contract-types`
**Design:** `docs/alpha/agent-runtime/CORE-REFACTOR.md` §7 "Move 2 — Pure-model gravity into `src/lib/`" + the v3.38.0 status block naming slice 2 as next
**Parent sequencing:** v3.38.0 post-release named "Move 2 second slice — runtime contract record types" as the next MCA; issue #194 was then filed with the full spec
**Mode:** MCA
**Level:** L6 — cross-module refactor with no new boundary; structural subtraction from `src/cmd/cn_runtime_contract.ml` into `src/lib/cn_contract.ml`. (v3.38.0 slice 1 was L5 in the shipped assessment; slice 2 is L6 because it also pulls `activation_entry` through the type-equality chain, exercising the pattern across two `src/cmd/` modules instead of one.)
**Active skills loaded (and read) before code:** cdd (§2.5b gate, §5.3 trace), eng/ocaml (§3.1 no bare `with _ ->`, §2.1 disambiguate at definition), eng/testing (ppx_expect per extracted module)

### Gap

`src/cmd/cn_runtime_contract.ml` (567 lines) mixes 11 pure record types with IO-heavy gathering/rendering functions. The pure types — `package_info`, `override_info`, `zone`, `zone_entry`, `identity`, `extension_contract_info`, `command_entry`, `orchestrator_entry`, `cognition`, `body_contract`, `runtime_contract` — are consumed by `cn_system.ml`, `cn_doctor.ml`, `cn_assets.ml`, and several test files, but live alongside `Cn_ffi.Fs.exists`, `Cn_ffi.Fs.readdir`, `Cn_assets.walk_skills`, `Cn_command.discover`, `Cn_workflow.discover`, and `Cn_ffi.Fs.write`.

This is the same inverted-abstraction problem slice 1 solved for `cn_deps.ml`: the pure model sits inside the IO wrapper instead of the IO wrapper sitting on top of the pure model. The v3.38.0 `cn_package.ml` extraction proved the OCaml type-equality re-export pattern (`type t = M.t = { ... }`) keeps external callers compiling unchanged while moving the canonical authority into `src/lib/`. This cycle repeats the pattern for the runtime contract types.

Additional wrinkle: `cognition` references `Cn_activation.activation_entry`, which lives in `src/cmd/cn_activation.ml` (an IO module — it reads `cn.package.json` files from installed packages to build the index). The `activation_entry` record itself is pure (4 fields: `skill_id`, `package`, `summary`, `triggers`). The issue offered three options for handling this dependency; this cycle takes **option (b)**: extract `activation_entry` into `cn_contract.ml` alongside the 11 runtime-contract types, and have `cn_activation.ml` re-export it via type-equality so existing callers of `Cn_activation.activation_entry` (test files + `cn_runtime_contract.ml` itself in the `render_markdown` / `to_json` closures) continue to compile unchanged.

### What fails if skipped

- Every new module that needs to reason about runtime contract shape drags in `cn_runtime_contract.ml`'s entire IO surface (`gather`, `write`, the filesystem walks) as a transitive dependency.
- Move 2 stalls at 1/4 slices. The pattern is proven on a small module but not yet scaled to a larger one — the next two slices (workflow IR, activation evaluator) would be uncertain handoffs without the intermediate scaling validation.
- The boundary map needed for the Go kernel rewrite (#192 referenced in #194's Impact section) stays ambiguous — runtime contract types are the second-largest pure surface in `src/cmd/` after package types.

### Scope for this cycle

**Slice 2 of Move 2: the runtime contract types plus one transitive dependency (`activation_entry`).** Remaining slices:

- Slice 3: workflow IR types + parser + validator from `cn_workflow.ml`
- Slice 4: activation evaluator (not just `activation_entry` — the full `build_index` pipeline and its frontmatter parser)

This cycle does NOT:
- Move any IO function (`gather`, `render_markdown`, `to_json`, `write`, `classify_zones`, etc. — all stay in `cn_runtime_contract.ml`)
- Create `src/core/` — per CORE-REFACTOR.md §7, widen `src/lib/` instead
- Refactor any caller-side record literal or field access (the re-export mechanism is the compatibility shim)
- Change any runtime semantics (pure extraction, byte-for-byte field preservation)

### Acceptance Criteria (matching #194 spec)

- [ ] **AC1** New `src/lib/cn_contract.ml` contains all 11 pure record types from `cn_runtime_contract.ml`: `package_info`, `override_info`, `zone`, `zone_entry`, `identity`, `extension_contract_info`, `command_entry`, `orchestrator_entry`, `cognition`, `body_contract`, `runtime_contract`.
- [ ] **AC2** Pure helpers that don't touch IO move to `cn_contract.ml`: `zone_to_string`. (There are no per-type JSON serializers to move — only the monolithic `to_json` which stays in `cn_runtime_contract.ml` per AC5 because it references `Cn_shell.shell_config` and `Cn_capabilities` constants that live in `src/cmd/`.)
- [ ] **AC3** `cn_runtime_contract.ml` re-exports all 11 types via OCaml type-equality (`type t = Cn_contract.t = { ... }`). Zero external caller migration. `zone_to_string` becomes a one-line delegation (`let zone_to_string = Cn_contract.zone_to_string`).
- [ ] **AC4** `src/lib/cn_contract.ml` discipline holds: no `Cn_ffi`, `Cn_executor`, `Cn_cmd`, `Unix`, `Sys`, filesystem, git, process, HTTP, or LLM code. Only stdlib + existing `cn_lib` modules. Verified by grep.
- [ ] **AC5** `cn_runtime_contract.ml` retains all IO functions unchanged: `classify_zones`, `list_md_relative`, `list_skill_overrides`, `extensions_from_registry`, `build_command_registry`, `build_orchestrator_registry`, `gather`, `render_markdown`, `to_json`, `write`.
- [ ] **AC6** `test/lib/cn_contract_test.ml` covers the pure module with ppx_expect tests: record construction + field-read for each type, `zone_to_string` exhaustive mapping, `activation_entry` construction.
- [ ] **AC7** Dune wiring: `cn_contract` registered in `src/lib/dune` modules list; `cn_contract_test` library registered in `test/lib/dune` with `(preprocess (pps ppx_expect))`.
- [ ] **AC8** Existing tests (`test/cmd/cn_runtime_contract_test.ml`, `test/cmd/cn_activation_test.ml`) pass unchanged. Type-equality preserves caller compatibility; five existing caller sites verified by grep to resolve through re-exports.
- [ ] **AC9** `docs/alpha/agent-runtime/CORE-REFACTOR.md` §7 Move 2 status block updated: slice 2 shipped, two remaining (workflow IR, activation evaluator).

### Plus one AC not in the issue but required by the `Cn_activation` decision

- [ ] **AC10** (implementer-added, per `Cn_activation` dependency option (b)): `activation_entry` moves from `cn_activation.ml` into `cn_contract.ml`. `cn_activation.ml` re-exports via type-equality (`type activation_entry = Cn_contract.activation_entry = { ... }`) so existing callers (`test/cmd/cn_activation_test.ml` × 3 field access sites, `src/cmd/cn_runtime_contract.ml` render_markdown/to_json closures) compile unchanged.

### Non-goals (this cycle)

- Moving any IO function out of `cn_runtime_contract.ml`
- Extracting the full `cn_activation.ml` build pipeline (frontmatter parser, `build_index`, manifest walks) — that is slice 4
- Extracting workflow IR — that is slice 3
- Forcing caller migrations from `Cn_runtime_contract.package_info` to `Cn_contract.package_info`
- Refactoring any `Cn_shell.shell_config` or `Cn_capabilities.*` surface (those are separate candidates, if ever)
- Creating `src/core/` — explicit no per CORE-REFACTOR.md §7 ("widen existing `src/lib/`, not new dir")
- Changes to `cn_runtime_contract` runtime semantics (`gather`, `render_markdown`, `to_json`, `write` — all stay byte-for-byte)

### Plan

| Stage | Scope | ACs |
|-------|-------|-----|
| A | Tests first: `test/lib/cn_contract_test.ml` with expect-tests for all 11 runtime-contract types, `activation_entry`, and `zone_to_string` exhaustive mapping | AC6 |
| B | Create `src/lib/cn_contract.ml` with the 11 types + `activation_entry` + `zone_to_string` + discipline comment (no IO) | AC1, AC2, AC4, AC10 (canonical side) |
| C | Rewrite `src/cmd/cn_runtime_contract.ml`: delete the 11 type definitions + `zone_to_string`, replace with type re-exports (`type package_info = Cn_contract.package_info = { ... }`) + one-line `zone_to_string` delegation; keep every IO function unchanged | AC3, AC5 |
| C' | Update `src/cmd/cn_activation.ml`: delete `activation_entry` type definition, replace with `type activation_entry = Cn_contract.activation_entry = { ... }` re-export | AC10 (caller side) |
| D | Register `cn_contract` in `src/lib/dune` modules list (alongside `cn_package`) and `cn_contract_test` library in `test/lib/dune` | AC7 |
| E | Verify no caller churn: grep for every external reference to `Cn_runtime_contract.{type}` and `Cn_activation.activation_entry` and confirm re-exports cover each site | AC8 |
| F | Update `docs/alpha/agent-runtime/CORE-REFACTOR.md` §7 Move 2 status: slice 2 shipped, two remaining (workflow IR, activation evaluator) | AC9 |
| G | Self-coherence report + GATE | — |
| H | §2.5b 6-check pre-review gate (including check 6 schema/fixture audit — expected to come out clean again because type-equality preserves identity, but must be explicitly performed) | — |

### Impact Graph

**New files:**
- `src/lib/cn_contract.ml` (types + `activation_entry` + `zone_to_string`)
- `test/lib/cn_contract_test.ml` (ppx_expect tests)

**Touched modules:**
- `src/cmd/cn_runtime_contract.ml` — delete 11 type defs + `zone_to_string` body; add 11 type re-exports + delegating `zone_to_string`; retain all IO functions unchanged
- `src/cmd/cn_activation.ml` — delete `activation_entry` type def; add type re-export from `Cn_contract`
- `src/lib/dune` — register `cn_contract` module
- `test/lib/dune` — register `cn_contract_test` library

**Touched docs:**
- `docs/alpha/agent-runtime/CORE-REFACTOR.md` — §7 Move 2 status block (slice 2 shipped)

**Compatibility-preserved (verified by grep, not changed):**
- `src/cmd/cn_runtime_contract.ml::render_markdown` — references `Cn_activation.activation_entry` in closure; works unchanged via re-export
- `src/cmd/cn_runtime_contract.ml::to_json` — same
- `test/cmd/cn_runtime_contract_test.ml` — 3 type annotation sites on `Cn_runtime_contract.package_info` and `Cn_runtime_contract.zone_entry`; works via type-equality re-export
- `test/cmd/cn_activation_test.ml` — 3 type annotation sites on `Cn_activation.activation_entry`; works via type-equality re-export from `Cn_activation` to `Cn_contract`
- `src/cmd/cn_system.ml` + `src/cmd/cn_doctor.ml` + `src/cmd/cn_assets.ml` — consumers of the runtime contract; verified by grep to have no type-construction sites that would break

### CDD Trace

| Step | Artifact | Skills loaded | Decision |
|------|----------|---------------|----------|
| 0 Observe | v3.38.0 post-release assessment (Next MCA = runtime contract types) + #194 spec + `cn_runtime_contract.ml` current shape + `cn_activation.ml` dependency | cdd, post-release | Next MCA per v3.38.0 assessment is slice 2 (runtime contract types); issue #194 was filed with full spec |
| 1 Select | #194 (#182 Move 2 slice 2) | cdd | L6 structural subtraction across two `src/cmd/` modules; scope = one primary extraction + one transitive dependency |
| 2 Branch | `claude/182-move2-contract-types` | — | Created from current main (post-`de39e64` = v3.38.0 post-release lag-table patch) |
| 3 Bootstrap | `docs/gamma/cdd/3.39.0/` | — | this file + SELF-COHERENCE + GATE |
| 4 Gap | this file §Gap | cdd | `cn_runtime_contract.ml` owns 11 pure types behind an IO module; `activation_entry` is the transitive dep |
| 5 Mode | this file §Active skills | cdd, eng/ocaml, eng/testing | MCA, L6, work shape "cross-module refactor"; skills loaded-and-read-before-code |
| 6 Artifacts | tests → code → docs → self-coherence | eng/ocaml, eng/testing | Stage A tests precede Stage B code |
| 7 Self-coherence | `SELF-COHERENCE.md` | cdd | Written after Stages A–F complete |
| 7a Pre-review | §2.5b 6-check gate (with check 6 schema/fixture audit) | cdd | Check 6 expected clean — type-equality preserves identity; still performed explicitly |
| 8 Review | PR body | cdd/review | Pending |
| 9 Gate | `GATE.md` | cdd/release | HOLD until CI + review converge |
| 10 Release | — | — | Next release train (v3.39.0) |
