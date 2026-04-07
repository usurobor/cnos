## CDD Bootstrap — v3.35.0 (#173 slice)

**Issue:** #173 — Runtime contract: activation index + command/orchestrator registry
**Parent:** #170 (orchestrator + command provider model)
**Branch:** claude/173-runtime-contract-activation
**Design:** docs/alpha/agent-runtime/ORCHESTRATORS.md §4
**Mode:** MCA
**Level:** L6 — cross-surface change (runtime contract + package metadata + doctor), no boundary moved
**Active skills:** cdd, eng/ocaml, eng/testing

### Gap

The runtime contract emits identity, cognition, body, and medium at every wake, but the agent wakes up knowing only:

- which packages are installed (no per-skill activation metadata)
- which capability ops the body has (no command or orchestrator registry)

The agent has no explicit knowledge of which skills it can pull in, what triggers should activate them, or which executable surfaces (commands, orchestrators) are available without scanning the filesystem at wake time. ORCHESTRATORS.md §4 specifies the surface; the implementation does not yet exist.

### What fails if skipped

The agent reasons from hidden prompt conventions instead of explicit declarative metadata. Skill activation becomes vague keyword matching (ORCHESTRATORS.md §1 ¶3 risk). Commands and orchestrators stay dispatchable but invisible at wake.

### Acceptance Criteria

- **AC1** Cognition contains an `activation_index` built from installed packages' exposed skills.
- **AC2** Skill activation metadata is read from SKILL.md frontmatter; the `triggers` field is the minimum required surface for v1.
- **AC3** Body contains a `commands` registry (from installed packages + repo-local), reusing `Cn_command.discover`.
- **AC4** Body contains an `orchestrators` registry sourced from each package's `cn.package.json` `sources.orchestrators` (may be `[]` per package; the field must always exist).
- **AC5** `cn doctor` validates the activation surface: missing SKILL.md, missing/empty `triggers` frontmatter, conflicting trigger keywords across exposed skills.
- **AC6** Existing runtime contract tests are updated; new tests cover frontmatter parsing, index building, doctor checks, and JSON/markdown rendering.

### Design

Three new surfaces wired into the existing runtime contract structure:

1. **`cognition.activation_index`** — built by walking installed packages, intersecting `sources.skills` from each `cn.package.json` with on-disk SKILL.md files, parsing each SKILL.md frontmatter with a line-based YAML subset reader (no library dependency), and emitting `{id, package, summary, triggers}` per exposed skill. Sub-skills not listed in the manifest are excluded.

2. **`body.commands`** — reuses `Cn_command.discover ~hub_path` (#167 surface) and projects to `{name, source, package, summary}` records. Repo-local commands carry `package = None`; package commands carry the owning package name.

3. **`body.orchestrators`** — reads `sources.orchestrators` from each installed package's manifest. v1 schema for an entry: `{name, source, package, trigger_kinds}`. Empty per-package list is the expected default until cnos.pm or another package ships orchestrators.

A new module `src/cmd/cn_activation.ml` owns frontmatter parsing and the activation index builder. Keeping it separate from `cn_runtime_contract.ml` follows §2.3 module structure (pure parser + builder; the contract module is the wiring layer).

Doctor checks attach to the existing `Cn_doctor.run_doctor` after `Cn_command.validate`, surfaced as warnings (missing/empty triggers) and errors (conflicting trigger keywords).

### Plan (stage index)

| Stage | Scope |
|-------|-------|
| A | Tests-first: ppx_expect coverage for frontmatter parser, activation builder, doctor validators, and contract JSON shape |
| B | Implement `cn_activation.ml` (frontmatter parser + builder), wire `commands_registry` + `orchestrators_registry` builders into `cn_runtime_contract.ml`, extend `gather` and the renderers |
| C | Doctor: missing SKILL.md / empty triggers / conflicting triggers checks |
| D | `cn build` → run `dune build && dune runtest` → commit → push → PR |

Full plan in `PLAN-runtime-activation.md`.

### Impact Graph

**Touched modules:**
- `src/cmd/cn_activation.ml` — new
- `src/cmd/cn_runtime_contract.ml` — types extended, gather + renderers updated
- `src/cmd/cn_doctor.ml` — activation validation added
- `src/cmd/dune` — new module declared

**Touched docs:**
- `docs/alpha/agent-runtime/ORCHESTRATORS.md` — already canonical, not edited
- `docs/gamma/cdd/3.35.0/` — bootstrap (this dir)

**Touched tests:**
- `test/cmd/cn_activation_test.ml` — new
- `test/cmd/cn_runtime_contract_test.ml` — new tests for activation/registry shape
- `test/cmd/cn_command_test.ml` — unchanged (commands surface reused as-is)
- `test/cmd/dune` — register new module

**Untouched (verified by spec):**
- `cn_command.ml` — discover/validate consumed as-is, no edits
- `cn_deps.ml` — package install path unchanged
- Runtime extensions, lockfile, package index — unrelated

### CDD Trace

| Step | Artifact | Skills loaded | Decision |
|------|----------|---------------|----------|
| 0 Observe | #173 + ORCHESTRATORS.md §4 | cdd | Runtime contract is missing the activation surface specified by §4 |
| 1 Select | #173 | cdd | L6 cross-surface; no boundary move; depends on #167 (shipped) |
| 2 Design | ORCHESTRATORS.md §4 + this README | cdd, design | New module `cn_activation.ml`; reuse `Cn_command.discover`; line-based YAML subset parser |
| 3 Contract | README ACs (this file) | cdd | 6 ACs derived from #173 |
| 4 Plan | `PLAN-runtime-activation.md` | cdd | Tests-first per §2.5a handoff; A → B → C → D |
| 5 Code | `cn_activation.ml`, `cn_runtime_contract.ml`, `cn_doctor.ml` | eng/ocaml | After tests |
| 6 Self-coherence | `SELF-COHERENCE.md` | cdd | Written after implementation completes |
| 7 Review | PR | cdd/review | After CI green |
| 8 Release | next release train | cdd/release | After review |
| 9 Assessment | post-release | cdd/post-release | After release |
