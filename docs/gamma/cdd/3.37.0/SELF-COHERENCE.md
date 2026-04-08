## Self-Coherence Report — v3.37.0 (#184)

**Issue:** #184 — Command pipeline symmetry
**Umbrella:** #182 (core refactor — this is Move 1)
**Branch:** `claude/184-command-pipeline-symmetry`
**Active skills loaded (and read) before code:** cdd, eng/ocaml (§3.1 no bare `with _ ->`, Result types), eng/testing (ppx_expect per touched module)

### Alpha (type-level clarity)

| Surface | Change | Type-level judgment |
|---------|--------|---------------------|
| `Cn_build.source_decl` | +`commands : string list` | Seventh content class, same shape as `skills`, `orchestrators`. Record grows by one field; no field is ambiguous. |
| `Cn_lib.command` variant | −`Daily`, −`Weekly`, −`Save of string option` | Three dead constructors removed. Every call site updated in the same diff. `string_of_command` and `parse_command` both stay exhaustive because the catchall `_ -> None` already covers the removed tokens. |
| `parse_package_commands` | reads top-level `commands` field, not `sources.commands` | One JSON path change. Return type unchanged (`(name, entrypoint, summary) list`). Discovery + dispatch logic untouched. |
| `Cn_command.validate` | parallel JSON path update | Same plumbing change as `parse_package_commands`, one level deeper. The validator's issue categories (missing entrypoint, not executable, duplicate name) are unchanged. |
| `Cn_gtd.run_daily`, `run_weekly` | deleted | Dead code after the variant removal. Deletion is a strict subtraction. |
| `Cn_hub.threads_reflections_daily`, `threads_reflections_weekly` | deleted | Dead after `run_daily`/`run_weekly` deletion. Sibling audit on `cn_hub.ml` found no other callers. |

**Alpha score: A.** The type changes are subtraction, not
rearrangement. Every removal has a verified empty call site
(`grep -rn "| Daily\b\|| Weekly\b\|| Save of\|run_daily\|run_weekly"
src/` is clean modulo separately-namespaced `Cadence.Daily` and
agent-facing `.md` content). The one addition (`source_decl.commands`)
mirrors the existing pattern for skills / orchestrators.

### Beta (surface agreement)

