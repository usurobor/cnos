# R2 — Round-trip kata

**Tier:** 2 — runtime/package
**Class:** runtime
**Proves:** author → build → install → dispatch round-trip.

## Scenario

A new package, authored from scratch in an isolated workdir, can be
built, locked, restored, and its command dispatched from a fresh hub.
No touching of the real repo.

## Pass condition

- `cn build` produces `$WORKDIR/dist/packages/<fixture>-<ver>.tar.gz`.
- `cn deps lock && cn deps restore` installs it into a sub-hub.
- Dispatching the fixture's command prints the expected marker and
  exposes the dispatch env vars (`CN_HUB_PATH`, `CN_PACKAGE_ROOT`,
  `CN_COMMAND_NAME`).

## Inputs

Self-contained: the kata authors a `kata-rt-fixture` package under a
tempdir, exercises the full pipeline there, and cleans up on exit.
The repo outside the tempdir is not modified.
