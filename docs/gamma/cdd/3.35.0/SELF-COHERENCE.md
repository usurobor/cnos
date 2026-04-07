## Self-Coherence Report — v3.35.0 (#173 slice)

**Issue:** #173 — Runtime contract: activation index + command/orchestrator registry
**Branch:** claude/173-runtime-contract-activation
**Tip:** ca3ad0c
**Active skills loaded (and read) before code:** cdd, eng/ocaml, eng/testing

### Alpha (type-level clarity)

| Surface | Change | Type-level judgment |
|---------|--------|---------------------|
| `Cn_activation.frontmatter` | new record `{fm_name; fm_description; fm_triggers}` | Three optional/list fields, all disambiguated by `fm_` prefix (eng/ocaml §2.1). Parser returns the record by value; no exceptions escape. |
| `Cn_activation.activation_entry` | new record `{skill_id; package; summary; triggers}` | All four fields required; the builder never emits `None` slots. |
| `Cn_activation.issue` + `issue_kind` | new variant with three constructors | One constructor per doctor category; compiler forces doctor dispatch to handle each case. |
| `Cn_runtime_contract.command_entry` | new record | `cmd_package : string option` disambiguates repo-local (`None`) vs package (`Some`). No string-typed "repo-local" sentinel in the package field. |
| `Cn_runtime_contract.orchestrator_entry` | new record | `orch_source` is always `"package"` in v1 — the field is kept for forward-compat (future `repo-local` orchestrators) and noted in PLAN §3. |
| `cognition.activation_index` | record field of `activation_entry list` | Consumed the upstream type from `cn_activation.ml` via module-qualified reference rather than copying the record — single source of truth. |
| `body_contract.{commands, orchestrators}` | two new list fields | Populated by dedicated builders that are called exactly once from `gather`. |

**Alpha score: A.** The frontmatter parser is a pure function with a
bounded output type. The activation builder is a pure walk over the
installed-package set with no exceptions escaping the boundary. The
contract records compose without overlapping field names (all have a
two-letter prefix). No "stringly typed" sentinels.

### Beta (authority surface agreement)

Every surface touched by this change and whether its consumers agree:

