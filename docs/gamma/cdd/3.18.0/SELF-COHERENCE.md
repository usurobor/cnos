# Self-Coherence Report — v3.18.0

**Issue:** #73 — Runtime Extensions Phase 2
**Branch:** `claude/3.18.0-73-runtime-extensions-p2`
**Mode:** MCA
**Date:** 2026-03-25
**Active skills:** eng/ocaml (hard), eng/testing (hard)

## AC Status

| # | AC | Status | Evidence |
|---|-----|--------|----------|
| AC1 | Package ships extension without core changes | **PASS** | `cn build` copies `extensions/` category from `src/agent/extensions/` to packages. `cnos.core` package manifest declares `"extensions": ["cnos.net.http"]`. Build, check, and clean all include extensions. |
| AC5 | Sandboxed and traced | **PASS** | `effective_permissions` computes extension-declared ∩ runtime-allowed. Secrets always stripped to empty array. Limits derived from shell_config. Executor passes permissions and limits to host protocol. |
| AC7 | cnos.net.http proves model | **PASS** | Shell script host binary at `src/agent/extensions/cnos.net.http/host/cnos-ext-http` implements describe/health/execute/shutdown. Tests prove: describe returns metadata, health returns ok, unknown ops rejected, missing URL rejected, non-http schemes rejected. |

## Triad Score

| Axis | Score | Notes |
|------|-------|-------|
| α (structural) | A | Policy intersection is pure function. Build integration follows existing pattern. Host binary is language-agnostic (shell script). No new type ambiguity. |
| β (relational) | A- | Full pipeline wired: build copies extensions → registry discovers → executor applies policy → host executes. Gap: host binary not yet on PATH in production (requires install step). |
| γ (process) | A- | Active skills applied as generation constraints (not post-hoc). Tests written with named invariants. Negative space tested (3 rejection cases). Gap: no property tests for policy intersection (example tests only). |

**Weakest axis:** β — host binary exists and passes tests but isn't installable to PATH without manual setup.

## Active Skill Compliance

### eng/ocaml
- §3.1 Type safety: No new overlapping field names. PASS.
- §3.3 Error handling: Pure functions return values (no Result needed). PASS.
- §2.6 Anti-patterns: No List.hd, no ref, no bare `with _ ->` in new code. PASS.
- §3.5 Build-before-push: Verified locally. PASS.

### eng/testing
- §3.1 Invariant-first: Each test block has named invariant in comment. PASS.
- §3.6 Negative space: unknown op, missing URL, bad scheme — all tested. PASS.
- §3.2 Proof strength: Example tests for pure functions, integration tests for subprocess host. PASS.
- §2.7 "What must never happen?": Secrets never passed to host, non-http schemes never fetched. PASS.

## Known Debt

1. **Host binary install path**: `cnos-ext-http` is at source path, not on PATH. Requires `cn install` or manual symlinking. Not blocking for type-proof but blocking for production use.
2. **Property tests for policy**: `effective_permissions` tested with 3 examples, not property-based. Example tests prove the invariant for specific cases; property tests would prove it for all permission combinations.
3. **Pre-existing bare `with _ ->`**: 4 instances in `cn_build.ml` (copy_tree, rm_tree, copy_source, discover_packages) predate this PR. Not in diff, but noted as debt.
