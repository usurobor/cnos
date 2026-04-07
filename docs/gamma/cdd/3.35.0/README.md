## CDD Bootstrap — v3.35.0

**Issue:** #167 — Package artifact distribution and command content class
**Branch:** claude/167-package-artifacts-H97Su
**Design:** docs/alpha/package-system/PACKAGE-ARTIFACTS.md
**Parent:** c6bd17a (main)
**Mode:** MCA
**Level:** L7 — boundary move: released packages become distribution
units, commands become a package content class
**Active skills:** cdd, design, eng/ocaml

### Gap

Two incoherences that share one root cause — the build system treats
the repository, not the package, as the distribution unit.

1. **Released packages are not yet the distribution unit.**
   `cn deps restore` fetches a git commit and copies a subtree out.
   That couples install to git protocol capabilities. When the
   protocol is restricted (#155: Claude Code sandbox, shallow-fetch
   -by-SHA unsupported) there is no simple recovery. The lockfile
   carried `source`, `rev`, `subdir` — transport metadata consumers
   do not need. `cn_deps.ml` had 27 references to those fields.

2. **Commands are not yet a package content class.** The CLI command
   surface was a closed built-in variant. Adding an operator-facing
   command required core edits (#162). Doctrine, mindsets, skills,
   extensions, and templates were all explicit content classes;
   commands were not.

### What fails if skipped

Every new environment that restricts git protocol produces another
fetch workaround. Every CLI command extension requires either core
modification or a second plugin framework.

### Acceptance Criteria

- **AC1** Released first-party packages published as tarball
  artifacts by the release workflow
- **AC2** `packages/index.json` resolves name+version to URL+SHA-256
- **AC3** `cn deps restore` restores first-party packages via HTTPS
  without git
- **AC4** `cn deps restore` verifies package SHA-256 before install
- **AC5** Extracted packages validate `cn.package.json`
- **AC6** `commands` is an explicit content class in `cn.package.json`
  schema, documented in PACKAGE-SYSTEM.md
- **AC7** `cn help` lists package-provided and repo-local commands
- **AC8** `cn doctor` validates package command integrity (duplicates,
  missing entrypoints, non-executable, malformed metadata)
- **AC9** `.cn/commands/` repo-local commands are discoverable
- **AC10** Runtime capability extensions remain a separate system
  (no regression)

### Design

Full design in `docs/alpha/package-system/PACKAGE-ARTIFACTS.md`
(cherry-picked onto this branch in Stage A). Three decisions, kept
separate:

1. **Artifact-first distribution** — released first-party packages
   restore over HTTPS from versioned tarballs. A package index
   resolves name+version to URL+SHA-256. Git becomes a
   development/exception path.
2. **Commands as a first-class package content class** — `commands`
   joins the existing content classes (doctrine / mindsets / skills /
   extensions / templates) with the same explicit-class pattern.
3. **Runtime capability extensions remain separate** — three-way
   split between runtime extensions (agent capability providers),
   package commands (operator CLI), and cognitive substrate (skills
   / doctrine / mindsets / templates).

### Plan (stage index)

Staged implementation: each stage builds, tests, and commits
independently so the branch tip is always recoverable.

| Stage | Scope | Commit |
|-------|-------|--------|
| A | Producer side: `scripts/build-packages.sh`, `packages/index.json`, `release.yml`, `commands` schema addition, `PACKAGE-SYSTEM.md` updates | 9bebbd5 |
| B | Consumer rewrite: `cn_deps.ml` HTTP restore + lockfile v2, `cn_runtime_contract.ml` field changes, test updates | e2e49b0 |
| C | Command surface: `cn_command.ml`, `cn_help.ml`, `cn_doctor.ml`, dispatch wiring in `cn.ml` | bafba83 |

Full plan in `PLAN-package-artifacts.md`.

### Impact Graph

**Downstream consumers**
- `cn deps restore` — switched to HTTP tarball fetch (Stage B)
- `cn deps vendor` — reads new lockfile format (Stage B)
- `cn doctor` — validates package integrity + command integrity (Stage B + C)
- `cn help` — discovers and lists package + repo-local commands (Stage C)
- `cn <name>` dispatch — resolves by precedence (Stage C)
- Lockfile schema — simplified (Stage B)
- `cn.package.json` schema — extended with commands (Stage A)
- `PACKAGE-SYSTEM.md` — documents commands class and artifact-first restore (Stage A)

**Upstream producers**
- Release workflow — builds and publishes package tarballs + index (Stage A)
- `scripts/build-packages.sh` — new (Stage A)

**Authority shifts**
- Lockfile authority: name+version+sha256 (no git transport) — Stage B
- Package index authority: name+version → URL+sha256 — Stage A

### CDD Trace

| Step | Artifact | Skills loaded | Decision |
|------|----------|---------------|----------|
| 0 Observe | CHANGELOG TSC, lag table, #155 post-mortem, #162 | — | Git-based restore fails in restricted envs; commands not a content class |
| 1 Select | — | — | Package distribution is the root cause of #155; commands the root cause of #162; single coherent cycle addresses both |
| 2 Design | `docs/alpha/package-system/PACKAGE-ARTIFACTS.md` | design, cap, writing | Artifact-first + commands-as-content-class + runtime extensions separate |
| 3 Contract | README.md ACs (this file) | — | 10 ACs derived from issue + design doc |
| 4 Plan | `PLAN-package-artifacts.md` | — | Three stages, each buildable, commit per stage |
| 5 Code | build-packages.sh, cn_{deps,command,help,doctor}.ml, cn.ml, workflow, docs | eng/ocaml | Staged A → B → C |
| 6 Self-coherence | `SELF-COHERENCE.md` | — | See report |
| 7 Review | `GATE.md` pre-gate + pending PR review | cdd/review | Pending |
| 8 Release | pending | cdd/release | After gate + review |
| 9 Assessment | pending | cdd/post-release | After release |