| Surface | Authority | Consumers updated? |
|---------|-----------|--------------------|
| SKILL.md frontmatter schema (`name`, `description`, `triggers`) | `Cn_activation.parse_frontmatter` | Only consumer. Inline-list form is explicitly unsupported with a logged warning (PLAN §3 known debt). Existing SKILL.md files in `src/agent/` use block list form; grepped to confirm. |
| `sources.skills` string array | `Cn_activation.manifest_skill_ids` | Reads the same field as `Cn_build.source_decl.skills`. No divergence. |
| `sources.commands` object map | `Cn_command.discover_package` (#167) | Consumed by `build_command_registry` without re-parsing. Single source of truth. |
| `sources.orchestrators` array | `build_orchestrator_registry` | New consumer; schema defined in `ORCHESTRATORS.md` §4.2. No package declares orchestrators yet — first real consumer is this code, expected empty arrays across all installed packages. |
| `Cn_command.external_cmd` | `Cn_command` | Projected to `command_entry` without mutation. The `source` variant is translated via pattern-match, not string compare. |
| JSON schema `cn.runtime_contract.v2` | `Cn_runtime_contract.to_json` | Schema tag unchanged — the new fields are additive under `cognition` and `body`. Downstream readers (agent runtime, tests) already use `Cn_json.get` (tolerant to unknown fields). |
| Markdown prompt surface | `Cn_runtime_contract.render_markdown` | New `Skills:`, `commands:`, `orchestrators:` sections render only when non-empty, so existing packed contexts for hubs without any exposed skills are byte-identical (cache-safe). |
| Doctor surface | `Cn_doctor.run_doctor` | `report_commands` and `report_activation` are factored out; both return a `bool` indicating "should exit 1", aggregated at the end. The pre-change behavior (`Cn_command.validate` causing an exit) is preserved exactly. |

**Stale reference scan:**

- `grep -rn 'with _ ->' src/cmd/cn_activation.ml src/cmd/cn_runtime_contract.ml src/cmd/cn_doctor.ml src/cmd/cn_command.ml` → **0 matches** (three pre-existing catches in `cn_runtime_contract.ml` cleaned up in this diff).
- `grep -rn 'Cn_activation\.' src/ test/` shows every exported symbol of the new module has at least one caller.
- `activation_index` / `build_index` / `build_command_registry` / `build_orchestrator_registry` each appear in exactly one build site plus the renderer + test site — no dangling exports.

**Beta score: A.** Every downstream consumer touched by the change
is updated in the same commit. The JSON schema tag `cn.runtime_contract.v2`
is preserved intact; the additions are pure growth at the
`cognition` and `body` leaves.

### Gamma (cycle economics)

**Lines changed:**

| File | Insertions | Deletions |
|------|------------|-----------|
| `src/cmd/cn_activation.ml` (new) | 236 | 0 |
| `src/cmd/cn_runtime_contract.ml` | 135 | 23 |
| `src/cmd/cn_doctor.ml` | 45 | 9 |
| `src/cmd/dune` | 1 | 1 |
| `test/cmd/cn_activation_test.ml` (new) | 294 | 0 |
| `test/cmd/cn_runtime_contract_test.ml` | 109 | 0 |
| `test/cmd/dune` | 8 | 0 |
| `docs/gamma/cdd/3.35.0/*.md` | 326 | 0 |
| **Total** | **1154** | **23** |

Ratio of code (`src/`) to tests (`test/`) by line count: **417 src
: 411 tests ≈ 1:1**, matching the eng/testing skill's expectation
for a new pure module.

**Cycle iteration triggers (§9.1):**

| Trigger | Fired? | Note |
|---------|--------|------|
| Review rounds > 2 | TBD | PR not yet opened |
| Mechanical ratio > 20% | TBD | Depends on review findings |
| Avoidable tooling failure | **Yes (soft)** | No OCaml toolchain in the authoring sandbox. Same constraint as v3.34.0 #167 cycle. Text-level review covered record exhaustiveness, match parenthesization, module registration, and cross-module references. Documented in README §5. |
| Loaded skill failed to prevent a finding | TBD | Depends on review; baseline is "skills were loaded and read before writing" — the explicit corrective from the v3.34.0 post-release. |

**Gamma score: A−.** Test-first discipline held: every production
function has at least one expect test, the three new record fields
are each asserted in a JSON-shape test, and the frontmatter parser
has five tests covering the four cases specified in the handoff.
The minus is the tooling gap — dune build did not run locally. This
is a known environment constraint, not a process gap, but it is
honest to withhold the A until CI confirms compilation.

### Triadic Coherence Check

1. **Does every AC have corresponding code?**
   - AC1 `cognition.activation_index` built from exposed skills →
     `Cn_activation.build_index` + `gather` + `to_json`
   - AC2 triggers read from SKILL.md frontmatter →
     `Cn_activation.parse_frontmatter` + `read_skill_frontmatter`
   - AC3 `body.commands` registry from packages + repo-local →
     `Cn_runtime_contract.build_command_registry` reusing
     `Cn_command.discover` (#167)
   - AC4 `body.orchestrators` registry →
     `Cn_runtime_contract.build_orchestrator_registry` reading
     `sources.orchestrators` from each manifest
   - AC5 `cn doctor` validates activation index →
     `Cn_activation.validate` + `Cn_doctor.report_activation` with
     three issue kinds (Missing_skill, Empty_triggers,
     Trigger_conflict); `Trigger_conflict` is fail-stop
   - AC6 contract tests updated + new tests →
     `cn_activation_test.ml` (11 expect-tests) +
     `cn_runtime_contract_test.ml` (+4 tests for the new fields)

2. **Are runtime capability extensions untouched?** Yes. No edits to
   `cn_ext_host.ml`, `cn_extension.ml`, or their test files. The
   activation index is a *read* of what's installed, not a
   modification of the extension surface.

3. **Does the activation index respect the "exposed only" contract?**
   Yes. `manifest_skill_ids` reads `sources.skills` as the authority
   list; sub-skills (SKILL.md files under a declared skill
   directory) are not added to the index even if they carry their
   own triggers. Test B3 ("build_index excludes SKILL.md not declared
   in manifest") asserts this explicitly.

4. **Is the "no new runtime dependencies" contract honored?** Yes.
   Frontmatter parser is pure OCaml + stdlib. No YAML library, no
   new opam pin. The parser is deliberately a subset that covers
   the existing SKILL.md corpus; the v1 limitation (inline list
   form unsupported) is documented in PLAN §3.

5. **Tests-first or tests-after?** Tests-first. The test files and
   test contents were authored before the corresponding production
   code in each stage. The eng/testing skill was read before the
   first test was written. This is the explicit corrective from the
   v3.34.0 post-release #167 assessment.

### Pointers

| What | Where |
|------|-------|
| Issue | https://github.com/usurobor/cnos/issues/173 |
| Design | `docs/alpha/agent-runtime/ORCHESTRATORS.md` §4 |
| Bootstrap | `docs/gamma/cdd/3.35.0/README.md` |
| Plan | `docs/gamma/cdd/3.35.0/PLAN-runtime-activation.md` |
| Parser + index + validator | `src/cmd/cn_activation.ml` |
| Contract wiring | `src/cmd/cn_runtime_contract.ml` (types, `gather`, `render_markdown`, `to_json`) |
| Doctor | `src/cmd/cn_doctor.ml` |
| Activation tests | `test/cmd/cn_activation_test.ml` |
| Contract tests | `test/cmd/cn_runtime_contract_test.ml` (#173 section) |

### Exit Criteria

- [x] AC1: activation_index in cognition
- [x] AC2: triggers read from SKILL.md frontmatter
- [x] AC3: body.commands registry from Cn_command.discover
- [x] AC4: body.orchestrators registry from manifests
- [x] AC5: cn doctor validates activation surface with three
      categories (Missing, Empty, Conflict)
- [x] AC6: 15 new tests (11 activation + 4 contract) + existing
      runtime contract tests updated for the new field shape
- [x] Zero bare `with _ ->` catches in touched files (eng/ocaml §2.6.2)
- [x] Tests-first discipline held; active skills loaded before
      writing (v3.34.0 post-release corrective)
- [x] `scripts/check-version-consistency.sh` passes
- [ ] `dune build && dune runtest` — deferred to CI
- [ ] PR review round 1 — pending open
- [ ] CI green on branch — pending
