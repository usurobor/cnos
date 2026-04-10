# RELEASE.md

## Outcome

Coherence delta: C_Σ A (`α A`, `β A+`, `γ A`) · **Level:** L6

Go kernel gains `doctor` command — hub health validation. Architecture design frontier advances: git-cn package shape, package restructuring target, capabilities field in extension manifests.

## Why it matters

The kernel now validates its own health: prerequisites, hub structure, package drift, runtime contract integrity, git remote. This is the foundation for self-diagnosis before `cn update` or `cn build` become available. The design docs make the full target shape explicit — package restructuring, polyglot provider packages, and the first Rust transport package.

## Added

- **Go kernel `doctor` command** (#212 Slice B, PR #217): 15+ checks across 5 categories — prerequisites, hub structure, package system, runtime contract, git remote. Advisory ✓ for optional files, actionable ✗ with fix suggestions for failures.
- **git-cn package design** (#218): `cnos.transport.git` — command form for operators, provider form for runtime, Rust implementation.
- **Package restructuring target** (#186): lean `cnos.core` + domain-aligned packages (cnos.agent, cnos.cdd, cnos.hub, cnos.net.http).
- **`capabilities` field** in `cn.extension.v1`: high-level capability families for policy/doctor/runtime-contract. No new manifest type — one field addition.
- **Kernel command migration issue** (#216): non-bootstrap commands (status, doctor, build, setup) should migrate to `cnos.core` packages post-Phase 4.

## Changed

- **cn.extension.v1** gains optional `capabilities` field (RUNTIME-EXTENSIONS.md §5.1a).
- **Provider Contract v1** updated: uses `cn.extension.v1` manifest (not a separate `cn.provider.v1`). Stricter describe matching rule.
- **Polyglot Packages doc** aligned to `cn.extension.v1` with `capabilities`.

## Validation

- Go binary builds: `cn help` lists 5 kernel commands (help, init, deps, status, doctor).
- `cn doctor` validates hub health on VPS.
- All 30 Go tests pass. CI green on all checks.

## Known Issues

- #193 — encoding lag (growing, 10 cycles)
- #186 — encoding lag (growing, design doc now shipped)
- #175 — encoding lag (growing)
