# v3.18.0 — Package System Substrate

**Issue:** #113 — Implement the Git-native package system substrate
**Branch:** `claude/3.18.0-113-package-system`
**Mode:** MCA
**Base:** v3.17.0
**Design:** `docs/beta/architecture/PACKAGE-SYSTEM.md`

## Gap

cnos has the right package-system spine but not a complete substrate. `restore_one` copies only doctrine/mindsets/skills, missing extensions/profiles. Third-party lock entries use empty source/subdir with wrong-repo rev.

## Active skills (CDD §4.4)

Hard generation constraints:

1. **eng/ocaml** — §3.1 type safety, §3.3 Result types, §2.6 no partial functions, §3.5 build-before-push
2. **eng/testing** — §3.1 start from invariants, §3.6 negative space mandatory, §3.2 match proof to claim
3. **eng/coding** — prefer pattern match, no premature abstraction, minimal complexity

All other skills are reference only.

## Scope (Steps 1-2 of #113)

| Step | Description | Status |
|------|-------------|--------|
| 1 | Full package restore — install full declared content, not only doctrine/mindsets/skills | done |
| 2 | Honest third-party handling — explicitly reject or properly resolve non-first-party lock entries | done |
| 7 | Build/check/clean for full content classes (cherry-picked from #112) | done |

## Deliverables

| Artifact | Status |
|----------|--------|
| README.md (this file) | done |
| SELF-COHERENCE.md | done |
| Code: cn_deps.ml restore_one — full content copy | done |
| Code: cn_deps.ml lockfile_for_manifest — honest third-party | done |
| Tests: restore copies extensions | done |
| Tests: third-party rejection/handling | done |

## ACs addressed (from #113)

| AC | Description | Target |
|----|-------------|--------|
| AC3 | Restore installs full package content | full |
| AC4 | Third-party handling explicit | full |
