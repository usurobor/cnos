# RELEASE.md

## Outcome

Coherence delta: C_Σ A (`α A`, `β A+`, `γ A`) · **Level:** L6

Go kernel gains `init` and `status` commands with input validation. Architecture design frontier advances: polyglot package model and provider subprocess protocol now have canonical specs.

## Why it matters

The kernel is gaining hub-management parity with OCaml — `init` creates hubs, `status` inspects them with version drift detection. The confinement gap (#214) closed a real path-traversal vector in `init`. The two design docs (polyglot packages, provider contract) make explicit what was previously implied: the kernel stays Go, packages stay language-agnostic, providers execute via subprocess protocol.

## Added

- **Go kernel `init` command** (#212 Slice A, PR #213): creates hub with full directory structure, config.json, SOUL.md stub, git init. Mirrors OCaml `cn_system.ml::run_init`.
- **Go kernel `status` command** (#212 Slice A, PR #213): shows hub info + installed packages with version drift detection (✓/✗/⚠).
- **Polyglot Packages and Provider Contracts design doc**: Go kernel with language-agnostic packages. Commands vs providers as distinct execution contracts. One package substrate, polyglot payloads.
- **Provider Contract v1 spec**: subprocess protocol (spawn, handshake, describe, health, execute, shutdown). NDJSON over stdio. Kernel owns policy; providers execute within permission envelope.

## Fixed

- **hubName validation in `init`** (#214, PR #215): bare-name validation rejects path separators, `..`, empty strings. 11-case table-driven test. Closes confinement gap from PR #213 review.

## Changed

- **CI**: OPAMRETRIES=3 for transient opam fetch failures.
- **Package sync**: eng/go + eng/ocaml skills synced to `packages/cnos.eng/`.

## Validation

- Go binary builds: `cn help` lists 4 kernel commands (help, init, deps, status).
- `cn init testbot` creates valid hub; `cn init ../bad` rejected.
- `cn status` shows installed packages with version drift detection.
- All 26 Go tests pass. CI green on all checks.

## Known Issues

- #193 — encoding lag (growing, 9 cycles)
- #186 — encoding lag (growing)
- #175 — encoding lag (growing)
