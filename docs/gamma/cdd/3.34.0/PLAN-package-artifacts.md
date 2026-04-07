# PLAN-v3.35.0-package-artifacts

## Implementation Plan for Package Artifact Distribution and Command Content Class

**Status:** Executed (3 stages, all committed)
**Implements:** docs/alpha/package-system/PACKAGE-ARTIFACTS.md
**Issue:** #167
**Depends on:** cn_deps, cn_build, cn_runtime_contract, cn_lib command
parser, Cn_ffi.Http, Cn_sha256, GitHub Actions release workflow

---

## 0. Coherence Contract

### Gap

Released packages are distributed by cloning the repo and copying a
subtree; commands are compiled built-ins with no extension path.
Both are transport/extensibility defects that show up at distinct
surfaces but share one root: the build system treats the repository,
not the package, as the distribution unit.

### Mode

MCA — concrete changes to build, restore, manifest schema, dispatch.

### α / β / γ target

- **α:** lockfile carries only (name, version, sha256); command
  discovery is a three-layer function with one winning source per
  name
- **β:** producer (release workflow), consumer (cn deps), schema
  (cn.package.json), and discovery (cn / help / doctor) all agree
  on the new surface
- **γ:** #155 failure class is eliminated (no git protocol in normal
  restore); #162 is eliminated (commands are a content class, no
  second plugin system); runtime extensions are unchanged

### Smallest coherent intervention

Do not redesign transport, third-party packaging, or runtime
extensions. Introduce:

- tarball build step in the release workflow
- package index file (`packages/index.json`)
- lockfile v2 with sha256 only
- HTTP download + verify in `cn deps restore`
- `commands` content class on the existing explicit pattern
- three-layer command discovery + dispatch
- doctor validation for the new surface

Everything else stays.

---

## 1. Step Order (as executed)

### Stage A — Producer side (commit 9bebbd5)

**Goal:** Ship the artifacts and schema that consumers will depend on.

**Work:**
1. `scripts/build-packages.sh` — deterministic tarball per
   `packages/<name>/`; writes `packages/index.json` with
   `cn.package-index.v1` schema and SHA-256 of each tarball
2. `packages/cnos.core/cn.package.json` — declare `commands: {}`
   (schema surface; Stage C wires discovery)
3. `src/cmd/cn_build.ml` — extend `source_decl` with
   `commands : command_decl list`, add `parse_commands` for the
   `{ name: { entrypoint, summary } }` map shape
4. `docs/alpha/package-system/PACKAGE-SYSTEM.md` — add commands as
   7th content class, document artifact-first restore flow, add §7
   Command Discovery precedence
5. `.github/workflows/release.yml` — new step runs
   `scripts/build-packages.sh`, attaches tarballs + `index.json`
   as release assets, commits updated `index.json` back to main
6. `docs/alpha/package-system/PACKAGE-ARTIFACTS.md` — cherry-pick
   design doc onto the working branch

**Exit conditions for Stage A:**
- [x] `scripts/build-packages.sh` runs clean; tarballs + index
      produced deterministically
- [x] `scripts/check-version-consistency.sh` passes
- [x] `cn_build.ml` parses existing manifests (empty commands map
      leaves behavior unchanged)
- [x] Docs describe the new class and the new restore flow

### Stage B — Consumer rewrite (commit e2e49b0)

**Goal:** Replace git fetch with artifact-first HTTPS restore +
lockfile v2. Delete dead git transport code.

**Work:**
1. `src/cmd/cn_deps.ml` — rewrite:
   - `locked_dep = { name; version; sha256 }` (was name + version +
     source + rev + subdir + integrity)
   - `lockfile.schema = "cn.lock.v2"`
   - `parse_package_index` for `cn.package-index.v1`
   - `load_package_index` prefers `packages/index.json` in the
     current cnos checkout, otherwise fetches from
     `https://raw.githubusercontent.com/<repo>/main/packages/index.json`
   - `download_to_file` via `curl --output` (avoids stringifying
     binary content through OCaml buffers)
   - `sha256_of_file` via `Cn_sha256.hash` + `Fs.read`
   - `extract_tarball` shells `tar -xzf`
   - `validate_extracted` requires cn.package.json with matching
     `name` field
   - `restore_one`: local first-party dev copy if available, else
     HTTP fetch → SHA-256 verify → extract → validate
   - `lockfile_for_manifest` populates sha256 from the index
   - dead code removed: `git_in`, `default_first_party_source`,
     `packages_subdir`, git fetch/clone flow, source/rev/subdir
     fields
   - compute_integrity / verify_integrity retained for local drift
     detection (unrelated to artifact SHA-256)
