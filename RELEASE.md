# cnos v3.34.0

## Headline

Package artifact distribution replaces git-based restore. Commands become a package content class.

## What changed

### Package distribution (#167)
- `cn deps restore` now downloads versioned tarballs over HTTPS instead of fetching git commits
- Package index (`packages/index.json`) resolves name+version to URL+SHA-256
- Lockfile v2: `{name, version, sha256}` — no git transport metadata
- All `source_kind`/`rev`/`subdir` logic deleted from `cn_deps.ml`
- `scripts/build-packages.sh` generates tarballs and index at release time

### Commands content class (#167)
- `commands` is the 7th package content class in `cn.package.json`
- `cn_command.ml`: discovery + dispatch (built-in > repo-local > package)
- `cn help` lists external commands with source and summary
- `cn doctor` validates command integrity (duplicates, missing entrypoints, non-executable, malformed)
- `.cn/commands/` repo-local commands discoverable

### CDD process improvements (#167)
- §2.5a: delegated implementation handoff protocol + self-verification gate
- CDD.md §5.3: step 6f (delegated handoff) in artifact manifest
- Architecture-evolution skill §5: five L7 diagnostic patterns

### Also included
- #155: vendor offline-first short-circuit, manual vendor recognition, help surface
- #161: self-update checksum verification
- #146: review findings on hardcoded-paths removal
- Review PRE-GATE: verify branch is unmerged before reviewing
- Release tooling: `cn release` CLI removed, replaced by `scripts/release.sh`

## Breaking changes

- Lockfile format changed from `cn.deps.lock.v1` to `cn.lock.v2`. Existing lockfiles must be regenerated (`cn deps restore` will create a new one).
- `cn release` CLI command removed. Use `scripts/release.sh` instead.

## Design documents

- `docs/alpha/package-system/PACKAGE-ARTIFACTS.md` v0.5.0 — artifact-first distribution, NuGet model
- `docs/alpha/agent-runtime/ORCHESTRATORS.md` v0.1.0 — follow-up design for #170

## Upgrade

```sh
cn update
cn deps restore   # regenerates lockfile in v2 format
```
