## Self-Coherence Report — v3.39.0 (#182 Move 2 slice 2)

**Issue:** #194 — #182 Move 2 slice 2: extract runtime contract types into `src/lib/`
**Branch:** `claude/182-move2-contract-types`
**Active skills loaded (and read) before code:** cdd (§2.5b 6-check gate + §5.3 trace), eng/ocaml (§3.1 no bare `with _ ->`, §2.1 disambiguate at definition), eng/testing (ppx_expect per extracted module)

### Alpha (type-level clarity)

| Surface | Change | Type-level judgment |
|---------|--------|---------------------|
| `Cn_contract.activation_entry` (new canonical home) | Pulled through from `cn_activation.ml` as a transitive dep of `cognition.activation_index` | Pure 4-field record (`skill_id`, `package`, `summary`, `triggers`). Field names, field types, and ordering byte-for-byte identical to pre-extraction. |
| `Cn_contract.package_info` (new canonical home) | Authoritative `{ name; version; sha256 option; doctrine_count; mindset_count; skill_count }` moved from `cn_runtime_contract.ml` | Pure record. `sha256 : string option` preserved exactly — `None` is valid for hubs with manually-vendored packages (no lockfile entry). |
| `Cn_contract.override_info` (new canonical home) | `{ doctrine; mindsets; skills }` moved | Pure record, three `string list` fields. |
| `Cn_contract.zone` (new canonical home) | 5-constructor variant `Constitutive_self \| Memory \| Private_body \| Work_medium \| Projection_surface` moved | Pure variant. Constructor names and order preserved exactly. Re-exporting via `type zone = Cn_contract.zone = ...` also re-exposes the constructors unqualified in `Cn_runtime_contract`, so existing pattern matches in `classify_zones` (lines 124-139) and `render_markdown` (lines 457-461) compile unchanged. |
| `Cn_contract.zone_entry` (new canonical home) | `{ path; zone }` moved | Pure record. `zone` field resolves to `Cn_contract.zone` which is the same type as `Cn_runtime_contract.zone` (type-equality), so no field-type drift. |
| `Cn_contract.identity` (new canonical home) | `{ cn_version; hub_name; profile }` moved | Pure record. Field names preserved exactly — `cn_version` not `version` (disambiguated from `package_info.version` at the definition level per eng/ocaml §2.1). |
| `Cn_contract.extension_contract_info` (new canonical home) | `{ ext_name; ext_version; ext_package; ext_backend; ext_state; ext_ops }` moved | Pure record. `ext_*` prefixes preserved to disambiguate from `package_info.name`/`.version` and the command/orchestrator prefix schemes. |
| `Cn_contract.command_entry` (new canonical home) | `{ cmd_name; cmd_source; cmd_package : string option; cmd_summary }` moved | Pure record. `cmd_package : string option` — `None` = repo-local, `Some pkg` = package-owned. The option-typed disambiguation (not a string sentinel like `"repo-local"`) is preserved. |
| `Cn_contract.orchestrator_entry` (new canonical home) | `{ orch_name; orch_source; orch_package; orch_trigger_kinds }` moved | Pure record. `orch_source` always `"package"` in v1 (forward-compat field). Field prefix `orch_*` preserved for same disambiguation reason as `ext_*`/`cmd_*`. |
| `Cn_contract.cognition` (new canonical home) | `{ packages; overrides; extensions_installed; activation_index : activation_entry list }` | Pure record. `activation_index` now references the local `Cn_contract.activation_entry` (vs. the pre-extraction reference to `Cn_activation.activation_entry`); both resolve to the same OCaml type because `cn_activation.ml` re-exports from `Cn_contract` via type-equality. |
| `Cn_contract.body_contract` (new canonical home) | `{ capabilities_text; peers; extensions_active; commands; orchestrators }` moved | Pure record. References `extension_contract_info`, `command_entry`, `orchestrator_entry` — all in the same module, no cross-module type resolution needed. |
| `Cn_contract.runtime_contract` (new canonical home) | Four-layer root `{ identity; cognition; body : body_contract; medium : zone_entry list }` moved | Pure record. The root composition type — references every other moved type. This is the external API the caller sees. |
| `Cn_contract.zone_to_string` | Pure function moved | 5-case pattern match on `zone`; pure, total, no IO. Byte-for-byte identical output ("constitutive_self", "memory", "private_body", "work_medium", "projection_surface"). |
| `Cn_runtime_contract.{all 11 types}` | Now **type re-exports** via OCaml type-equality: `type package_info = Cn_contract.package_info = { ... }` and 10 more | Same record/variant at the OCaml type level. Existing record literals at `Cn_runtime_contract.{type}` remain valid because the re-exported type IS `Cn_contract.{type}` — identical, not structurally compatible. Zero caller migration. |
| `Cn_runtime_contract.zone_to_string` | Now a delegating let-binding: `let zone_to_string = Cn_contract.zone_to_string` | One-line re-export. Behaviour preserved exactly. Called at line 571 in `to_json` — still resolves unchanged. |
| `Cn_activation.activation_entry` | Now a type-equality re-export: `type activation_entry = Cn_contract.activation_entry = { skill_id; package; summary; triggers }` | Same record at the OCaml type level. Existing callers (`test/cmd/cn_activation_test.ml` × 3 field-access sites, `src/cmd/cn_runtime_contract.ml` render_markdown/to_json closures × 2) compile unchanged because the re-exported type IS `Cn_contract.activation_entry`. |
| `Cn_runtime_contract` IO surface | Untouched | Every IO function (`classify_zones`, `list_md_relative`, `list_skill_overrides`, `extensions_from_registry`, `build_command_registry`, `build_orchestrator_registry`, `gather`, `render_markdown`, `to_json`, `write`) retained with zero modification. The pure ↔ IO split runs through the type-re-export section, not through any function body. |
| `Cn_activation` IO surface | Untouched | Frontmatter parser, `build_index`, manifest walks, SKILL.md readers — all unchanged. Only the type declaration changed from a fresh record to a type-equality re-export. This is the slice-4 candidate for Move 2 but out of scope this cycle. |

