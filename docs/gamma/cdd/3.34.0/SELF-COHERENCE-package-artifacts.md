## Self-Coherence Report — v3.35.0

**Issue:** #167 — Package artifact distribution and command content class
**Branch:** claude/167-package-artifacts-H97Su
**Stages committed:** 9bebbd5 (A), e2e49b0 (B), bafba83 (C)

### Alpha (type-level clarity)

| Surface | Change | Type-level judgment |
|---------|--------|--------------------|
| `Cn_deps.locked_dep` | `{source; rev; subdir; integrity}` → `{sha256}` | Collapsed 4 optional-or-transport fields into one mandatory integrity field. Every remaining field is required by consumers. |
| `Cn_deps.lockfile` | schema constant `cn.deps.lock.v1` → `cn.lock.v2` | Single source of truth for the wire format; grep finds no stale `v1` literals outside historical docs. |
| `Cn_deps.package_index` | new record `{index_schema; index_entries}` with assoc-list lookup | Explicit; no `string string option Map` acrobatics. |
| `Cn_build.source_decl` | +`commands : command_decl list` | Follows the same pattern as `doctrine`/`mindsets`/etc — one record field per content class. |
| `Cn_runtime_contract.package_info` | `source; rev; integrity` → `sha256 : string option` | Option-typed because a hub may have installed packages without a lockfile entry (e.g., manual vendor). |
| `Cn_command.source` | new `Repo_local \| Package of string` | Variant encodes the precedence layer; impossible to forget one. |
| `Cn_command.external_cmd` | new record `{name; source; entrypoint_path; summary}` | Every field is used in discovery, dispatch, help, or doctor. No speculative fields. |

**Alpha score: A−.** Clean field collapses (locked_dep especially),
one variant per discovery layer, no string-typed dispatch. The minus
is honest about one thing: `Cn_command.external_cmd.summary` for
repo-local commands is synthesized (`"repo-local: cn-<basename>"`)
rather than read from frontmatter, because repo-local scripts are
unstructured by design. A richer repo-local metadata surface would
push this to A; it is explicitly out of scope for v1.

### Beta (authority surface agreement)

Every authority surface touched by this change, and whether its
consumers agree:

| Surface | Authority | Consumers updated? |
|---------|-----------|--------------------|
| Lockfile schema `cn.lock.v2` | `cn_deps.ml` read/write | `cn_system.ml` (setup + reconcile), `cn_runtime_contract.ml` (provenance), `test/cmd/cn_deps_test.ml`, `test/cmd/cn_runtime_contract_test.ml` — all updated |
| Manifest schema `cn.package.v1` | `packages/<name>/cn.package.json` | `cn_build.ml` parser extended; `docs/alpha/package-system/PACKAGE-SYSTEM.md` documents the new `commands` class |
| Package index schema `cn.package-index.v1` | `packages/index.json` | `scripts/build-packages.sh` (producer), `cn_deps.ml::load_package_index` (consumer) |
| Command discovery precedence | `src/cmd/cn_command.ml` discover order | `src/cli/cn.ml` dispatch, `cn_help.ml` listing, `cn_doctor.ml` validation all read the same `discover`/`find` functions — single source of truth |
| Release workflow tarball + index | `.github/workflows/release.yml` | Produces artifacts the lockfile format is designed around; index URL hardcoded via `Cn_lib.cnos_repo` matches what the workflow publishes |
| Runtime contract JSON | `Cn_runtime_contract.to_json` | Field rename `source/rev/integrity → sha256` flows through both the buffer rendering and the JSON emitter; no half-updated surface |
| PACKAGE-SYSTEM.md | canonical docs for package system shape | §1.1 table expanded to 7 classes; §2.4 restore flow rewritten; new §7 Command Discovery. PACKAGE-ARTIFACTS.md is the design companion (cherry-picked to this branch) |

**Stale-reference scan (grep):**
- `locked_dep.source`, `.rev`, `.subdir`, `.integrity`: **no remaining references** in src/ or test/
- `cn.deps.lock.v1` literal: only in `docs/alpha/cognitive-substrate/CAR.md`
  (historical narrative) and a 3.19.0 CDD archive — both intentionally
  untouched
- `source_kind` / git transport helpers: deleted

**Beta score: A.** Every downstream consumer of the touched
authorities is updated in the same set of commits. The one doc with
a stale schema literal (CAR.md) is narrative history, not a live
surface.

### Gamma (cycle economics)

**Lines changed per stage:**

| Stage | Files touched | Insertions | Deletions | Net |
|-------|---------------|------------|-----------|-----|
| A | 7 | +555 | −8 | +547 |
| B | 5 | +445 | −470 | −25 |
| C | 5 | +320 | −5 | +315 |
| **Total** | 17 unique | **+1320** | **−483** | **+837** |

**Where the new lines go:**
- Design doc (cherry-picked): 311 lines
- `scripts/build-packages.sh`: 130 lines
- `cn_command.ml` (new): 249 lines
- `cn_deps.ml` (rewrite): net −25 but roughly the same line count
  because git transport was replaced with HTTP transport
- `cn_help.ml`, `cn_doctor.ml`, CDD ceremony: the rest

**Where lines went away:**
- 27 references to `source_kind` / `rev` / `subdir` in cn_deps.ml
- `git_in`, `default_first_party_source`, fetch/clone fallback path
- Old git-transport test expectations

**Cycle iteration triggers (§9.1):**

