# PLAN-v3.35.0-runtime-activation

## Implementation Plan for Runtime Contract Activation Index + Registries

**Status:** In progress
**Implements:** docs/alpha/agent-runtime/ORCHESTRATORS.md §4
**Issue:** #173 (parent: #170)
**Depends on:** #167 (commands content class — shipped in v3.34.0)

---

## 0. Coherence Contract

### Gap

The runtime contract emits packages and capabilities but no activation metadata, no command registry, and no orchestrator registry. The agent reasons from hidden prompt conventions instead of explicit declarative state.

### Mode

MCA — concrete additions to runtime contract types, builders, renderers, and doctor.

### α / β / γ target

- **α:** new types are explicit records (`activation_entry`, `command_entry`, `orchestrator_entry`); frontmatter parser is a pure function from string to `(parsed, string) result`.
- **β:** the activation index, the markdown render, and the JSON render all read the same builder output. Doctor surfaces consume the same builder. Single source of truth per surface.
- **γ:** test-first; eng/ocaml + eng/testing skills loaded **before writing**, not after a review finding. No bare `with _ ->`. `dune build && dune runtest` and `cn build` run before commit.

### Smallest coherent intervention

One new module (`cn_activation.ml`), three new record types in `cn_runtime_contract.ml`, three new fields in the JSON / markdown renderers, three new doctor checks. No new dependencies. No build-system changes beyond declaring the new module in `src/cmd/dune` and the new test in `test/cmd/dune`.

---

## 1. Step Order

### Stage A — Tests first

Write all expect-tests before any production code so failing tests demonstrate the gap.

**`test/cmd/cn_activation_test.ml`** (new):
1. Parse SKILL.md frontmatter — happy path with `name`, `description`, `triggers` block list. Assert all three extracted.
2. Parse SKILL.md frontmatter — missing leading `---`. Assert graceful (returns empty/no triggers, no exception).
3. Parse SKILL.md frontmatter — closes mid-file with no second `---`. Assert graceful.
4. Parse SKILL.md frontmatter — `triggers` field absent. Assert empty triggers list.
5. Parse SKILL.md frontmatter — malformed list lines. Assert what we can extract is extracted.
6. Build activation index from a temp package tree with two declared skills, one with triggers and one without. Assert both appear with correct triggers.
7. Build activation index when the manifest declares a skill not present on disk. Assert it is excluded (not crash).
8. Build activation index when SKILL.md exists but is not declared in `sources.skills`. Assert it is excluded.

**`test/cmd/cn_runtime_contract_test.ml`** (extend):
9. `to_json` cognition contains an `activation_index.skills` array.
10. `to_json` body contains `commands` and `orchestrators` arrays.
11. `render_markdown` includes a Skills: section with package + triggers when activation index is non-empty.

**`test/cmd/cn_doctor` coverage** (in `cn_activation_test.ml` to keep doctor module thin):
12. Validator: declared skill with no SKILL.md → warning string mentions "missing".
13. Validator: SKILL.md with empty triggers → warning string mentions "triggers".
14. Validator: two skills claiming the same trigger keyword → error string mentions "conflict".

### Stage B — Implementation

`src/cmd/cn_activation.ml` (new):

```ocaml
type frontmatter = {
  fm_name : string option;
  fm_description : string option;
  fm_triggers : string list;
}

val parse_frontmatter : string -> frontmatter
val read_skill_frontmatter : string -> frontmatter option
(* path -> Some fm | None if file missing *)

type activation_entry = {
  skill_id : string;          (* path-style id, e.g. "cdd/review" *)
  package : string;
  summary : string;            (* from fm_description, "" if absent *)
  triggers : string list;
}

val build_index :
  hub_path:string ->
  activation_entry list

(* Validators returning issue list (empty = healthy) *)
type issue_kind = Missing_skill | Empty_triggers | Trigger_conflict
type issue = { kind : issue_kind; message : string }
val validate : hub_path:string -> issue list
```

Frontmatter parser:
- Trim. If file does not start with `---\n`, return empty frontmatter.
- Read until next line that is `---`. Anything between is the YAML subset.
- For each line:
  - `key: value` → set scalar field
  - `key:` followed by indented `- item` lines → block list
  - blank line → skip
  - everything else → log warning to stderr, continue
