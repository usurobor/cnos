# RELEASE.md

## Outcome

Coherence delta: C_Σ A (`α A+`, `β A`, `γ A`) · **Level:** `L7`

First runnable Go binary. `go build ./cmd/cn && ./cn deps restore` works end-to-end.

## Why it matters

cnos now has a Go CLI binary that dispatches commands through the architecture defined in GO-KERNEL-COMMANDS.md. The command model is modular: `CommandSpec` runtime descriptor, `Invocation` with IO streams, `Command` interface, `Registry` with tier precedence and availability filtering. Adding a command = one file + one constructor map entry. The kernel is a package.

This also validates CDD §7.0 (all findings resolved before merge) on its first use — PR #211 fixed F2+F3 from PR #210 review before merge landed.

## Added

- **Go CLI entrypoint** (`cmd/cn/main.go`): hub discovery, registry setup, dispatch. Unknown command → clear error + help hint. No hub → lists only hub-independent commands with ⚠ warning.
- **Command model** (`internal/cli/`): `CommandSpec`, `CommandSource`, `CommandTier`, `Invocation`, `Command` interface. Design authority: GO-KERNEL-COMMANDS.md v1.2.
- **Registry** (`internal/cli/registry.go`): Register with tier precedence, Lookup, All, Available(hasHub). Deterministic ordering for help.
- **deps command** (`internal/cli/cmd_deps.go`): `deps restore` wired to `internal/restore/`. Subcommand dispatch. User-facing output: `✓ Restored N package(s)` / `✗` on error.
- **help command** (`internal/cli/cmd_help.go`): lists available commands with summaries. Hides NeedsHub commands when no hub found.
- **CI**: `go build -o cn ./cmd/cn` step added to Go workflow.
- **CDD §7.0**: all review findings must be resolved before merge. No "approved with follow-up." Synced across review skill, CDD.md §5.5, packages/cnos.core.

## Fixed

- **F2** (from PR #210 R1): `envMap()` removed — commands use `os.Getenv` directly
- **F3** (from PR #210 R1): `joinArgs` replaced with `strings.Join`

## Validation

- 20 Go tests pass (7 pkg + 6 restore + 7 registry)
- CI green: go ✅ ocaml ✅ I2/I3 ✅
- Binary builds and dispatches `deps restore` end-to-end
- §7.0 gate validated: findings fixed on-branch before merge (PR #211)

## Known Issues

- I1 (package/source drift) failing due to opam infrastructure — not caused by code changes
- #209 Phase 2 complete; Phase 3 (remaining kernel commands) next
