# RELEASE.md

## Outcome

Coherence delta: C_Σ A (`α A`, `β A`, `γ A`) · **Level:** `L7`

Move 2 of the core refactor (#182) is complete. The pure-model extraction phase that began in v3.38.0 closes with the fourth and final slice: activation frontmatter parser + validation types into `src/lib/cn_frontmatter.ml`. Every pure type and parser in the codebase now lives in `src/lib/`; every IO function lives in `src/cmd/`. The boundary is structural, not conventional. The Go kernel rewrite (#192) has its contract.

## Why it matters

This release closes a 4-cycle architectural extraction. The boundary between pure model and IO code is now visible in the build system — `src/lib/` is a dune library that cannot import IO modules. This means the Go rewrite has a mechanically verifiable type spec to implement against, not a design doc to interpret. The CDD role model also reached its final form: reviewer → releaser → assessor is now the default path, with explicit role ownership per lifecycle step.

## Changed

- **Move 2 slice 4** (#201, PR #202): `cn_frontmatter.ml` — 12 pure surface items extracted. 21 tests. 1 review round, 0 findings.
- **Move 2 complete.** 5 pure modules in `src/lib/`. Boundary map closed.
- **CDD §1.4 Roles**: Two-agent minimum, reviewer-default releaser, Role column in lifecycle table, small-change exception, Implementer role.
- **CDD post-release ownership**: Releasing agent owns steps 11–13.

## Added

- **TypeScript skill** (`eng/typescript`): Schema-backed boundaries, branded primitives, explicit error policy, mutation discipline, idempotence/receipts. Registered in `cnos.eng`.

## Validation

- CI green on all checks (ocaml build+test, protocol contract, package drift).
- First Move 2 cycle with zero review findings — §2.5b checks 7+8 validated.
- Post-release assessment pending (this release).

## Known Issues

- #192 — Go kernel rewrite (unblocked by Move 2 completion, not yet started).
- #180 — Beta package doc retirement (Move 3, pending).
- #193 — `llm` step execution (carried 5+ cycles).
