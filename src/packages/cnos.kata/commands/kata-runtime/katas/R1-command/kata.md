# R1 — Command kata

**Tier:** 2 — runtime/package
**Class:** runtime
**Proves:** package command discovery + dispatch.

## Scenario

Given at least one installed package that exposes commands, the
kernel discovers those commands through `cn help` and can dispatch
one without reporting "unknown command".

## Pass condition

- `cn help` lists a command from an installed package (`daily` from `cnos.core`).
- `cn daily` is dispatched to its entrypoint. A non-zero exit from the
  dispatched command is acceptable (the command may require state);
  the failure mode being rejected is **"unknown command"**.

## Inputs

The kata relies on the hub it runs inside having `cnos.core` restored.
`cn kata-runtime` runs from an installed `cnos.kata` package — the
fact that this kata is being executed at all is weak proof that package
dispatch works; this kata makes the proof explicit.
