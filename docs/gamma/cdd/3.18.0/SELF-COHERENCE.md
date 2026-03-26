# v3.18.0 Self-Coherence — Package System Substrate

**Issue:** #113
**Active skills:** eng/ocaml, eng/testing, eng/coding

## AC Status

| AC | Description | Status |
|----|-------------|--------|
| AC3 | Restore installs full package content | done |
| AC4 | Third-party handling explicit | done |

## Triad Scores

| Dimension | Score | Notes |
|-----------|-------|-------|
| α (structural) | — | pending review |
| β (alignment) | — | pending review |
| γ (process) | — | pending review |

## Active Skill Compliance

### eng/ocaml
- Result types: `lockfile_for_manifest` returns `(lockfile, string) result` — no silent empty entries
- No partial functions: all pattern matches exhaustive
- Type safety: callers updated to handle Result

### eng/testing
- Invariant-first: each test names its invariant (I1–I4)
- Negative space: explicit test that no lock entry has empty source
- Match proof to claim: tests verify the exact categories restored

### eng/coding
- Pattern match preferred over if/else chains
- Minimal complexity: third-party rejection is a filter + error, not a complex resolver
- No premature abstraction: categories listed explicitly, not derived from a schema parser

## Changes

| File | Change |
|------|--------|
| `src/cmd/cn_deps.ml` | `restore_one` copies 5 categories (was 3); `lockfile_for_manifest` returns Result, rejects third-party |
| `src/cmd/cn_system.ml` | Both callers updated to handle Result from `lockfile_for_manifest` |
| `test/cmd/cn_deps_test.ml` | 7 tests: full restore (2), third-party rejection (2), first-party valid (2), negative space (1) |
| `test/cmd/dune` | Added cn_deps_test library stanza |
