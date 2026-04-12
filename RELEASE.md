# RELEASE.md

## Outcome

Coherence delta: C_Sigma A (`alpha A`, `beta A`, `gamma A-`) · **Level:** L6

**Package and repo-local command discovery closes the "one model" gap.** Three source forms (kernel, repo-local, package-vendored) now normalize into the same `CommandSpec`, register into the same `Registry`, and dispatch through the same `Command` interface. The kernel's command model is no longer a special case — it's an instance of its own runtime command descriptor.

## Why it matters

Since v3.37.0, package commands (daily, weekly, save) have been installable through `cn deps restore` but invisible to the Go kernel — the CLI only knew about its 8 built-in kernel commands. This meant `cn daily` failed even though the command was correctly installed at `.cn/vendor/packages/cnos.core/commands/daily/cn-daily`. This cycle closes the gap described in GO-KERNEL-COMMANDS.md Phase 4: the kernel discovers all installed commands and dispatches them uniformly.

## Added

- **Package command scanning** (#226): `discover.ScanPackageCommands` walks `.cn/vendor/packages/*/cn.package.json`, parses `commands` entries, creates exec-backed `Command` implementations.
- **Repo-local command scanning** (#226): `discover.ScanRepoLocalCommands` walks `.cn/commands/cn-*`, creates `Command` from filename convention.
- **External command dispatch** (#226): `ExecCommand.Run()` execs entrypoint scripts with `CN_HUB_PATH`, `CN_PACKAGE_ROOT`, `CN_COMMAND_NAME` env vars.
- **Tiered help output** (#226): `cn help` groups by Kernel / Repo-local / Package with `[pkg-name]` attribution.
- **Command integrity validation** (#226): `cn doctor` reports missing entrypoints, non-executable files, duplicate names within tier.
- **Path confinement** (#226): entrypoints validated to stay within package directory.

## Changed

- **`doctor.RunAll` signature** (#226): accepts optional `commandIssues` for integrity reporting.

## Validation

- All 11 Go test packages pass (79+ tests).
- `go build ./...` clean.
- Round-trip: `cn build` -> `cn deps restore` -> `cn daily` dispatches correctly.
- `cn help` shows all three tiers with correct attribution.
- `cn doctor` shows "command integrity: all commands valid".
- CI green on merge (5/5 checks: go, I1, I2, notify x2).

## Known Issues

- Repo-local commands show generic `(repo-local command)` summary — no sidecar metadata yet (GO-KERNEL-COMMANDS.md defers to future version)
- #230 — `cn deps restore` skips version upgrades silently
- #224 — Layout migration remaining ACs