- Recognised keys: `name`, `description`, `triggers`. Anything else ignored.

`build_index ~hub_path`:
- Walk `Cn_assets.list_installed_packages hub_path`
- For each `(pkg_name, pkg_dir)`:
  - Parse `cn.package.json`, read `sources.skills` (string list)
  - For each declared skill path: open `<pkg_dir>/skills/<path>/SKILL.md`
  - If present, parse frontmatter; emit one `activation_entry` with `skill_id = path`, `package = pkg_name`, `summary = description option default ""`, `triggers = fm_triggers`
  - If absent: skip silently (validator surfaces it)

`validate ~hub_path`:
- For each declared skill: if SKILL.md missing → `Missing_skill` issue
- For each parsed entry: if `triggers = []` → `Empty_triggers` issue
- Cross-skill: build a `(trigger, skill_id) list`, group by trigger, any group with > 1 distinct `skill_id` → `Trigger_conflict` issue

`src/cmd/cn_runtime_contract.ml` (extend):

New record types in the cognition / body sections:

```ocaml
type activation_entry = Cn_activation.activation_entry  (* re-exposed *)

type command_entry = {
  cmd_name : string;
  cmd_source : string;     (* "repo-local" | "package" *)
  cmd_package : string option;
  cmd_summary : string;
}

type orchestrator_entry = {
  orch_name : string;
  orch_source : string;
  orch_package : string;
  orch_trigger_kinds : string list;
}
```

Extend `cognition` and `body_contract` records with:
- `cognition.activation_index : activation_entry list`
- `body_contract.commands : command_entry list`
- `body_contract.orchestrators : orchestrator_entry list`

Add helper builders that consume `Cn_activation.build_index` and `Cn_command.discover` and that read `sources.orchestrators` from each installed package.

Extend `gather` to populate the new fields. Extend `render_markdown` and `to_json` to emit them.

### Stage C — Doctor wiring

`src/cmd/cn_doctor.ml`:

```ocaml
let run_doctor ~hub_path =
  Cn_system.run_doctor hub_path;
  let cmd_issues = Cn_command.validate ~hub_path in
  let act_issues = Cn_activation.validate ~hub_path in
  ...
```

Format activation issues by kind:
- `Missing_skill` → warning prefix
- `Empty_triggers` → warning prefix
- `Trigger_conflict` → error prefix; doctor exits 1 if any conflict present

### Stage D — Sync + verify + ship

1. Run `cn build` so `packages/cnos.core/skills/...` mirrors `src/agent/skills/...` (no orphan SKILL.md drift).
2. Run `dune build` — must succeed.
3. Run `dune runtest` — all expect tests pass (refresh snapshots only if a test asserts shape and the shape is intentional).
4. Run `bash scripts/check-version-consistency.sh`.
5. Self-verification gate (issue body §"Self-verification gate"):
   - `grep -rn 'with _ ->' src/cmd/cn_activation.ml src/cmd/cn_runtime_contract.ml src/cmd/cn_doctor.ml` returns zero matches
   - test counts ≥ targets
   - frontmatter parser handles all four cases
   - `cn build` run
   - `dune build && dune runtest` pass
6. Commit per stage. Push branch. Open PR.

---

## 2. Process Cost / Automation Boundary

- Frontmatter parsing: code; no library
- Activation index building: code; reads filesystem
- Doctor checks: code; reads filesystem
- Trigger-conflict policy: human judgment (which keywords are conflicts vs. legitimately shared) — v1 treats *any* shared trigger across distinct skill ids as a conflict; v2 may relax once we see real cases

---

## 3. Known Debt

- Frontmatter parser is line-based YAML subset; will fail on inline lists `triggers: [a, b]` (only supports block list `- item`). Documented as v1 limitation; the existing SKILL.md files in this repo all use block list form, verified by grep.
- Sub-skills (SKILL.md files under a declared skill directory) are not exposed even if they have their own triggers. Activation index treats one declared skill = one entry.
- Orchestrators schema is shipped but no package declares orchestrators yet; the field will read empty across all installed packages until cnos.pm or another package adds them.
- Trigger conflict policy is binary; no notion of "weak" vs "strong" trigger as ORCHESTRATORS.md §6 mentions for future work.
