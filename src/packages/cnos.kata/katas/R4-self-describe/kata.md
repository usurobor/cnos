# R4 — Self-describe kata

**Tier:** 2 — runtime/package
**Class:** runtime
**Proves:** `cn status` surfaces installed packages and discovered commands.

## Scenario

After at least one package is installed, `cn status` must report:

1. the hub identity (`cn hub: ...`)
2. the installed-packages section, including the installed package's
   name and version (read from its manifest)
3. the command registry including a command from that package

## Pass condition

- `cn status` exits 0.
- Output contains `cnos.core` (name) and its version.
- Output mentions a package-provided command (`daily`).

## Inputs

Self-contained: creates a temp hub under `$TMPDIR`, restores
`cnos.core`, then asserts `cn status` output. Uses the repo's
`dist/packages/index.json` as the source of truth for install.
