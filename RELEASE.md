# RELEASE.md

## Outcome

Coherence delta: C_Σ A+ (`α A+`, `β A`, `γ A+`) · **Level:** L5

Dispatch boundary enforced: cli/ is now dispatch-only with CI enforcement. Domain logic extracted to dedicated packages. INVARIANTS.md T-002 is mechanical — a `cmd_*.go` file importing `os`, `encoding/json`, or `path/filepath` fails CI.

## Why it matters

This is the first architectural invariant enforced by machine, not just by reviewers. The leak class that produced #221 (doctor logic inline in cli/) is now impossible to reintroduce without CI failure. The CDD invariants chain (author loads → handoff names → reviewer verifies → assessor confirms → CI enforces) is complete for this constraint.

## Changed

- **cli/ extraction** (#221, PR #222): domain logic extracted from `cli/` into dedicated packages:
  - `cmd_doctor.go` 238→44 lines → `internal/doctor/`
  - `cmd_init.go` 131→27 lines → `internal/hubinit/`
  - `cmd_status.go` 76→27 lines → `internal/hubstatus/`
  - `FindIndexPath` → `internal/restore/`
  - `cmd_deps.go` and `cmd_build.go` already correct (unchanged)
- **CI dispatch boundary check** (`.github/workflows/go.yml`): greps `cmd_*.go` for prohibited imports. T-002 is now mechanical.
- **INVARIANTS.md v1.2.0**: title normalized to "Architectural Invariants", stale `DESIGN-CONSTRAINTS.md` reference removed from review skill.

## Validation

- Go binary builds: `cn help` lists 6 kernel commands (help, init, deps, status, doctor, build).
- All Go tests pass (35 tests across 6 packages: cli, pkg, restore, pkgbuild, doctor, hubinit, hubstatus).
- CI dispatch boundary check passes — no `cmd_*.go` imports prohibited packages.

## Known Issues

- #193 — encoding lag (growing, 12 cycles)
- #186 — encoding lag (design doc shipped)
- #175 — encoding lag (growing)
