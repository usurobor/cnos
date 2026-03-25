# v3.18.0 — Runtime Extensions Phase 2

**Issue:** #73 — Runtime Extensions: Capability Providers, Discovery, and Isolation
**Phase:** 2 — Subprocess host binary + policy intersection
**Branch:** `claude/3.18.0-73-runtime-extensions-p2`
**Mode:** MCA
**Base:** v3.17.0 (Phase 1 shipped)

## Gap

The extension architecture is type-complete but not runtime-complete. `cn_ext_host.ml` dispatches to a subprocess that doesn't exist. Three ACs remain partial (AC1, AC5, AC7) because no extension can actually execute.

## Active skills (CDD §4.4)

Hard generation constraints — all code must satisfy these before being written:

1. **eng/ocaml** — §3.1 type safety, §3.3 Result types, §2.6 no partial functions, §3.5 build-before-push
2. **eng/testing** — §3.1 start from invariants, §3.6 negative space mandatory, §3.2 match proof to claim

All other skills are reference only.

## Deliverables

| Artifact | Status |
|----------|--------|
| README.md (this file) | done |
| SELF-COHERENCE.md | stub |
| Code: subprocess host binary (`cnos-ext-http`) | pending |
| Code: policy intersection (domain allowlists) | pending |
| Code: build integration (`cn build` copies extensions) | pending |
| Tests: host protocol end-to-end | pending |
| Tests: policy enforcement negative space | pending |

## ACs to close

| AC | Current | Target |
|----|---------|--------|
| AC1 | partial (build integration pending) | full |
| AC5 | partial (policy intersection pending) | full |
| AC7 | partial (no host binary) | full |
