# R3 — Round-trip Kata

**Class:** runtime
**Purpose:** Prove a newly authored package command flows through source → build → install → dispatch.
**Requires:** cn >= 3.52.0

## Scenario

Add a custom test command to cnos.core, build, install, dispatch, verify env vars are set. Clean up after.

## Inputs

- cnos repo with `src/packages/cnos.core/`
- writable manifest

## Exact commands

```bash
# Author: add kata-test command to cnos.core manifest + entrypoint script
cn build
cn deps lock
cn deps restore
cn kata-test
# Verify: output contains CN_HUB_PATH, CN_PACKAGE_ROOT, CN_COMMAND_NAME
```

## Pass conditions

- kata-test command added to manifest
- cn build succeeds with the new command
- cn deps restore installs the package
- cn kata-test dispatches and produces expected env var output
- cleanup restores original manifest
