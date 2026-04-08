# v3.35.0

## Outcome

Coherence delta: C_Σ A- (`α A`, `β A-`, `γ B+`) · **Level:** `L6`

The runtime contract now exposes the activation surface — which skills exist, what triggers them, and what commands and orchestrators are available. The agent's self-model gained three new registries that were previously invisible. Silent error suppression eliminated across both runtime-contract and activation modules.

## Why it matters

Before this release, the runtime contract's cognition layer knew about installed packages but not about the skills, commands, or orchestrators inside them. Activation was implicit — the agent couldn't see its own trigger surface. This release makes that surface explicit and queryable, which is the prerequisite for #174 (orchestrator IR runtime).

The process gap matters too: PR #176 shipped without CDD review. The retro-review proved the code was correct, but the process violation was real. The corrective artifact (PR #177) and the mechanical gate (WORKFLOW_AUTO.md) close that gap.

## Added

- **Runtime contract activation index** (#173): `activation_index.skills` in cognition layer with declarative triggers from SKILL.md frontmatter.
- **Command and orchestrator registries** (#173): body layer exposes discovered commands and declared orchestrators.
- **ORCHESTRATORS.md** (#170): four-surface architecture design doc — skills, commands, orchestrators, extensions. CTB as source language, Effect Plan as IR.

## Changed

- **Markdown/JSON parity** (#177, F3): activation_index markdown now mirrors JSON two-level nesting.
- **Silent suppression eliminated** (#177, F1/F2/R2): all error paths in `cn_runtime_contract.ml` and `cn_activation.ml` now log with package context.
- **#170 dependency graph** corrected: #172 independent, #173 depends on #170, #174 owns orchestrator package-class.

## Fixed

- **Retro-review findings** (#177): all 5 findings from PR #176 post-merge retro addressed in code.

## Validation

- CI green on main (ocaml, I1 drift, I2/I3 traceability).
- 21 expect-tests in `cn_runtime_contract_test.ml`, 11 in `cn_activation_test.ml`.
- Zero bare `with _ ->` catches in touched modules.
- `scripts/check-version-consistency.sh` passes.

## Known Issues

- `cn_runtime_contract.ml` carrying significant rendering + registry + contract logic — module split is future cleanup.
- ~25 stale `claude/*` remote branches — cleanup deferred.