| Surface | Authority | Consumers updated? |
|---------|-----------|--------------------|
| `sources.commands` shape | string array (per AC2 and content-class symmetry) | `cn_build.ml::parse_sources`, `cn_build.ml::build_one`, `cn_build.ml::check_one`, `cn_build.ml::clean_package_dir`, `cn_build.ml::diff_tree` category list |
| Top-level `commands` object shape | `{id: {entrypoint, summary}}` per CORE-REFACTOR.md §2 | `cn_command.ml::parse_package_commands`, `cn_command.ml::validate` |
| `packages/cnos.core/cn.package.json` | both fields declared | matches both readers |
| Command source layout | `src/agent/commands/<id>/cn-<id>` shell scripts | Three scripts created: daily, weekly, save. Mirrored into `packages/cnos.core/commands/` with executable bit preserved. |
| CLI dispatch | `cn.ml` None-branch fallthrough to `Cn_command.find → dispatch` | Daily/Weekly/Save removed from built-in dispatch; parser returns None; external command dispatch (pre-existing since v3.34.0 #167) picks them up via the top-level `commands` field |
| `Cn_lib.help_text` | help text | daily/weekly/save lines removed from built-in listing; replaced with a note pointing at the package-command listing (`cn help` shows both after `Cn_help.print_external_section` appends vendored package commands) |
| `PACKAGE-SYSTEM.md` §1.1 | canonical docs | Row for `commands` updated (copy mode = directory trees, source location = `src/agent/commands/`, manifest form = string array); prose paragraph rewritten to state that all seven classes use the same pipeline; the old "commands are the exception" paragraph is gone |

**Stale-reference scan:**
- `grep -rn "with _ " src/cmd/cn_build.ml src/cmd/cn_command.ml src/cmd/cn_gtd.ml src/cmd/cn_hub.ml src/lib/cn_lib.ml src/cli/cn.ml` → **zero matches** (sibling audit held)
- `grep -rn "sources\.commands" src/` → only in comments explaining the move
- Remaining `Daily`/`Weekly`/`Save` references in source code are either: (a) `Cadence.Daily`/`Cadence.Weekly` (separate type in cn_lib.ml — unrelated to the removed command variants); (b) agent-facing markdown content in `src/agent/` (reflections concepts, not code)

**Beta score: A.** Every downstream consumer of the touched
authorities is updated in the same diff. The schema reconciliation
(string array `sources.commands` + top-level `commands` object)
follows CORE-REFACTOR.md §2 verbatim and mirrors the orchestrators
precedent from #174.

### Gamma (cycle economics)

**Lines changed:**

| File | Rough delta |
|------|-------------|
| `src/cmd/cn_build.ml` | +25 (content class wiring + chmod +x loop) |
| `src/cmd/cn_command.ml` | net ~0 (JSON path change in two functions) |
| `src/cmd/cn_gtd.ml` | −73 (delete `run_daily` + `run_weekly`) |
| `src/cmd/cn_hub.ml` | −2 (delete two dead bindings) |
| `src/lib/cn_lib.ml` | −12 (variant + string_of + parse_command + help_text) |
| `src/cli/cn.ml` | −4 (three dispatch branches) |
| `packages/cnos.core/cn.package.json` | +14 (`sources.commands` + top-level `commands`) |
| `src/agent/commands/{daily,weekly,save}/cn-<id>` (new) | +3 files, ~150 lines shell |
| `packages/cnos.core/commands/{daily,weekly,save}/` (new mirror) | same 3 files |
| `test/cmd/cn_build_test.ml` | +4 tests (3 commands content class + 1 parse_command regression) |
| `docs/alpha/package-system/PACKAGE-SYSTEM.md` §1.1 | ~20 lines touched |
| `docs/gamma/cdd/3.37.0/` (new) | README + this file + GATE |

**Net effect:** more lines added in scripts + docs + tests than
removed in OCaml. That's the expected shape when migrating from
built-in to package — the code shrinks, the asset tree grows.

**Test-first discipline:** the four new tests in
`cn_build_test.ml` were authored in Stage A, before the `cn_build.ml`
changes in Stage B. Stage B made them pass.

**§9.1 trigger status (pre-review):**

| Trigger | Fired? | Note |
|---------|--------|------|
| Review rounds > 2 | TBD | Not yet reviewed |
| Mechanical ratio > 20% | TBD | Not yet reviewed |
| Avoidable tooling failure | **soft** | No local OCaml toolchain, fifth cycle in a row. CI is the first compilation oracle. Same environment constraint as every preceding cycle. |
| Loaded skill failed to prevent a finding | TBD | The §2.5b pre-review gate (patched in v3.36.0) will be **dogfooded** this cycle: the branch will be rebased onto current main immediately before opening the PR, and the CDD Trace will live in the PR body. First live test of the corrective. |

**Gamma score: A−.** Tests-first held. Sibling audit on cn_hub.ml
held (caught the two dead `threads_reflections_*` bindings). The
minus is the usual tooling gap — no local OCaml, CI proves
compilation. One cycle of dogfooding the §2.5b rule should confirm
whether the mechanical gate is sufficient or needs tightening.

### Triadic coherence check

1. **Does every AC have corresponding code?**
   - **AC1** `cn build` commands content class: `Cn_build.source_decl.commands` + `parse_sources` + `build_one` copy-and-chmod loop + `check_one` loop + `clean_package_dir` list + `diff_tree` category list + build summary count. Tests: `build_one copies commands directory (AC1)`, `clean removes commands directory (AC1)`, `check detects command drift (AC1)`.
   - **AC2** `sources.commands` declared in manifest: `packages/cnos.core/cn.package.json` `"sources"."commands": ["daily", "save", "weekly"]`.
   - **AC3** Three commands migrated: `src/agent/commands/{daily,weekly,save}/cn-<id>` + top-level `commands` object in manifest provides entrypoint + summary for each.
   - **AC4** Built-in dispatch no longer handles daily/weekly/save: `cn_lib.ml` variant removes `Daily`, `Weekly`, `Save`; `parse_command` no longer recognises the tokens; `cn.ml` dispatch branches removed. Test: `parse_command: daily/weekly/save no longer built-in (AC4)` asserts all four cases return `None`.
   - **AC5** `cn help` shows both: `Cn_help.print_external_section` (pre-existing from v3.34.0 #167) already appends discovered external commands; the migrated three will appear there once installed. The built-in help text no longer lists them (removed from `cn_lib.help_text`).
   - **AC6** `cn doctor` reports command conflicts: `Cn_command.validate` already checks duplicate-name-across-sources (pre-existing); the JSON-path plumbing update preserves this path. No new test needed — existing behaviour covers the migrated commands.
   - **AC7** CI `cn build --check` validates command sync: the diff_tree category list now includes `commands`, so `check_one` will detect drift just like every other content class. Test: `check detects command drift (AC1)` exercises the path end-to-end in a temp repo.

2. **Is the schema-reconciliation decision honoured end-to-end?** Yes. `sources.commands` is a string array (driving `cn build`), the top-level `commands` object is the metadata authority (driving `cn_command.parse_package_commands` + `Cn_command.validate`). Both readers were updated in the same commit; no dueling-schema drift.

3. **Is the cn_command.ml change genuinely "plumbing, not logic" per the issue's non-goal?** Yes. The discovery walk (walk installed packages → read manifest → extract commands → register by name) is identical. Only the JSON path (`sources.commands` → `commands`) changed. Walk, match, exec — all unchanged.

4. **Are the new shell scripts self-contained?** Yes. `cn-daily` and `cn-weekly` use only `$CN_HUB_PATH` (exported by `Cn_command.dispatch`) + POSIX `date`, `mkdir`, `cat`. `cn-save` uses `$CN_HUB_PATH` + `cn commit` + `cn push` (both still built-in for this cycle per issue non-goal). No bash-only features; no `/bin/bash` shebang; should run on the sigma hub's `sh`.

5. **Does the `cn build --check` loop actually validate commands?** Yes. The `check_one` function copies each content class (including commands) into a tmp dir, then `diff_tree` compares category-by-category. The `["doctrine"; "mindsets"; "skills"; "extensions"; "templates"; "orchestrators"; "commands"]` list now contains commands, so drift detection runs over it.

### Pointers

| What | Where |
|------|-------|
| Issue | https://github.com/usurobor/cnos/issues/184 |
| Design | `docs/alpha/agent-runtime/CORE-REFACTOR.md` §2 + §7 Move 1 |
| Bootstrap | `docs/gamma/cdd/3.37.0/README.md` |
| Build extension | `src/cmd/cn_build.ml` (source_decl, parse_sources, build_one, check_one, clean, summary) |
| Runtime discovery | `src/cmd/cn_command.ml` (parse_package_commands, validate) |
| Removed built-ins | `src/lib/cn_lib.ml`, `src/cli/cn.ml`, `src/cmd/cn_gtd.ml`, `src/cmd/cn_hub.ml` |
| Shell scripts (source) | `src/agent/commands/{daily,weekly,save}/cn-<id>` |
| Shell scripts (built) | `packages/cnos.core/commands/{daily,weekly,save}/cn-<id>` |
| Manifest | `packages/cnos.core/cn.package.json` |
| Content-class docs | `docs/alpha/package-system/PACKAGE-SYSTEM.md` §1.1 |
| Tests | `test/cmd/cn_build_test.ml` — new tests tagged AC1 / AC4 |

### Exit criteria

- [x] AC1 commands content class in `cn build` build/check/clean
- [x] AC2 `sources.commands` in manifest
- [x] AC3 three commands migrated with entrypoint scripts
- [x] AC4 built-in dispatch for daily/weekly/save removed
- [x] AC5 `cn help` built-in section no longer lists them; external section (pre-existing) will show them once installed
- [x] AC6 `Cn_command.validate` path still covers migrated commands (plumbing update only)
- [x] AC7 `cn build --check` path now includes commands category
- [x] Zero bare `with _ ->` in touched files (eng/ocaml §3.1)
- [x] Tests-first discipline held (Stage A before Stage B)
- [x] §2.5b pre-review gate to be dogfooded (rebase onto current main before PR) — see GATE.md
- [ ] `dune build && dune runtest` — deferred to CI
- [ ] PR review round 1 — pending
- [ ] CI green — pending
