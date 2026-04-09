# RELEASE.md

## Outcome

Coherence delta: C_Σ A (`α A`, `β A`, `γ A`) · **Level:** `L5`

Pure package types extracted from `src/cmd/cn_deps.ml` into `src/lib/cn_package.ml`. First slice of Move 2 (#182 core refactor). The pure model begins its gravity toward `src/lib/`.

## Why it matters

`src/cmd/` owned the canonical type definitions for package manifests, lockfiles, and the package index — mixing pure model with IO operations. Now the pure types live in `src/lib/` where they can be imported without pulling in filesystem, HTTP, or git dependencies. This is the pattern for the remaining three extraction slices (runtime contract, workflow IR, activation evaluator).

## Added

- **`src/lib/cn_package.ml`** (#182 Move 2): Canonical pure types — `manifest_dep`, `locked_dep`, `manifest`, `lockfile`, `index_entry`, `package_index`. 7 pure helpers: `manifest_dep_to_json`, `parse_manifest_dep`, `locked_dep_to_json`, `parse_locked_dep`, `parse_package_index`, `lookup_index`, `is_first_party`. Imports only stdlib + `Cn_json`.
- **11 ppx_expect tests** (`test/lib/cn_package_test.ml`): Round-trips (R1–R4), index parsing (P1–P3), lookup (L1–L2), first-party name check (F1–F2).
- **`docs/alpha/vision/AGENT-NETWORK.md`**: Vision document — cnos as a protocol for agents to exist as peers in a decentralized network.

## Changed

- **`src/cmd/cn_deps.ml`**: 6 type definitions replaced with type-equality re-exports (`type t = Cn_package.t = { ... }`). 7 pure helper bodies replaced with delegating let-bindings. IO functions untouched. Zero caller-side migration required.
- **`src/lib/dune`**: `cn_package` added to module list. Discipline comment added: no filesystem/git/process/HTTP/LLM code in this library.
- **`docs/alpha/agent-runtime/CORE-REFACTOR.md`**: §7 Move 2 status block — first slice shipped, three remaining.

## Validation

- CI green on merge commit (5825285): OCaml build + all tests + package/source drift + protocol traceability.
- Deployed to [target], validated with `cn --version` + `cn deps restore`.

## Known Issues

- Three Move 2 slices remaining: runtime contract types, workflow IR types, activation evaluator.
- `src/lib/` purity is enforced by convention (dune comment + grep) not by the build system. Acceptable at current scale.