| Trigger | Fired? | Note |
|---------|--------|------|
| Review rounds > 2 | TBD | PR not yet opened |
| Mechanical ratio > 20% | No | Estimated < 10%: most of the diff is new surface (schema, discovery, docs), not boilerplate |
| Avoidable tooling failure | **Yes (soft)** | No OCaml toolchain in the authoring sandbox; dune build / dune runtest did not execute locally. This will surface in CI as the compilation oracle. Mitigated by reading-level review: record-literal exhaustiveness, parser nesting, cross-module refs, module list in dune, grep for removed field refs. Documented in Stage C commit message. |
| Loaded skill failed to prevent a finding | TBD | Depends on review findings |

**Gamma score: A−.** Line economics are healthy — the negative delta
on Stage B is the correct signature for a simplification stage
(replacing git transport with HTTP transport should be net-neutral
or better). The − is for the tooling failure: a real L7 cycle should
have run `dune build` between stages. Documented as immediate debt
in Stage C's commit message and in the known-debt list below.

### Triadic Coherence Check

1. **Does every AC have corresponding code?**
   - AC1 (tarballs): `scripts/build-packages.sh` + `.github/workflows/release.yml`
   - AC2 (index resolves name+version): `packages/index.json` +
     `Cn_deps.load_package_index` + `Cn_deps.lookup_index`
   - AC3 (HTTP restore without git): `Cn_deps.restore_one_http` via
     `download_to_file` (curl shell) — git helpers deleted
   - AC4 (SHA-256 verify): `Cn_deps.sha256_of_file` +
     equality check in `restore_one_http` before extraction
   - AC5 (manifest validate post-extract):
     `Cn_deps.validate_extracted`
   - AC6 (commands content class in schema + docs):
     `Cn_build.source_decl.commands` + `parse_commands` +
     `packages/cnos.core/cn.package.json` declaration +
     `PACKAGE-SYSTEM.md` §1.1 and §7
   - AC7 (help lists package + repo-local commands):
     `Cn_help.run_help` + `Cn_command.discover`
   - AC8 (doctor validates command integrity):
     `Cn_command.validate` + `Cn_doctor.run_doctor`
   - AC9 (`.cn/commands/` discoverable):
     `Cn_command.discover_repo_local` + dispatch in `cn.ml`
   - AC10 (runtime extensions unchanged): grep shows no edits to
     `cn_ext_host.ml` or `cn_extension.ml` in any of the three
     stage commits

2. **Does the precedence rule match the docs?** Yes. Design doc §7
   and PACKAGE-SYSTEM.md §7 both say built-in > repo-local > package.
   `src/cli/cn.ml` dispatches built-ins via `parse_command` *before*
   ever calling `Cn_command.find`, which returns repo-local entries
   before package entries. One chain, one ordering, three surfaces
   agreeing (docs, code, doctor).

3. **Are runtime extensions actually untouched?** Yes. Neither
   `cn_ext_host.ml` nor `cn_extension.ml` appear in any of the
   stage diffs. `PACKAGE-SYSTEM.md` §7 explicitly calls out the
   separation.

4. **Is the "one hub = sigma" assumption honored?** Yes. No
   backwards-compat code, no `cn.deps.lock.v1` read path, no
   schema-version sniffing. Lockfiles written before this change
   will fail to parse and `cn setup` will regenerate them — which
   is exactly the migration the design doc specifies.

5. **Is there a silent failure path?** One known soft spot: when
   `load_package_index` fails (no local index and no network), the
   restore falls through to local-first-party copy, which succeeds
   in the cnos dev checkout and fails with a clear error
   elsewhere. This matches the "dev escape hatch" from design doc
   §5. A consumer running `cn deps restore` on a sigma hub with no
   network will see the index fetch failure wrapped in a per-package
   error — not ideal, but honest.

### Pointers

| What | Where |
|------|-------|
| Issue | https://github.com/usurobor/cnos/issues/167 |
| Design | `docs/alpha/package-system/PACKAGE-ARTIFACTS.md` |
| System docs | `docs/alpha/package-system/PACKAGE-SYSTEM.md` (§1.1, §2.4, §7) |
| Bootstrap | `docs/gamma/cdd/3.35.0/README.md` |
| Plan | `docs/gamma/cdd/3.35.0/PLAN-package-artifacts.md` |
| Producer | `scripts/build-packages.sh`, `.github/workflows/release.yml` |
| Consumer | `src/cmd/cn_deps.ml`, `src/cmd/cn_runtime_contract.ml` |
| Commands | `src/cmd/cn_command.ml`, `src/cmd/cn_help.ml`, `src/cmd/cn_doctor.ml`, `src/cli/cn.ml` |
| Index | `packages/index.json` |

### Exit Criteria

- [x] AC1: Release workflow builds and publishes package tarballs
- [x] AC2: Package index maps name+version → URL+SHA-256
- [x] AC3: Restore uses HTTPS + tar, not git
- [x] AC4: SHA-256 verified before extraction
- [x] AC5: cn.package.json validated post-extract
- [x] AC6: `commands` declared in schema, documented in
      PACKAGE-SYSTEM.md §1.1 and §7
- [x] AC7: `cn help` lists external commands
- [x] AC8: `cn doctor` validates command integrity
- [x] AC9: `.cn/commands/cn-<name>` dispatch
- [x] AC10: runtime-extensions modules untouched
- [ ] `dune build && dune runtest` (deferred to CI — no OCaml
      toolchain in authoring sandbox)
- [ ] PR review round 1
- [ ] CI green on branch
