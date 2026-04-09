## CDD Bootstrap — v3.38.0 (#182 Move 2 — first slice)

**Issue:** #182 — Core refactor: package-driven runtime substrate with lean core
**Cycle scope:** Move 2 first slice — extract package manifest / lockfile / index types into `src/lib/`
**Branch:** `claude/182-move2-package-types`
**Design:** `docs/alpha/agent-runtime/CORE-REFACTOR.md` §7 "Move 2 — Pure-model gravity into `src/lib/`"
**Parent sequencing:** v3.37.0 post-release §7 named "Move 2 of #182" as the next MCA with first AC = extract one canonical pure-type module (suggested: package manifest types from `cn_deps.ml`)
**Mode:** MCA
**Level:** L6 — cross-module refactor with no new boundary; structural subtraction from `src/cmd/` into `src/lib/`
**Active skills loaded (and read) before code:** cdd, eng/ocaml (§3.1 no bare `with _ ->`, §2.1 disambiguate at definition), eng/testing (ppx_expect per extracted module)

### Gap

`src/cmd/cn_deps.ml` currently owns the authoritative definitions
of six pure types — `manifest_dep`, `locked_dep`, `manifest`,
`lockfile`, `index_entry`, `package_index` — plus their JSON
serialization and the `parse_package_index` / `lookup_index` /
`is_first_party` helpers. None of these types or helpers touch the
filesystem, git, process exec, HTTP, or the LLM. They are pure data.

But the enclosing module (`Cn_deps`) is in the `cmd/` library,
which is the IO plane. Every caller that wants to know "what
shape is a lockfile entry" has to reach into `Cn_deps` — a module
whose other exports do filesystem reads, HTTP fetches, and tar
extraction. The abstraction inverts: the pure model sits inside
the IO wrapper instead of the IO wrapper sitting on top of the
pure model.

This is the specific instance of the broader #182 observation:
`src/cmd/` owns system truth (schemas, registries, contract
rendering, activation logic) that should live in a reusable
pure-model layer. CORE-REFACTOR.md §7 prescribes the remedy:
widen the existing `src/lib/` with pure types and validators
extracted from `src/cmd/`, starting with package manifest types
from `cn_deps.ml`. No `src/core/` — widen `src/lib/` instead.

### What fails if skipped

- Every new cross-module that needs to reason about package
  manifests (runtime contract projection, workflow runtime
  discovery, doctor validation, future CTB compiler output) has
  to depend on `Cn_deps`, which drags in the entire HTTP-fetch
  + tar-extract surface as a transitive dependency even when
  the caller only wants record types.
- Move 2 of #182 remains unstarted. The broader refactor pipeline
  stalls at the first move.
- The asymmetry between "docs describe a modular system" and
  "code is a command-centric monolith" widens further.

### Scope for this cycle

**Just the first slice of Move 2.** This cycle extracts exactly
one canonical pure-type module — the package types — and
demonstrates the pattern (pure module in `src/lib/`, type
re-export in the old `src/cmd/` location for caller compatibility,
zero IO in the extracted module, no new directories). Subsequent
cycles repeat the pattern for:

- runtime contract record types (from `cn_runtime_contract.ml`)
- workflow IR types + parser + validator (from `cn_workflow.ml`)
- activation types + evaluator (from `cn_activation.ml`)

Each of those is a separate cycle, not this one. Slicing Move 2
keeps the per-cycle diff reviewable and lets each extraction
carry its own self-coherence + tests.

### Acceptance Criteria (this cycle)

- [ ] **AC1** New module `src/lib/cn_package.ml` defines the six pure types (`manifest_dep`, `locked_dep`, `manifest`, `lockfile`, `index_entry`, `package_index`) as the canonical authority.
- [ ] **AC2** The pure JSON helpers (`manifest_dep_to_json`, `locked_dep_to_json`, `parse_manifest_dep`, `parse_locked_dep`, `parse_package_index`, `lookup_index`, `is_first_party`) live in `Cn_package`. No IO, no process exec, no HTTP.
- [ ] **AC3** `src/cmd/cn_deps.ml` no longer owns the canonical type definitions. Instead it **re-exports** them via OCaml type-equality syntax (`type manifest_dep = Cn_package.manifest_dep = { ... }`) so existing external callers (e.g. `Cn_deps.locked_dep` used by `cn_runtime_contract.ml`, `cn_system.ml`, and several test files) continue to compile with zero changes.
- [ ] **AC4** `src/cmd/cn_deps.ml` retains only the IO-side functions (`read_manifest`, `write_manifest`, `read_lockfile`, `write_lockfile`, `restore`, `doctor`, etc.) and delegates the pure JSON / lookup logic to `Cn_package`.
- [ ] **AC5** `test/lib/cn_package_test.ml` covers the pure module with ppx_expect tests: record round-trips through JSON, `parse_package_index` shape, `lookup_index` hit and miss, `is_first_party` positive and negative.
- [ ] **AC6** `src/lib/dune` registers the new module; `test/lib/dune` registers the new test library.
- [ ] **AC7** Existing callers (`cn_runtime_contract.ml`, `cn_system.ml`, `cn_deps_test.ml`, `cn_runtime_contract_test.ml`, `cn_selfpath_test.ml`) compile without edits. Zero caller migrations in this cycle — the re-export mechanism is the compatibility shim.
- [ ] **AC8** Discipline: `src/lib/cn_package.ml` imports **zero** modules from `src/cmd/`, `src/ffi/`, `src/transport/`. It may only use stdlib + `Cn_json`. Verified by grep.