2. `src/cmd/cn_runtime_contract.ml` — `package_info` loses
   source/rev/integrity, gains `sha256 : string option`; text and
   JSON rendering updated
3. `test/cmd/cn_deps_test.ml` — drop v1 schema tests (I5, I8);
   replace I3 with v2 round-trip; keep I1/I6/I7 (copy_tree, legacy
   integrity)
4. `test/cmd/cn_runtime_contract_test.ml` — AC7 tests rewritten to
   check `sha256` instead of source/rev/integrity
5. `test/cmd/cn_selfpath_test.ml` — invariant 4 now asserts
   `package_index_url` derives from `cnos_repo`

**Exit conditions for Stage B:**
- [x] All call sites of removed `locked_dep` fields updated
- [x] Lockfile round-trip test passes schema `cn.lock.v2`
- [x] `Cn_deps` exports retained for all external callers
      (`cn_system.ml`, `cn_runtime_contract.ml`)

### Stage C — Command surface (commit bafba83)

**Goal:** Discover, help-list, dispatch, and doctor-validate
external commands.

**Work:**
1. `src/cmd/cn_command.ml` (new):
   - `type source = Repo_local | Package of string`
   - `type external_cmd = { name; source; entrypoint_path; summary }`
   - `discover_repo_local ~hub_path` — walks `.cn/commands/cn-*`
   - `discover_package ~hub_path` — walks `.cn/vendor/packages/*/
     cn.package.json` for the commands object
   - `discover` concatenates in precedence order (repo-local first)
   - `find ~hub_path name` — first match wins
   - `dispatch ~hub_path ~args` — `Unix.create_process_env` with
     inherited stdio, exports `CN_HUB_PATH`, `CN_PACKAGE_ROOT`,
     `CN_COMMAND_NAME`, returns child exit code
   - `validate ~hub_path` — missing entrypoint, non-executable,
     malformed metadata, cross-package duplicate names
2. `src/cmd/cn_help.ml` (new) — `run_help ()` prints
   `Cn_lib.help_text` and appends an "External commands:" section
   if inside a hub, labeled by source
3. `src/cmd/cn_doctor.ml` (new) — wraps `Cn_system.run_doctor` with
   `Cn_command.validate`; exits non-zero on command issues
4. `src/cli/cn.ml`:
   - `None` branch routes single-token unknowns through
     `Cn_command.find` → dispatch before falling back to help+exit
   - `Some Help → Cn_help.run_help ()`
   - `Some Doctor → Cn_doctor.run_doctor ~hub_path`
5. `src/cmd/dune` — declare new modules

**Exit conditions for Stage C:**
- [x] `cn <unknown-name>` dispatches to `.cn/commands/cn-<name>` or
      a package-declared entrypoint if either exists
- [x] Built-in commands still take precedence (parse_command runs
      first; external dispatch only fires on `None`)
- [x] `cn help` augments output with external commands when in a hub
- [x] `cn doctor` appends command validation to the system doctor
      pipeline

### Deferred (documented, not this cycle)

- Migrating specific built-ins (`daily`, `weekly`, `save`, `release`)
  into `packages/cnos.core/commands/`. Surface is in place; follow-up
  cycle picks specific commands and writes their scripts + deletes
  the built-in handlers.
- Third-party package registry (design doc §Non-goals).
- Package signing beyond SHA-256 checksums (known debt).

---

## 2. Process Cost / Automation Boundary

- Package tarball generation: automated (release workflow)
- Index generation: automated (release workflow)
- Index commit-back to main: automated with soft-fail (branch
  protection may require manual merge)
- Checksum verification: automated (cn deps restore)
- Command discovery: automated (cn dispatch, help, doctor)
- Human judgment retained: which built-ins to migrate, command API
  design, version policy

---

## 3. Known Debt (for next cycle's assessment)

- Package index is a flat file; no versioned API or caching layer
- No third-party package hosting story
- No package signing beyond SHA-256
- Version solving is exact-match only
- `curl` is required on the host for restore (documented; no new
  OCaml runtime deps)
- `tar` is required on the host for extraction (same)
- Release workflow push-to-main may fail under branch protection;
  index is still attached as a release asset as a fallback
