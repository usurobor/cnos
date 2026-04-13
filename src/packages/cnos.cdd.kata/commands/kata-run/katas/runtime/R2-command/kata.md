# R2 — Command Kata

**Class:** runtime
**Purpose:** Prove package command discovery and dispatch works.
**Requires:** cn >= 3.52.0

## Scenario

Build packages from repo source, install via restore, verify `cn daily` dispatches from installed package. Verify `cn help` shows package commands with source attribution.

## Inputs

- cnos repo with `src/packages/` containing cnos.core (declares daily/weekly/save commands)
- Go binary with command discovery (>= 3.52.0)

## Exact commands

```bash
cn build
cn deps lock
cn deps restore
cn help
cn daily
```

## Required artifacts

- dist/packages/ tarballs + index
- .cn/vendor/packages/ installed packages
- cn help output showing tiered commands
- cn daily dispatch result

## Pass conditions

- cn build produces >= 3 tarballs
- cn deps restore installs packages
- cn help shows "daily" with package attribution
- cn daily dispatches (exit code irrelevant — stateful error is acceptable, "unknown command" is not)
