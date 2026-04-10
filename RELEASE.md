# RELEASE.md

## Outcome

Coherence delta: C_Σ A (`α A`, `β A+`, `γ A`) · **Level:** `L5`

Doc authority convergence: the package system now has a single story. CDD self-learning loop tightened with two mechanical gates.

## Why it matters

The beta package-system doc claimed Git-native transport while the alpha spec and shipped code (v3.34.0+) use artifact-first distribution via package index. Any reader of the beta doc got a false picture. With the Go kernel rewrite (#192) about to begin, the docs must agree on what the kernel implements against. They now do.

Separately, the v3.41.0 post-release assessment revealed a compaction gap: the assessment was written but hub memory was not, so the next session lost cycle context. The fix is MCA — a pre-publish gate check, not a "remember next time" commitment.

## Changed

- **Beta package-system doc retired** (#180): 620-line stale doc replaced with 18-line redirect stub pointing to alpha spec. Alpha doc §2.4 clarified: GitHub Releases is the current publishing surface, package index is the consumer-facing resolution authority. 4 cross-references updated.
- **#192 Go kernel rewrite scoped**: narrow 4-phase kernel extraction (package/index/restore → command registry → doctor/status/help/update → runtime contract). Explicit non-goals: skills, A2A workflows, package-authored behavior.

## Added

- **CDD post-release Step 7 — Hub Memory**: daily reflection + adhoc thread update mandatory before cycle close. Two pre-publish gate checks added. CDD.md §10.1/§10.3 updated.
- **CDD release §2.6a — Branch cleanup**: delete merged remote branches after tag+push. Mechanical, not judgment.

## Validation

- `scripts/check-version-consistency.sh` passes
- 13 merged branches cleaned (51 → 37 remote branches)
- Hub memory gate is structural: pre-publish checklist won't pass without §8 filled

## Known Issues

- 37 unmerged remote branches remain (open PRs or abandoned work — separate triage)
