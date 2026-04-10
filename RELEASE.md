# RELEASE.md

## Outcome

Coherence delta: C_Σ A (`α A+`, `β A+`, `γ A+`) · **Level:** L7

Go kernel gains `build` command — package assembly from source trees with tarball distribution. Architectural invariants are now a first-class validated surface across the full CDD lifecycle: author loads, handoff names, reviewer verifies, assessor confirms.

## Why it matters

This cycle closes two gaps: (1) the kernel can now build packages, completing Slice C of Phase 3, and (2) the architectural constraints that were previously implicit are now explicit, documented, and validated at every CDD touchpoint. The eng/go skill now has concrete rules for the purity boundary and dispatch boundary, both deriving from INVARIANTS.md — prevention at coding time, not just detection at review.

## Added

- **Go kernel `build` command** (#219, PR #220): three modes — `cn build` (assemble tarballs + index + checksums), `cn build --check` (CI drift verification), `cn build clean` (remove artifacts). Pure/IO split: `ParseManifestData` pure, `ReadManifest` IO wrapper.
- **Architectural invariants doc** (`INVARIANTS.md`): 6 active invariants (one package substrate, language-neutral metadata, distinct runtime surfaces, kernel-owned policy, protocol above transport, hub state ≠ source), 5 transition constraints, 3 process constraints. Validated each CDD cycle.
- **CDD invariants lifecycle**: project invariants loaded at §2.4 (pre-coding), §2.5a item 5 (handoff), review §2.2.13 (verification), post-release §6a (confirmation).
- **eng/go §2.17**: Parse/Read purity boundary — derives from INVARIANTS.md T-004.
- **eng/go §2.18**: cli/ dispatch boundary — derives from INVARIANTS.md T-002.
- **Build-and-Distribution design doc**: independent package versioning (`package version ≠ binary version`), `src/packages/` → `dist/packages/` → `.cn/vendor/`, plain tarballs as artifact format.
- **cli/ extraction issue** (#221): dispatch boundary enforcement — domain logic must leave `cli/`.

## Changed

- **CDD review §2.2.13**: generic project design constraints check (any project with INVARIANTS.md gets the gate).
- **CDD §2.5**: pre-coding gate — load engineering skills AND project invariants before writing code.

## Validation

- Go binary builds: `cn help` lists 6 kernel commands (help, init, deps, status, doctor, build).
- 35 Go tests pass. CI green on all checks.
- `cn build --check` validates packages on VPS.

## Known Issues

- #221 — cli/ extraction (dispatch boundary enforcement, filed this cycle)
- #193 — encoding lag (growing, 11 cycles)
- #186 — encoding lag (design doc shipped)
- #175 — encoding lag (growing)
