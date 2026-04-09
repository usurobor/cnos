## CDD Bootstrap — v3.37.0 (#184)

**Issue:** #184 — Command pipeline symmetry: commands through `src/agent/` → `cn build` → `packages/`
**Parent umbrella:** #182 (core refactor — this is Move 1 of the immediate execution slice)
**Design:** `docs/alpha/agent-runtime/CORE-REFACTOR.md` §2 + §7 "Move 1"
**Branch:** `claude/184-command-pipeline-symmetry`
**Mode:** MCA
**Level:** L6 — cross-surface (build pipeline, package manifest, CLI dispatch, docs)
**Active skills loaded before code:** cdd, eng/ocaml (§3.1: no bare `with _ ->`, Result types), eng/testing (ppx_expect for each touched module)

### Gap

Commands are the only content class that bypasses the standard
`src/agent/` → `cn build` → `packages/` pipeline. All other six
content classes (doctrine, mindsets, skills, extensions, templates,
orchestrators) are authored in `src/agent/<class>/`, built into
`packages/<name>/<class>/` by `cn build`, and installed into
`.cn/vendor/packages/<name>@<version>/<class>/` by `cn deps restore`.

Commands are instead either:
- **hardcoded as built-in dispatch cases** in `cn.ml` / `cn_lib.ml`
  (`Daily`, `Weekly`, `Save`, plus a wider set of operational
  built-ins), or
- **authored directly in `packages/<name>/commands/`** and picked up
  by `cn_command.ml`'s discovery — bypassing `cn build` entirely.