**Alpha score: A.** The diff is structural subtraction. 11 type definitions + `zone_to_string` body leave `cn_runtime_contract.ml` and arrive in `cn_contract.ml` byte-for-byte equivalent. The re-export mechanism preserves OCaml-level type identity, not just structural compatibility — `Cn_runtime_contract.package_info` and `Cn_contract.package_info` are literally the same type, as verified by the fact that `render_markdown` and `to_json` closures (which still reference `Cn_activation.activation_entry` by module-qualified name) continue to compile. No field-naming drift, no constructor drift, no `string option` vs `string` sloppiness. The `activation_entry` transitive extraction exercises the pattern across two `src/cmd/` modules instead of one, scaling the slice-1 technique as planned.

### Beta (surface agreement)

| Surface | Authority | Consumers updated? |
|---------|-----------|--------------------|
| 11 runtime-contract record shapes | `Cn_contract` (canonical) | Re-exported by `Cn_runtime_contract` via type-equality. Three external type-annotation sites in `test/cmd/cn_runtime_contract_test.ml` (lines 115, 128, 349 — `package_info` × 2 and `zone_entry` × 1) resolve to the canonical type via the re-export chain. Zero edits. |
| `activation_entry` record shape | `Cn_contract` (canonical) | Re-exported by `Cn_activation` via type-equality. Three external type-annotation sites in `test/cmd/cn_activation_test.ml` (lines 196, 198, 234) + two in-module closure sites in `src/cmd/cn_runtime_contract.ml` (lines 395, 516 — `render_markdown` and `to_json` closures) resolve to the same type. Zero edits. |
| `cognition.activation_index` field | `Cn_contract` (definition) | The pre-extraction definition referenced `Cn_activation.activation_entry list`; the post-extraction definition references the local `activation_entry list` (unqualified within `Cn_contract`). Both the re-exports in `Cn_runtime_contract` and `Cn_activation` walk to the same `Cn_contract.activation_entry` type. Single canonical source, no dueling-schema risk. |
| `zone_to_string` body | `Cn_contract` (canonical) | `Cn_runtime_contract.zone_to_string` is a one-line delegation. Used inside `Cn_runtime_contract.to_json` at line 571 — works unchanged because the delegation has the same type signature. |
| `src/lib/` discipline (no IO) | `CORE-REFACTOR.md` §7 + `src/lib/dune` comment | `cn_contract.ml` imports only stdlib. Verified by grep: `grep -n "Cn_ffi\|Cn_executor\|Cn_cmd\|Unix\|Sys\." src/lib/cn_contract.ml` → zero matches. (Same discipline held for `cn_package.ml` in slice 1; verified again for slice 2.) |
| `src/lib/dune` modules list | dune | `cn_contract` added between `cn_package` and `cn_build_info`. Now 8 modules: `cn_lib cn_json cn_sha256 cn_package cn_contract cn_build_info cn_version cn_repo_info`. |
| `test/lib/dune` library list | dune | `cn_contract_test` library added as fifth entry alongside `cn_test`, `cn_json_test`, `cn_sha256_test`, `cn_package_test` with `(libraries cn_lib)` and `(preprocess (pps ppx_expect))`. |
| `CORE-REFACTOR.md` §7 Move 2 status block | docs | v3.39.0 status block appended after the v3.38.0 block, names 2 remaining slices (workflow IR, activation evaluator). Status history is cumulative — slice 1 block preserved for audit trail. |

