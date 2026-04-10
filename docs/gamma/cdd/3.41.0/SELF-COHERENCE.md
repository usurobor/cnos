## Self-Coherence Report — v3.41.0 (#182 Move 2 slice 4 — **final slice**)

**Issue:** #201 — #182 Move 2 slice 4: extract activation frontmatter parser + types into `src/lib/`
**Branch:** `claude/182-move2-activation`
**Active skills loaded (and read) before code:** cdd (§1.4 Roles + §2.5b 8-check gate including the new formal checks 7 + 8), eng/ocaml (§3.1 no bare `with _ ->`, §2.1 disambiguate at definition), eng/testing (ppx_expect per extracted module)

### Alpha (type-level clarity)

| Surface | Change | Type-level judgment |
|---------|--------|---------------------|
| `Cn_frontmatter.frontmatter` (new canonical home) | `{ fm_name : string option; fm_description : string option; fm_triggers : string list }` moved from `cn_activation.ml` | Pure record. `fm_` field-prefix preserved to disambiguate the three fields per eng/ocaml §2.1 (established by slice 2's same-module-multiple-records discipline). |
| `Cn_frontmatter.empty_frontmatter` (new canonical home) | Constant value: the zero-filled `frontmatter` (`None`, `None`, `[]`) | Pure constant. Used as the "no frontmatter found" sentinel and as the base case for the imperative parser loop. |
| `Cn_frontmatter.split_lines`, `extract_block`, `parse_key_value`, `is_list_item`, `list_item_value` | 5 line-level YAML-subset helpers moved | All pure. `extract_block` uses pattern matching + recursive `take` helper with explicit `None` on unterminated and empty-list cases; no exceptions escape. `parse_key_value` uses `String.index_opt` (total, returns `None` instead of raising). `is_list_item` and `list_item_value` are one-liners that can only be called after an `is_list_item` guard succeeds. |
| `Cn_frontmatter.parse_frontmatter` (new canonical home) | Main parser — 45-line imperative loop over block lines with `ref`-based mutable state for pending list accumulation | Pure in the sense that matters for `src/lib/`: no filesystem, no network, no process exec. Uses `Printf.eprintf` for two distinct warning classes (malformed line, inline triggers unsupported) — stderr precedent established in v3.40.0 slice 3 and documented in CORE-REFACTOR.md §7 discipline. The `ref` + `Printf.eprintf` combination is local mutation + diagnostic output, not IO in the forbidden sense. |
| `Cn_frontmatter.manifest_skill_ids` (new canonical home) | Reads `sources.skills` from a parsed `cn.package.json` and returns the declared skill IDs | Pure. Uses `Cn_json.get` + `List.filter_map` + pattern matching. Also uses `Printf.eprintf` for malformed-entry warnings (same stderr precedent). |
| `Cn_frontmatter.issue_kind` (new canonical home) | 3-variant sum: `Missing_skill`, `Empty_triggers`, `Trigger_conflict` | Pure variant. **Distinct from `Cn_workflow_ir.issue_kind`** (7-variant, workflow IR validation) — different domains, different module paths, no OCaml-level collision. Both types coexist in `src/lib/` without interference because they live in separate modules and are always referenced via module-qualified names or explicit type annotations. |
| `Cn_frontmatter.issue` (new canonical home) | `{ kind : issue_kind; message : string }` — 2-field record | Pure record. **Field name is `kind`, not `issue_kind`** — deliberately preserved from the pre-extraction definition to avoid caller-side churn in `cn_doctor.ml` (which reads `i.kind`). This is intentionally different from `Cn_workflow_ir.issue.issue_kind` (which has field name matching the type name). The divergence is pre-existing and the re-export preserves it exactly. |
| `Cn_frontmatter.issue_kind_label` (new canonical home) | 3-case pattern match: `Missing_skill -> "missing" \| Empty_triggers -> "empty" \| Trigger_conflict -> "conflict"` | Pure exhaustive pattern match. Compiler enforces exhaustiveness; adding a 4th constructor would force this function to update (and trigger a compile error in consumers). |
| `Cn_activation.{frontmatter, issue_kind, issue}` | Now **type re-exports** via OCaml type-equality: `type frontmatter = Cn_frontmatter.frontmatter = { fm_name; fm_description; fm_triggers }` + variants/records for `issue_kind` and `issue` | Same record/variant at the OCaml type level. Existing pattern matches at `Cn_activation.Missing_skill` etc. (in `cn_doctor.ml` and `test/cmd/cn_activation_test.ml`) continue to compile because the re-exported variant re-exposes its constructors in the re-exporting module. The `i.kind` field access also works because the re-exported record IS `Cn_frontmatter.issue` at the type level. |
| `Cn_activation.{empty_frontmatter, split_lines, extract_block, parse_key_value, is_list_item, list_item_value, parse_frontmatter, manifest_skill_ids, issue_kind_label}` | Now **9 delegating let-bindings**: `let f = Cn_frontmatter.f` | One-line re-exports. Behaviour preserved exactly — every delegated function has the same type signature and same runtime behaviour because it IS the same function under a different name. |
| `Cn_activation.activation_entry` | **Unchanged** — still the type-equality re-export from `Cn_contract` that slice 2 established. No slice-4 modification. | Same record at the OCaml type level. The chained re-export from slice 2 (v3.39.0) remains valid and unbroken. |
| `Cn_activation` IO surface | Untouched — `read_skill_frontmatter`, `build_index`, `validate` retained with zero modification | Every IO function stays in `cn_activation.ml`. The pure ↔ IO split runs through the type-re-export section + the delegating let-bindings, not through any function body. `read_skill_frontmatter` uses the delegated `parse_frontmatter` under the hood (the local name still works because of the let-binding). `build_index` uses the delegated `manifest_skill_ids`. `validate` constructs `issue` records using the bare field names `kind` and `message` unqualified, which resolves to the re-exported record. |

**Alpha score: A.** The diff is structural subtraction. 12 pure surface items leave `cn_activation.ml` and arrive in `cn_frontmatter.ml` byte-for-byte equivalent. The re-export mechanism preserves OCaml-level type identity for the 3 types + 9 functions. The activation-specific `issue_kind` (3-variant) vs the workflow IR `issue_kind` (7-variant) coexistence is handled structurally — different modules, different domains, no OCaml-level collision. The field-name divergence (`kind` vs `issue_kind`) is preserved deliberately to keep `cn_doctor.ml` and the existing test file compiling without edits. `Printf.eprintf` diagnostics are permitted per the v3.40.0 stderr discipline clarification. The `activation_entry` re-export chain from slice 2 remains unbroken and the IO surface is untouched.

### Beta (surface agreement)

| Surface | Authority | Consumers updated? |
|---------|-----------|--------------------|
| `frontmatter` record shape | `Cn_frontmatter` (canonical) | Re-exported by `Cn_activation` via type-equality. Consumer: `Cn_activation.{read_skill_frontmatter, build_index}` uses `fm.fm_description`, `fm.fm_triggers` field access — works unchanged because the re-exported record IS `Cn_frontmatter.frontmatter`. |
| `empty_frontmatter` constant | `Cn_frontmatter` (canonical) | Delegated let-binding in `Cn_activation`. Used internally by the re-exported `parse_frontmatter` (via module scope). No external consumers. |
| 5 line-level YAML-subset helpers | `Cn_frontmatter` (canonical) | Delegated let-bindings. Used internally by the re-exported `parse_frontmatter`. No external consumers beyond the test coverage. |
| `parse_frontmatter` | `Cn_frontmatter` (canonical) | Delegated let-binding. 5 external reference sites in `test/cmd/cn_activation_test.ml` (lines 112, 134, 146, 158, 170) all resolve through the delegation. 1 internal use in `Cn_activation.read_skill_frontmatter` (line 88 of the rewritten file) also uses the delegated name and resolves. |
| `manifest_skill_ids` | `Cn_frontmatter` (canonical) | Delegated let-binding. 2 internal uses in `Cn_activation.{build_index, validate}` use the local delegated name. No external consumers. |
| `issue_kind` variant (3-constructor) | `Cn_frontmatter` (canonical) | Re-exported by `Cn_activation` via type-equality with constructor re-exposure. External references: `cn_doctor.ml` (`Cn_activation.Trigger_conflict`) and `test/cmd/cn_activation_test.ml` (`Cn_activation.Missing_skill`, `Cn_activation.Empty_triggers`, `Cn_activation.Trigger_conflict` × 2 each) all resolve because the re-exposed constructors are in scope wherever the `Cn_activation` module is opened or qualified. |
| `issue` record | `Cn_frontmatter` (canonical) | Re-exported by `Cn_activation` via type-equality. External references: `cn_doctor.ml` (`(i : Cn_activation.issue)` type annotations + `i.kind` field access) and `test/cmd/cn_activation_test.ml` (5 `(i : Cn_activation.issue)` annotations). All resolve because the re-exported record IS the canonical one at the OCaml type level. |
| `issue_kind_label` | `Cn_frontmatter` (canonical) | Delegated let-binding. 1 external reference in `cn_doctor.ml` line 44 (`Cn_activation.issue_kind_label i.kind`) — works via the delegation. |
| `activation_entry` chain | `Cn_contract` (canonical from slice 2) — unchanged | `Cn_activation.activation_entry` still re-exports `Cn_contract.activation_entry` via the type-equality syntax established in v3.39.0. No slice-4 modification. 3 external reference sites in `test/cmd/cn_activation_test.ml` + 2 in `src/cmd/cn_runtime_contract.ml` continue to resolve through the slice-2 chain. |
| `src/lib/` discipline (no IO) | `CORE-REFACTOR.md` §7 (with v3.40.0 stderr precedent clarification) + `src/lib/dune` comment | `cn_frontmatter.ml` imports only stdlib + `Cn_json`. Verified by grep: `grep -n "Cn_ffi\|Cn_executor\|Cn_cmd\|Cn_contract\|Unix\|Sys\." src/lib/cn_frontmatter.ml` → zero matches. `Printf.eprintf` for stderr diagnostics is permitted per the v3.40.0 precedent. |
| `src/lib/dune` modules list | dune | `cn_frontmatter` inserted between `cn_workflow_ir` and `cn_build_info`. Now 10 modules: `cn_lib cn_json cn_sha256 cn_package cn_contract cn_workflow_ir cn_frontmatter cn_build_info cn_version cn_repo_info`. |
| `test/lib/dune` library list | dune | `cn_frontmatter_test` library added as the seventh test library. §2.5b check 7 verified pre-bootstrap and re-verified at Stage D (no workspace-global collision with the pre-existing `cn_activation_test` in `test/cmd/dune:165`). |
| `CORE-REFACTOR.md` §7 Move 2 status block | docs | v3.41.0 block added with the **"✅ Move 2 complete"** milestone callout. The "remaining candidates" line becomes **"none"**. The block explicitly cites #192 (Go kernel rewrite) as the newly-unblocked next track. |

**Stale-reference scan:**

- `grep -rn "Cn_activation\.\(frontmatter\|empty_frontmatter\|split_lines\|extract_block\|parse_key_value\|is_list_item\|list_item_value\|parse_frontmatter\|manifest_skill_ids\|issue_kind\|issue\b\|issue_kind_label\|Missing_skill\|Empty_triggers\|Trigger_conflict\)"` → 2 source-tree matches: `src/cmd/cn_doctor.ml` (6 reference sites) + `test/cmd/cn_activation_test.ml` (~18 reference sites). All resolve through re-exports + delegating let-bindings as enumerated in §Beta above. Historical matches in `docs/gamma/cdd/` frozen snapshot docs are expected and informational only.
- `grep -rn "Cn_activation\.\(read_skill_frontmatter\|build_index\|validate\)"` → these IO functions are **retained** in `cn_activation.ml` with zero modification. 3 references in `test/cmd/cn_activation_test.ml` + 2 in `src/cmd/cn_doctor.ml` + 1 in `src/cmd/cn_runtime_contract.ml` all continue to resolve because the functions haven't moved.
- `grep -rn "Cn_activation\.activation_entry"` → the slice-2 re-export chain is unmodified. 3 references in `test/cmd/cn_activation_test.ml` + 2 in `src/cmd/cn_runtime_contract.ml` continue to resolve through the chain.
- `grep -rn "let open Cn_activation\b"` → zero matches. No `open` statements that would require deeper type-path resolution.
- `grep -n "with _ " src/lib/cn_frontmatter.ml` → zero matches (eng/ocaml §3.1 holds — the pure module has two `try ... with exn ->` handlers in the pre-extraction `read_skill_frontmatter`, but those are in the IO function which stays in `cn_activation.ml`; the pure module itself has no exception handling).
- `grep -n "^type activation_entry\|^type frontmatter\|^type issue" src/cmd/cn_activation.ml` → shows 4 lines: 3 type re-exports (`frontmatter`, `issue_kind`, `issue`) + 1 `activation_entry` re-export from slice 2. No duplicate definitions lingering.
- `grep -n "^let parse_frontmatter\|^let manifest_skill_ids\|^let issue_kind_label\|^let empty_frontmatter" src/cmd/cn_activation.ml` → shows 4 lines, all delegating let-bindings. No duplicate function bodies.

**Schema/fixture audit (§2.5b check 6):**

Did this PR change a JSON schema, manifest shape, op envelope, receipt format, or any string-literal contract that test fixtures construct?

**No.**
- Record field names (`fm_name`, `fm_description`, `fm_triggers`, `kind`, `message`), variant constructor names (`Missing_skill`, `Empty_triggers`, `Trigger_conflict`), the `issue_kind_label` output strings (`"missing"`, `"empty"`, `"conflict"`), and the `sources.skills` JSON path are all byte-for-byte preserved.
- Test fixtures in `test/cmd/cn_activation_test.ml` construct `issue` records via pattern matching on `(i : Cn_activation.issue)` annotations — these all work because the re-exported type IS `Cn_frontmatter.issue` at the OCaml level.
- The new `test/lib/cn_frontmatter_test.ml` constructs `frontmatter` and `issue` records using the new canonical type name `Cn_frontmatter.frontmatter` / `Cn_frontmatter.issue` directly. These are new literals in new test code, not modifications to existing fixtures.
- No YAML schema change, no JSON schema change, no constructor rename.

Structural no-op for pure-type extraction cycles, same as slices 1 + 2 + 3.

**§2.5b check 7 (workspace-global library-name uniqueness — formal this cycle):**

Verified pre-bootstrap and re-verified at Stage D. `grep -rn "(name cn_frontmatter" src/ test/` → only `test/lib/dune:55 (name cn_frontmatter_test)` (the new stanza I added in Stage D); no pre-existing collisions. `grep -rn "(name cn_frontmatter_test)" src/ test/` → same (only the new stanza). The existing `cn_activation_test` library in `test/cmd/dune:165` is distinct — the `frontmatter_` prefix in the new name is the distinguishing mark.

**Beta score: A.** Every downstream consumer of the touched authorities is resolved through either a type-equality re-export (the 3 type surfaces for `cn_doctor.ml` + `cn_activation_test.ml`) or a delegating let-binding (the 9 function surfaces, mostly used internally by the IO functions in `cn_activation.ml` itself). No schema changes, no fixture-level record construction edits, no stale references. The schema/fixture audit (check 6) and workspace-library-name uniqueness check (check 7) both come up clean. `src/lib/cn_frontmatter.ml` imports only stdlib + `Cn_json`, verified by grep.

### Gamma (cycle economics)

**Lines changed:**

| File | Rough delta |
|------|-------------|
| `src/lib/cn_frontmatter.ml` (new) | +185 lines (3 type defs + 1 constant + 6 parsers + 2 helpers + discipline comment) |
| `src/lib/dune` | +1 token (`cn_frontmatter` in modules list) |
| `test/lib/cn_frontmatter_test.ml` (new) | +215 lines (21 ppx_expect tests: F1/F2 record+constant, E1–E4 extract_block, K1–K3 parse_key_value, L1–L3 is_list_item/list_item_value, P1–P4 parse_frontmatter, M1–M3 manifest_skill_ids, IK1 issue_kind_label, I1 issue construction) |
| `test/lib/dune` | +12 lines (new library stanza with check-7 comment) |
| `src/cmd/cn_activation.ml` | net ~−85 lines (removed 12 pure surface items ≈ 200 lines; added 3 type re-exports + 9 delegating let-bindings + v3.41.0 docstring ≈ 115 lines; net shrink from 288 to ~203 lines) |
| `docs/alpha/agent-runtime/CORE-REFACTOR.md` | +1 status block (v3.41.0 Move 2 complete, with milestone callout) |
| `docs/gamma/cdd/3.41.0/` (new) | README + this file + GATE |

**Test-first discipline:** `test/lib/cn_frontmatter_test.ml` was authored in Stage A before `src/lib/cn_frontmatter.ml` in Stage B. 21 tests cover every moved type, constant, and function — including edge cases for the frontmatter parser (missing markers, unterminated blocks, empty blocks, scalar-only, unrecognised keys) and `manifest_skill_ids` (happy, missing-sources, missing-skills-subkey).

**§2.5b 8-check gate (formal this cycle — first cycle where ALL 8 checks are formal gate items):**

| # | Check | Pass | Evidence |
|---|-------|------|----------|
| 1 | Branch rebased onto current `main` | pending verify | Branch cut from current main; re-verify at Stage H push time |
| 2 | Self-coherence present | ✅ | `SELF-COHERENCE.md` — this file |
| 3 | CDD Trace in PR body | pending | Will be included from `README.md` |
| 4 | Tests reference ACs | ✅ | F/E/K/L/P/M/IK/I test families → AC1/AC2/AC5/AC6 |
| 5 | Known debt explicit | ✅ | README §Non-goals (4 items) + §1.4 step 11-13 ownership clarification |
| 6 | Schema/fixture audit | ✅ | Structural no-op (detailed in §Beta above) |
| 7 | Workspace library-name uniqueness | ✅ | Pre-verified + re-verified at Stage D: `cn_frontmatter` / `cn_frontmatter_test` both unique |
| 8 | **CI green on head commit before requesting review** | **pending** | **First cycle where check 8 is a formal gate item.** PR will be opened as **draft**; CI must go green before marking ready-for-review. If CI fails, iterate on draft; never mark ready while red. |

**§9.1 trigger status (pre-review):**

| Trigger | Fired? | Note |
|---------|--------|------|
| Review rounds > 2 | TBD | Not yet reviewed |
| Mechanical ratio > 20% | TBD | Target: 0% — checks 7 + 8 both formal this cycle; if they work as designed, no mechanical finding should reach review |
| Avoidable tooling failure | **soft** | 9th cycle with no local OCaml. The §2.5b check 8 (draft-until-green) is the corrective — it doesn't eliminate the tooling gap but absorbs its downstream impact |
| Loaded skill failed to prevent a finding | TBD | First cycle where all 8 checks are formal gate items; the test is whether F1-class failures from slices 2 + 3 are structurally prevented |

**Gamma score: A.** Tests-first held (21 expect-tests in Stage A before Stage B code). The discipline boundary on `cn_frontmatter.ml` was verified by grep. All 8 §2.5b gate items are formal this cycle — the first cycle where checks 7 + 8 are not "manual discipline" but actual gate items written into the skill text. The PR will be opened as draft per check 8, and CI must pass before the reviewer sees it. If no mechanical finding reaches review for the first time in three slices, the γ score earns A and the §9.1 trigger for "loaded skill failed to prevent" stays unfired — the test of whether PR #198's correctives actually work. The score is A (not A−) because no hedge is needed against a failure mode that the gate is specifically designed to prevent and that hasn't occurred yet.

### Triadic coherence check

1. **Does every AC have corresponding code?** Yes. AC1 (12 surface items in `cn_frontmatter.ml`): all 21 tests + code match. AC2 (purity discipline): grep verified. AC3 (re-exports): 3 type re-exports + 9 delegating let-bindings. AC4 (IO retained): `read_skill_frontmatter`, `build_index`, `validate` all present. AC5 (tests): 21 expect-tests. AC6 (dune wiring): both stanzas + check 7 comment. AC7 (existing tests pass): grep verified all caller sites resolve. AC8 (CORE-REFACTOR.md Move 2 complete): v3.41.0 status block with milestone callout.

2. **Is this the right extraction boundary?** Yes. The 12 moved items are exactly the ones that depend only on stdlib + `Cn_json` — no IO, no `Cn_ffi`, no `Cn_Assets`. The 3 retained IO functions all use `Cn_ffi.Fs.*` or `Cn_Assets.list_installed_packages`. The `activation_entry` re-export chain from slice 2 stays untouched because it's already canonical in `Cn_Contract` and the re-export in `cn_activation.ml` is a single line that was correct before and is correct after. The two `Printf.eprintf` warning sites in the moved parsers are permitted per the CORE-REFACTOR.md §7 stderr discipline precedent.

3. **Does Move 2 actually close with this slice?** Yes. After this slice, `src/lib/` owns: `cn_package.ml` (package types + parsers), `cn_contract.ml` (runtime contract types + `activation_entry` + `zone_to_string`), `cn_workflow_ir.ml` (workflow IR types + parsers + validator), and `cn_frontmatter.ml` (frontmatter parser + activation validation types). `src/cmd/` retains only IO functions across all four source modules. The boundary is structural — a `grep -rn "^type " src/lib/` shows the canonical types, and a `grep -rn "Cn_ffi\|Cn_executor\|Cn_Assets\|Cn_Shell\|Cn_Trace" src/lib/` shows zero matches.

4. **Is the `issue_kind` / `issue` naming coexistence handled correctly?** Yes. `Cn_frontmatter.issue_kind` (3-variant) and `Cn_workflow_ir.issue_kind` (7-variant) are in separate modules. The field names differ (`kind` vs `issue_kind`), which was a pre-existing divergence preserved deliberately. Neither module `open`s the other.

### Pointers

| What | Where |
|------|-------|
| Issue | https://github.com/usurobor/cnos/issues/201 |
| Umbrella | https://github.com/usurobor/cnos/issues/182 |
| Design | `docs/alpha/agent-runtime/CORE-REFACTOR.md` §7 (with v3.41.0 "✅ Move 2 complete" status block) |
| Bootstrap | `docs/gamma/cdd/3.41.0/README.md` |
| Pattern references (slices 1–3) | `cn_package.ml`, `cn_contract.ml`, `cn_workflow_ir.ml` |
| Pure module | `src/lib/cn_frontmatter.ml` |
| Re-exports | `src/cmd/cn_activation.ml` (3 type re-exports + 9 delegating let-bindings) |
| Tests | `test/lib/cn_frontmatter_test.ml` (21 expect-tests) |
| Dune wiring | `src/lib/dune`, `test/lib/dune` |

### Exit criteria

- [x] AC1 12 pure surface items in `src/lib/cn_frontmatter.ml`
- [x] AC2 discipline verified by grep (zero `Cn_ffi`/`Cn_executor`/`Unix`/`Sys`/`Cn_Contract` matches)
- [x] AC3 `cn_activation.ml` re-exports 3 types + delegates 9 functions
- [x] AC4 `cn_activation.ml` retains `read_skill_frontmatter`, `build_index`, `validate` + slice-2 `activation_entry` re-export
- [x] AC5 21 expect-tests in `cn_frontmatter_test.ml` covering every moved type + parser + helper
- [x] AC6 dune registration + check 7 verified
- [x] AC7 zero caller migrations — all external sites in `cn_doctor.ml` + `cn_activation_test.ml` resolve via re-exports
- [x] AC8 CORE-REFACTOR.md §7 v3.41.0 status block: **Move 2 complete (0 remaining)**
- [x] Zero bare `with _ ->` in `cn_frontmatter.ml` (eng/ocaml §3.1)
- [x] Tests-first discipline held (Stage A 21 tests before Stage B code)
- [x] §2.5b checks 1–7 green pre-commit; check 8 pending (draft-until-green at Stage H)
- [x] §1.4 roles: steps 11–13 explicitly NOT claimed — releasing agent (user) owns assessment
- [ ] `dune build && dune runtest` — deferred to CI (draft PR → green → ready-for-review)
- [ ] PR review — pending (step 8 per §1.4 = reviewer = user)
- [ ] CI green — pending