This is the biggest structural asymmetry left in the package system
after #167 (content class), #173 (activation index), and #174
(orchestrator runtime). The external command discovery
infrastructure has existed since v3.34.0 (#167) — it just has no
first-party commands flowing through it.

### What fails if skipped

- Every new operator-facing command stays a core code change
- The built-in kernel stays wider than the bootstrap set needs to be
- Commands cannot be tested via the same package build/check pipeline as other content classes
- The "one pipeline for all content classes" promise is broken for this one class
- Move 2 of the core refactor (#182) — pulling pure types into `src/lib/` — is harder to execute while commands remain a special case because the command surface cuts across `cn_lib.ml`, `cn.ml`, and several `cn_*` command modules

### Acceptance Criteria (verbatim from issue)

- [ ] **AC1:** `cn build` copies `src/agent/commands/<id>/` → `packages/cnos.core/commands/<id>/` alongside the existing 6 content classes. `cn build --check` verifies sync. `cn build clean` removes generated command dirs.
- [ ] **AC2:** `packages/cnos.core/cn.package.json` declares `sources.commands` listing the command ids, following the same pattern as `sources.skills`, `sources.orchestrators`, etc.
- [ ] **AC3:** At least three commands migrated from built-in to package commands: `daily`, `weekly`, `save`. Each has an entrypoint script under `src/agent/commands/<id>/cn-<id>` and is discovered at runtime via `cn_command.ml` (existing precedence: built-in > repo-local > vendored package).
- [ ] **AC4:** Built-in dispatch in `cn.ml` no longer handles `daily`, `weekly`, or `save`. These are resolved through external command discovery. `cn_lib.ml` `parse_command` no longer recognizes them as built-in.
- [ ] **AC5:** `cn help` shows both built-in and discovered package commands.
- [ ] **AC6:** `cn doctor` reports command conflicts (already implemented; verify it covers the newly migrated commands).
- [ ] **AC7:** CI passes: `cn build --check` validates command sync alongside other content classes.

### Schema reconciliation (design note)

The `sources.commands` shape must resolve a minor collision between
two pre-existing readers:

- `cn_build.ml` (new this cycle): reads `sources.<class>` as a
  **string array of ids** to drive directory-tree copies. Same shape
  as `sources.skills`, `sources.orchestrators`.
- `cn_command.ml` (pre-existing, from #167 v3.34.0): reads
  `sources.commands` as an **object map** `{id: {entrypoint, summary}}`
  for dispatch metadata. No package previously used this.

AC2 ("string array following `sources.skills` pattern") requires
the array form. CORE-REFACTOR.md §2 independently specifies a
**top-level `commands`** object for per-command metadata — moving
the entrypoint/summary out of `sources.commands` into a top-level
field. This is cleaner and matches the orchestrators pattern from
#174 (where per-orchestrator metadata lives in the
`orchestrator.json` file rather than inline in the manifest).

**Resolution for this cycle:**
- `sources.commands` becomes a **string array of ids** (AC2)
- A new top-level **`commands` object** carries per-command
  metadata (entrypoint, summary)
- `cn_command.ml::parse_package_commands` updated to read from the
  top-level `commands` field instead of `sources.commands`. This is
  a minimal plumbing change (one function, one JSON path) and does
  **not** touch discovery/dispatch logic — respecting the issue's
  non-goal "Changes to `cn_command.ml` discovery/dispatch logic".
  The walk-packages → match-by-name → exec flow is untouched.

### Plan

| Stage | Scope | ACs |
|-------|-------|-----|
| A | Tests first: `cn_build_test` commands content class + `cn_cmd_test` parse_command no longer recognizes daily/weekly/save | AC1, AC4 |
| B | `cn_build.ml` — add `commands` to `source_decl`, `parse_sources`, `build_one`, `check_one`, `clean_package_dir`, summary count | AC1, AC7 |
| C | Shell scripts — `src/agent/commands/{daily,weekly,save}/cn-<id>` + mirror to `packages/cnos.core/commands/` + preserve exec bit | AC3 |
| D | `cnos.core/cn.package.json` — `sources.commands` string array + top-level `commands` object | AC2, AC3 |
| E | `cn_command.ml::parse_package_commands` — read top-level `commands` field (one-function plumbing change) | AC3 |
| F | Remove built-in: `cn_lib.ml` command variant + parse + string_of + help_text; `cn.ml` dispatch; `cn_gtd.ml::run_daily/run_weekly` | AC4, AC5 |
| G | `PACKAGE-SYSTEM.md` §1.1 — commands row updated to note the pipeline is now uniform | AC5 (doc) |
| H | `SELF-COHERENCE.md` + `GATE.md` | — |
| I | §2.5b pre-review gate: rebase onto current main, verify diff, open PR | — |

### Impact Graph

**Touched code:**
- `src/cmd/cn_build.ml` — add commands content class
- `src/cmd/cn_command.ml` — change JSON read path (one function)
- `src/cmd/cn_gtd.ml` — delete `run_daily`, `run_weekly`
- `src/cli/cn.ml` — delete `Daily`, `Weekly`, `Save` dispatch branches
- `src/lib/cn_lib.ml` — delete `Daily`, `Weekly`, `Save` from command variant, `string_of_command`, `parse_command`; update `help_text`

**Touched assets:**
- `src/agent/commands/{daily,weekly,save}/cn-<id>` (new shell scripts)
- `packages/cnos.core/commands/{daily,weekly,save}/cn-<id>` (mirror of above)
- `packages/cnos.core/cn.package.json` — `sources.commands` + top-level `commands`

**Touched tests:**
- `test/cmd/cn_build_test.ml` — commands content class build/check/clean
- `test/cmd/cn_cmd_test.ml` — parse_command no longer recognizes daily/weekly/save
- `test/cmd/cn_command_test.ml` — existing tests still pass; new test verifies top-level `commands` read path

**Touched docs:**
- `docs/alpha/package-system/PACKAGE-SYSTEM.md` §1.1
- `docs/gamma/cdd/3.37.0/` (this dir)

**Untouched (non-goals):**
- `cn_command.ml` discovery/dispatch logic — unchanged (only the JSON read path in `parse_package_commands` adjusts)
- `commit`, `push`, `peer`, `send`, `reply` — remain built-in (explicit non-goal per issue)
- `src/core/` or `src/runtime/` extraction — that is Move 2
- Package roles, policy differentiation
- Runtime extensions, low-level A2A transport

### CDD Trace

| Step | Artifact | Skills loaded | Decision |
|------|----------|---------------|----------|
| 0 Observe | #184 + CORE-REFACTOR.md §2 §7 + `cn_build.ml` + `cn_command.ml` + `cn_gtd.ml` daily/weekly + `cn_lib.ml`/`cn.ml` Daily/Weekly/Save | cdd, post-release (v3.36.0 assessment just landed) | The pipeline asymmetry is the biggest structural gap left after #174 |
| 1 Select | #184 | cdd | L6 cross-surface, self-contained (issue is ready-to-pick), depends on nothing new |
| 2 Branch | `claude/184-command-pipeline-symmetry` | — | created from current main (9d27558 + refactor docs) |
| 3 Bootstrap | `docs/gamma/cdd/3.37.0/` | — | this file + PLAN inline in §Plan table + SELF-COHERENCE + GATE later |
| 4 Gap | this file §Gap | cdd | Commands bypass the standard pipeline; remove the exception |
| 5 Mode | this file §Level + §Active skills | cdd, eng/ocaml, eng/testing | MCA, L6, work shape "cross-surface pipeline", skills loaded-and-read-before-code |
| 6 Artifacts | tests → code → docs → self-coherence | eng/ocaml, eng/testing | Stage A tests precede Stage B code (per §2.5 artifact order) |
| 7 Self-coherence | `SELF-COHERENCE.md` (end of cycle) | cdd | Written after Stages A–G complete |
| 7a Pre-review | §2.5b gate check | cdd | Rebase onto current main, CDD Trace in PR body, tests reference ACs, debt explicit |
| 8 Review | PR body | cdd/review | Pending |
| 9 Gate | `GATE.md` | cdd/release | HOLD until CI + review converge |
| 10 Release | — | — | Next release train |