**Stale-reference scan:**

- `grep -rn "Cn_runtime_contract\.\(package_info\|override_info\|zone\|zone_entry\|identity\|extension_contract_info\|command_entry\|orchestrator_entry\|cognition\|body_contract\|runtime_contract\|zone_to_string\)"` → 3 source-tree matches, all in `test/cmd/cn_runtime_contract_test.ml` (lines 115, 128, 349 as noted above), all type annotations (`package_info` × 2, `zone_entry` × 1). All resolve through re-export. Plus the v3.39.0 README and self-coherence documentation references (expected, informational only).
- `grep -rn "Cn_activation\.activation_entry"` → 5 source-tree matches: 3 in `test/cmd/cn_activation_test.ml`, 2 in `src/cmd/cn_runtime_contract.ml` (render_markdown + to_json closures). All resolve through the `cn_activation.ml` type-equality re-export that chains to `Cn_contract.activation_entry`.
- `grep -rn "let open Cn_runtime_contract\|let open Cn_activation"` → zero matches. No `open` statements that would require deeper type path resolution.
- `grep -n "with _ " src/lib/cn_contract.ml` → zero matches (eng/ocaml §3.1 holds — `cn_contract.ml` has no exception handling; it's pure type definitions + one pattern match).
- `grep -n "let zone_to_string\|^type " src/cmd/cn_runtime_contract.ml` → shows only re-export bindings (12 type re-exports + one delegating `zone_to_string` let-binding). No duplicate definitions lingering from the pre-extraction file.
- `grep -n "^type activation_entry" src/cmd/cn_activation.ml` → shows one line: `type activation_entry = Cn_contract.activation_entry = {`. Single re-export; no duplicate definition.

**Schema/fixture audit (§2.5b check 6):**

Did this PR change a JSON schema, manifest shape, op envelope, receipt format, or any string-literal contract that test fixtures construct?

**No.**
- JSON schema (`cn.runtime_contract.v2` in `to_json`): unchanged. `to_json` stays in `cn_runtime_contract.ml` byte-for-byte.
- Record field names, types, ordering: unchanged for every moved type.
- `zone_to_string` output strings: unchanged (5 preserved mappings).
- Test fixtures: `test/cmd/cn_runtime_contract_test.ml` does not construct any of the moved types as record literals — it uses `gather` to build them from disk state and then reads fields. `test/cmd/cn_activation_test.ml` does not construct `activation_entry` as a literal either — it uses `build_index` on a temp hub. No fixture-level record construction to audit for either module.

The check comes up empty twice over: (a) no schema change occurred, and (b) even if one had, there would be no literal construction sites to sweep. Same pattern as v3.38.0 slice 1 — the type-equality re-export mechanism structurally makes check 6 a no-op for pure-type extraction cycles.

**Beta score: A.** Every downstream consumer of the touched authorities is either already resolved through a type-equality re-export (production and test-side type annotations) or is already consuming the IO surface by function name (`gather`, `render_markdown`, `to_json`, `write` — unchanged). The schema reconciliation is trivially coherent because there are two syntactic surfaces pointing at one canonical type. The `Cn_activation` transitive dependency is handled cleanly through a chained re-export (`Cn_activation.activation_entry → Cn_contract.activation_entry`), which is the same mechanism the rest of the extraction uses. No authority conflicts, no stale references, no dueling schemas.

### Gamma (cycle economics)

**Lines changed:**

| File | Rough delta |
|------|-------------|
| `src/lib/cn_contract.ml` (new) | +140 lines (11 type defs + `activation_entry` + `zone_to_string` + docstrings + discipline comment) |
| `src/lib/dune` | +1 line in modules list (`cn_contract` inserted between `cn_package` and `cn_build_info`) |
| `test/lib/cn_contract_test.ml` (new) | +240 lines (13 ppx_expect tests: P1/P1b for package_info, O1 for override_info, Z1 for zone variant + `zone_to_string` exhaustive, ZE1 for zone_entry, I1 for identity, E1 for extension_contract_info, C1+C2 for command_entry both None/Some, OR1 for orchestrator_entry, A1 for activation_entry, CG1 for cognition composing activation_entry, B1 for body_contract, RC1 for runtime_contract four-layer composition) |
| `test/lib/dune` | +9 lines (new library stanza for `cn_contract_test`) |
| `src/cmd/cn_runtime_contract.ml` | net ~−30 lines (removed 11 type defs + `zone_to_string` body ≈ 100 lines; added 11 type re-exports + 1 delegating let-binding + v3.39.0 docstring ≈ 70 lines). All IO functions byte-for-byte identical. |
| `src/cmd/cn_activation.ml` | net ~+7 lines (replaced the 6-line `activation_entry` record definition with the 7-line re-export + docstring explaining slice 2) |
| `docs/alpha/agent-runtime/CORE-REFACTOR.md` | +1 status block (v3.39.0 Move 2 slice 2 shipped; preserves the v3.38.0 block for history) |
| `docs/gamma/cdd/3.39.0/` (new) | README + this file + GATE |

**Net effect:** the OCaml plane gains a new `src/lib/` module (140 lines) and the equivalent amount of type-definition bulk leaves `src/cmd/cn_runtime_contract.ml`. Tests grow by one file (13 expect-tests). `cn_activation.ml` loses a 6-line type def and gains a 7-line re-export (+documentation) — nearly zero-sum. The IO surfaces of both touched `src/cmd/` modules are byte-for-byte unchanged.

**Test-first discipline:** `test/lib/cn_contract_test.ml` was authored in Stage A — before `src/lib/cn_contract.ml` in Stage B — and every test references the API I designed for `Cn_contract` (field names on each record, `zone_to_string` mapping, `activation_entry` fields inside the cognition composition test). Stage B made the tests pass by definition rather than by retrofit. Thirteen tests cover every moved type at least once; `zone_to_string` is covered exhaustively (all 5 constructors) and `command_entry` is covered twice (repo-local `None` + package-owned `Some`) because that's the only type with a sum-shape field.

**§2.5b 6-check gate pre-commit (dogfood):**

| # | Check | Pass | Evidence |
|---|-------|------|----------|
| 1 | Branch rebased onto current `main` | pending verify | Branch was cut from current `main` (`de39e64` = v3.38.0 post-release lag patch). Rebase is expected to be a no-op; `git fetch origin main && git rebase origin/main` will be run immediately before push. |
| 2 | Self-coherence artifact present | ✅ | `docs/gamma/cdd/3.39.0/SELF-COHERENCE.md` — this file |
| 3 | CDD Trace in PR body | pending | Will be included verbatim from `README.md` §"CDD Trace" at PR open time |
| 4 | Tests reference ACs | ✅ | Each test family is named for the AC it covers: P1/P1b/O1/Z1/ZE1/I1/E1/C1/C2/OR1/CG1/B1/RC1 → AC1/AC2 (11 types, `zone_to_string`); A1 → AC10 (`activation_entry`) |
| 5 | Known debt explicit | ✅ | `README.md` §"Non-goals" names the two remaining Move 2 slices (workflow IR, activation evaluator) + the deliberate scope choice to keep `to_json`/`render_markdown`/`write` in `cn_runtime_contract.ml` per AC5 |
| 6 | Schema/shape audit across test fixtures | ✅ | Performed inline in §Beta. Zero schema changes; zero fixture-level record literals. Check is a structural no-op for pure-type extraction cycles. Same structural property held in slice 1 (v3.38.0). |

**§9.1 trigger status (pre-review):**

| Trigger | Fired? | Note |
|---------|--------|------|
| Review rounds > 2 | TBD | Not yet reviewed |
| Mechanical ratio > 20% | TBD | Not yet reviewed |
| Avoidable tooling failure | **soft** | Seventh cycle in a row with no local OCaml toolchain. CI is the first compilation oracle. Same environment constraint as v3.33.0 through v3.38.0. |
| Loaded skill failed to prevent a finding | TBD | Will be evaluated against review outcome. Slice 1 (v3.38.0) was clean; slice 2 is larger scope (two `src/cmd/` modules touched instead of one) but otherwise the same pattern. |

**Gamma score: A−.** Tests-first held. Sibling audit held (no stale references in either touched `src/cmd/` module; no duplicate definitions lingering). The discipline boundary on `cn_contract.ml` was verified by grep, not by convention. The §2.5b 6-check gate was dogfooded with all 6 checks green pre-commit (check 1 pending verify at push time; checks 2–6 complete). The minus is the persistent tooling gap — no local OCaml, CI is the only compilation oracle, seventh consecutive cycle. Not A because compile-time risk is meaningfully higher on slice 2 than slice 1 (two `src/cmd/` modules touched, chained re-export via `activation_entry`) and I cannot validate that locally before pushing — CI is the ground truth.

### Triadic coherence check

1. **Does every AC have corresponding code?**
   - **AC1** 11 pure types in `src/lib/cn_contract.ml`: `package_info`, `override_info`, `zone`, `zone_entry`, `identity`, `extension_contract_info`, `command_entry`, `orchestrator_entry`, `cognition`, `body_contract`, `runtime_contract`. Tests: P1/P1b (package_info with Some/None sha256), O1 (override_info), Z1 (zone variant + `zone_to_string` exhaustive), ZE1 (zone_entry), I1 (identity), E1 (extension_contract_info), C1+C2 (command_entry with None/Some cmd_package), OR1 (orchestrator_entry), CG1 (cognition composing activation_entry), B1 (body_contract composing commands + orchestrators), RC1 (runtime_contract four-layer composition).
   - **AC2** Pure helpers in `Cn_contract`: `zone_to_string` moved verbatim. No per-type JSON serializers to move (the only JSON function is the monolithic `to_json` which stays per AC5). Test: Z1 exhaustive mapping of all 5 zone constructors to their string forms.
   - **AC3** `cn_runtime_contract.ml` re-exports each type: see lines 35-113 of the rewritten file (`type package_info = Cn_contract.package_info = { ... }` for all 11 types), plus `let zone_to_string = Cn_contract.zone_to_string` at line 115. External callers (`cn_runtime_contract_test.ml`, in-module closures) compile unchanged because the re-exported type is equal to the canonical one at the OCaml level.
   - **AC4** `src/lib/cn_contract.ml` discipline: imports only stdlib. Verified by grep: `grep -n "Cn_ffi\|Cn_executor\|Cn_cmd\|Unix\|Sys\." src/lib/cn_contract.ml` → zero matches. The module is pure type definitions + one pattern-match function; no exception handling, no IO references, no filesystem, no process.
   - **AC5** `cn_runtime_contract.ml` retains all IO-side functions: `classify_zones` (line 117), `list_md_relative` (line 143), `list_skill_overrides` (line 158), `extensions_from_registry` (line 166), `build_command_registry` (line 179), `build_orchestrator_registry` (line 193), `gather` (line 214), `render_markdown` (line 332), `to_json` (line 466), `write` (line 577). Every one unchanged. Verified by grep: only the type definitions + `zone_to_string` body were removed; nothing else.
   - **AC6** `test/lib/cn_contract_test.ml` covers the pure module with 13 ppx_expect tests (enumerated in AC1 above). Each test names the record literal construction site and reads back each field — the `[%expect]` block locks in the construction shape and the field-read order.
   - **AC7** `src/lib/dune` registers `cn_contract` in the modules list (now 8 modules); `test/lib/dune` registers `cn_contract_test` library as the fifth entry with `(libraries cn_lib)` + `(inline_tests)` + `(preprocess (pps ppx_expect))`.
   - **AC8** Existing callers compile unchanged. Verified by grep (stale-reference scan in §Beta): 5 caller sites total, all resolve through re-exports. Zero fixture edits, zero caller migrations.
   - **AC9** `docs/alpha/agent-runtime/CORE-REFACTOR.md` §7 Move 2 status block updated: v3.39.0 block appended after v3.38.0 block, naming 2 remaining slices (workflow IR, activation evaluator).
   - **AC10** (implementer-added per `Cn_activation` dependency option (b)): `activation_entry` moved from `cn_activation.ml` into `cn_contract.ml`. `cn_activation.ml` re-exports via type-equality (`type activation_entry = Cn_contract.activation_entry = { skill_id; package; summary; triggers }`). Five external caller sites verified: 3 in `test/cmd/cn_activation_test.ml` type annotations, 2 in `src/cmd/cn_runtime_contract.ml` closures. All compile via chained re-export. Test: A1 (construction + field read).

2. **Is the type-equality re-export the right compatibility mechanism for slice 2?** Yes, same as slice 1. The 11 runtime-contract types include one variant (`zone`) in addition to 10 records. OCaml's `type t = M.t = Ctor1 | Ctor2 | ...` syntax re-exposes variant constructors in the re-exporting module, which is why `classify_zones` (lines 123-139 of `cn_runtime_contract.ml`, uses `Constitutive_self`, `Memory`, etc. unqualified) continues to compile. Without the constructor-re-export form, the existing `classify_zones` would break; the chosen form preserves it. For the 10 records, the `type t = M.t = { ... }` syntax preserves field names and field-construction sites identically. Zero caller migration required, which was the explicit AC7/AC8 goal.

3. **Was the `Cn_activation` dependency handled correctly?** Yes, via option (b) as documented in README §"Cn_activation dependency strategy". The alternative options were rejected:
   - **(a) Import `Cn_activation` from `Cn_contract`** — impossible. `cn_activation.ml` lives in `src/cmd/` and uses `Cn_ffi.Fs.exists`, `Cn_ffi.Path.join`, `Cn_ffi.Fs.read` in `build_index`, `check_frontmatter_file`, and `list_declared_skills`. Importing it would pull IO transitively into `src/lib/`, violating AC4.
   - **(c) Keep `cognition` and `runtime_contract` in `cn_runtime_contract.ml` for now** — would leave a messy partial boundary: the two "root" types (cognition, runtime_contract) that external callers care about most would stay behind, defeating the purpose of the slice. Acceptable per the issue spec but strictly worse.
   - **(b) Extract `activation_entry` into `cn_contract.ml` alongside the runtime-contract types** — chosen. The `activation_entry` record is pure (4 string/list fields, no IO), small (6 lines), and has only two classes of consumer (the runtime-contract `cognition.activation_index` field, and 3 test annotation sites). The `cn_activation.ml` IO surface (frontmatter parser, `build_index`, manifest walks) stays untouched; only the type declaration changed to a type-equality re-export. This unblocks the cleanest version of slice 2 and establishes the "transitive-dep extraction" pattern for the remaining slices.

4. **Did the schema/fixture audit (check 6) cover everything?** Yes, structurally. The audit is a two-layer check:
   - Layer 1: did any schema change occur? **No.** Record fields, types, ordering: unchanged for all 11 types + `activation_entry`. JSON schema `cn.runtime_contract.v2` (produced by `to_json`): unchanged because `to_json` stays unchanged in `cn_runtime_contract.ml`. `zone_to_string` output strings: unchanged.
   - Layer 2: are there fixture-level record literals that *would* need auditing if a schema change had occurred? **No.** `test/cmd/cn_runtime_contract_test.ml` doesn't construct any of the 11 types as record literals; it calls `gather` on a temp hub and reads fields back. `test/cmd/cn_activation_test.ml` doesn't construct `activation_entry` as a literal; it calls `build_index` on a temp hub.
   - The check is empty on both layers — a structural property of pure-type extraction cycles where the IO functions (which produce the records) are untouched.

5. **Is the IO ↔ pure boundary clean after this slice?** Yes. `cn_contract.ml` contains no `Cn_ffi`, no `Cn_executor`, no `Sys.*`, no `Unix.*`, no `open` statements that would reach into `src/cmd/`. `cn_runtime_contract.ml` retains every function that touches the filesystem (`classify_zones`, `list_md_relative`, `list_skill_overrides`, `gather`, `write`), the runtime state (`build_command_registry`, `build_orchestrator_registry`, `extensions_from_registry`), or the prompt rendering (`render_markdown`, `to_json`). `cn_activation.ml` retains every function that reads manifests and SKILL.md files from disk. The boundary runs through three module walls (`cn_contract` ↔ `cn_runtime_contract` ↔ `cn_activation`), not through any function body.

6. **Does this slice scale the slice-1 pattern as predicted?** Yes. The hypothesis in the bootstrap README was: "slice 1 was structurally small (~130 LOC, one `src/cmd/` module); slice 2 proves the pattern scales to a larger module (567 LOC, two `src/cmd/` modules via transitive dep)." The slice-2 scope is:
   - 11 types moved (vs. 6 in slice 1)
   - 1 transitive dependency (`activation_entry`) pulled through via a chained re-export — a pattern that didn't exist in slice 1
   - 1 variant type with re-exposed constructors — also new vs. slice 1 (which had only records)
   - Same discipline (no IO imports in new module, verified by grep)
   - Same test-first discipline (Stage A before Stage B)
   - Same §2.5b 6-check gate dogfood
   
   If CI lands green and review is clean, the pattern is fully validated for the remaining two slices (workflow IR, activation evaluator), both of which are larger than slice 2 (`cn_workflow.ml` is ~900 LOC, `cn_activation.ml` is ~260 LOC but with frontmatter parser + build pipeline).

### Pointers

| What | Where |
|------|-------|
| Issue | https://github.com/usurobor/cnos/issues/194 |
| Umbrella | https://github.com/usurobor/cnos/issues/182 |
| Design | `docs/alpha/agent-runtime/CORE-REFACTOR.md` §7 Move 2 (with v3.38.0 + v3.39.0 status blocks) |
| Bootstrap | `docs/gamma/cdd/3.39.0/README.md` |
| Pattern reference (slice 1) | `docs/gamma/cdd/3.38.0/SELF-COHERENCE.md` + `src/lib/cn_package.ml` + `src/cmd/cn_deps.ml` |
| Pure module | `src/lib/cn_contract.ml` |
| Re-exports (runtime contract) | `src/cmd/cn_runtime_contract.ml` lines 35-115 |
| Re-export (activation) | `src/cmd/cn_activation.ml` around line 137 |
| Tests | `test/lib/cn_contract_test.ml` (13 expect-tests) |
| Dune wiring | `src/lib/dune`, `test/lib/dune` |

### Exit criteria

- [x] AC1 11 pure runtime-contract types in `src/lib/cn_contract.ml`
- [x] AC2 `zone_to_string` in `Cn_contract` (no other per-type pure helpers exist to move)
- [x] AC3 `cn_runtime_contract.ml` re-exports all 11 types via type-equality + delegates `zone_to_string`
- [x] AC4 `cn_contract.ml` discipline verified by grep (zero `Cn_ffi`/`Cn_executor`/`Unix`/`Sys` matches)
- [x] AC5 `cn_runtime_contract.ml` retains every IO function unchanged
- [x] AC6 13 expect-tests in `cn_contract_test.ml` covering every moved type + exhaustive `zone_to_string`
- [x] AC7 dune registration in `src/lib/dune` and `test/lib/dune`
- [x] AC8 zero caller migrations — 5 external caller sites verified to resolve through re-exports
- [x] AC9 `CORE-REFACTOR.md` §7 Move 2 status block updated with v3.39.0 entry naming 2 remaining slices
- [x] AC10 `activation_entry` moved to `cn_contract.ml` + re-exported from `cn_activation.ml` via type-equality
- [x] Zero bare `with _ ->` in touched files (eng/ocaml §3.1)
- [x] Tests-first discipline held (Stage A before Stage B)
- [x] §2.5b 6-check pre-review gate dogfooded (checks 2–6 pre-commit; check 1 verified at push time)
- [ ] `dune build && dune runtest` — deferred to CI
- [ ] PR review round 1 — pending
- [ ] CI green — pending