### Non-goals (this cycle)

- Extracting runtime contract types (next cycle)
- Extracting workflow IR (cycle after that)
- Extracting activation types (cycle after that)
- Forcing callers to migrate from `Cn_deps.manifest_dep` to `Cn_package.manifest_dep` — the re-export is the compatibility shim and callers stay unchanged
- Creating `src/core/` — explicit no per CORE-REFACTOR.md §7 ("widen existing `src/lib/`, not new dir")
- Any `src/host/` / `src/runtime/` restructure
- gh-pages package source (#181)
- Changes to `Cn_deps` IO semantics (restore, doctor, lockfile_for_manifest, etc. stay as-is)

### Plan

| Stage | Scope | ACs |
|-------|-------|-----|
| A | Tests first: `test/lib/cn_package_test.ml` with expect-tests for types, JSON round-trip, index parse+lookup, is_first_party | AC5 |
| B | Create `src/lib/cn_package.ml` with the six types, the pure helpers, and the discipline comment (no IO) | AC1, AC2, AC8 |
| C | Register new module in `src/lib/dune` (`modules` list) and new test library in `test/lib/dune` | AC6 |
| D | Rewrite `src/cmd/cn_deps.ml`: delete the six type definitions, replace with type re-exports (`type manifest_dep = Cn_package.manifest_dep = { ... }`); delete the duplicated pure helpers and `open Cn_package` at the top so the IO-side functions (which reference `manifest_dep.name`, `locked_dep.sha256`, etc.) still type-check against the re-exported records | AC3, AC4 |
| E | Verify no caller churn: grep for every external reference to `Cn_deps.manifest_dep | .locked_dep | .manifest | .lockfile | .package_index` and confirm type re-exports cover each site | AC7 |
| F | Update `docs/alpha/agent-runtime/CORE-REFACTOR.md` Move 2 status: first slice shipped, three remaining (runtime contract, workflow, activation) | — |
| G | Self-coherence report + GATE | — |
| H | §2.5b 6-check pre-review gate (including new check 6: does this PR change a schema consumed by test fixtures? — **yes, record-field layout**; audit all test files that construct `Cn_deps.manifest_dep` etc.) | — |

### Impact Graph

**New files:**
- `src/lib/cn_package.ml` (types + pure helpers)
- `test/lib/cn_package_test.ml` (ppx_expect tests)

**Touched modules:**
- `src/cmd/cn_deps.ml` — delete duplicate type defs + pure helpers; add type re-exports and `open Cn_package`
- `src/lib/dune` — register `cn_package` module
- `test/lib/dune` — register `cn_package_test` library

**Touched docs:**
- `docs/alpha/agent-runtime/CORE-REFACTOR.md` — Move 2 status (first slice)

**Compatibility-preserved (verified by grep, not changed):**
- `src/cmd/cn_runtime_contract.ml::build_orchestrator_registry` — accesses `Cn_deps.locked_dep` fields; works unchanged via re-export
- `src/cmd/cn_system.ml::setup_assets`, `reconcile_packages` — calls `Cn_deps.lockfile_for_manifest`; type-threaded via re-exports
- `test/cmd/cn_deps_test.ml` — constructs `Cn_deps.manifest` and `Cn_deps.lockfile` record literals; works unchanged via re-exports with field-equality syntax
- `test/cmd/cn_runtime_contract_test.ml` — constructs `Cn_deps.lockfile` record literals; same as above
- `test/cmd/cn_selfpath_test.ml` — calls `Cn_deps.package_index_url ()`; function stays in `Cn_deps`, not moved

### CDD Trace

| Step | Artifact | Skills loaded | Decision |
|------|----------|---------------|----------|
| 0 Observe | v3.37.0 post-release §7 + #182 issue + CORE-REFACTOR.md §7 Move 2 + `src/cmd/cn_deps.ml` current shape + existing `src/lib/` layout | cdd, post-release | Next MCA per post-release is Move 2 first slice; pure package types are the canonical candidate |
| 1 Select | #182 (umbrella) — Move 2 first slice | cdd | L6 structural subtraction, not a boundary move; scope = one module extraction |
| 2 Branch | `claude/182-move2-package-types` | — | created from current main (`cfe45c2` = v3.37.0 post-release merge) |
| 3 Bootstrap | `docs/gamma/cdd/3.38.0/` | — | this file + SELF-COHERENCE + GATE |
| 4 Gap | this file §Gap | cdd | `cn_deps.ml` owns pure types that other modules must reach through an IO plane to use |
| 5 Mode | this file §Active skills | cdd, eng/ocaml, eng/testing | MCA, L6, work shape "cross-module refactor"; skills loaded-and-read-before-code |
| 6 Artifacts | tests → code → docs → self-coherence | eng/ocaml, eng/testing | Stage A tests precede Stage B code |
| 7 Self-coherence | `SELF-COHERENCE.md` | cdd | Written after Stages A–F complete |
| 7a Pre-review | §2.5b 6-check gate | cdd | Including the new check 6 from v3.37.0 post-release |
| 8 Review | PR body | cdd/review | Pending |
| 9 Gate | `GATE.md` | cdd/release | HOLD until CI + review converge |
| 10 Release | — | — | Next release train |
