# R3 — Doctor (broken) kata

**Tier:** 2 — runtime/package
**Class:** runtime
**Proves:** `cn doctor` catches broken installed-package state.

## Scenario

With at least one package installed and the hub otherwise clean, we
deliberately break one piece of installed state (a command entrypoint
is stripped of its exec bit). `cn doctor` must exit non-zero and emit
at least one `✗` broken-check line.

## Pass condition

- Before break: `cn doctor` exits 0 (`✗`-free) on the fresh hub.
- After break: `cn doctor` exits non-zero AND the output contains a
  `✗` line. Broken state is visible, not silent.

## Inputs

Self-contained: creates a temp hub under `$TMPDIR`, restores `cnos.core`
locally via the repo's `dist/packages/`, breaks
`.cn/vendor/packages/cnos.core/commands/daily/cn-daily`, then asserts
doctor's reaction.
