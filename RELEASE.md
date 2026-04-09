# RELEASE.md

## Outcome

Coherence delta: C_Σ A (`α A`, `β A`, `γ A`) · **Level:** `L6`

The pure model layer in `src/lib/` doubled from 2 modules to 4, now covering the two largest pure surfaces in the codebase: runtime contract types and workflow IR. The CDD pre-review gate gained two new mechanical checks that close the failure classes from the previous two cycles. A Go skill was converged to govern the upcoming kernel rewrite.

## Why it matters

Move 2 of the core refactor (#182) is 3/4 complete. The boundary between pure model and IO code is now structurally visible in 4 of 5 target modules. This boundary map is the contract the Go rewrite (#192) will implement against. The type-equality re-export pattern has been validated at scale — including 6-variant and 7-variant types with inline-record payloads. The CDD gate tightening (#198) means future slices will not leak mechanical failures into review rounds.

## Added

- **Go skill** (`eng/go`): Runtime/kernel Go craft skill for cnos, converged through 4 iterations. Registered in `cnos.eng`.
- **CDD §2.5b checks 7+8** (#198): Library-name uniqueness + CI-green-before-review.
- **Telegram CI notifications**: All 3 workflows notify on success/failure.

## Changed

- **Move 2 slice 2** (#194, PR #195): 11 runtime contract types → `src/lib/cn_contract.ml`. 13 tests. 2 review rounds.
- **Move 2 slice 3** (#196, PR #197): 6 types + 10 pure functions → `src/lib/cn_workflow_ir.ml`. 20 tests. 2 review rounds.
- **CORE-REFACTOR.md §7**: stderr discipline documented. v3.39.0 + v3.40.0 status blocks.
- **`src/lib/`**: 4 pure modules. Move 2 is 3/4 complete.

## Fixed

- Go skill package placement (cnos.core → cnos.eng).
- v3.38.0 lag table TBD → #193.

## Validation

- CI green on all 3 checks (ocaml build+test, protocol contract, package drift).
- Post-release assessments pending (#199).

## Known Issues

- #199 — stacked v3.39.0 + v3.40.0 post-release assessments not yet written.
- #182 — Move 2 slice 4 (activation evaluator) remaining.
- #180 — beta package doc retirement (Move 3) pending.
