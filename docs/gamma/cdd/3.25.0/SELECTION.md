# Selection — v3.25.0

## Observation Inputs

### CHANGELOG TSC (baseline)

v3.24.0: C_Sigma A, alpha A, beta A, gamma A-

### Encoding Lag (from v3.24.0 assessment)

| Issue | Title | Type | Design | Impl | Lag |
|-------|-------|------|--------|------|-----|
| #64 | P0: agent probes filesystem despite RC | bug | bug report | not started | **growing** |
| #74 | Rethink logs structure (P0) | process | issue spec | not started | growing |
| #59 | cn doctor — deep validation | feature | partial design | partially addressed | low |
| #68 | Agent self-diagnostics | feature | issue spec | not started | growing |
| #84 | CA mindset reflection requirements | feature | issue spec | not started | growing |
| #79 | Projection surfaces | feature | issue spec | not started | growing |
| #94 | cn cdd: mechanize CDD invariants | feature | issue spec | not started | growing |
| #100 | Memory as first-class capability | feature | issue spec | not started | growing |
| #96 | Docs taxonomy alignment | process | issue spec | not started | growing |
| #101 | Normalize skill corpus | process | issue spec | not started | growing |
| #20 | Eliminate silent failures in daemon | bug | issue spec | not started | growing |
| #43 | No interrupt mechanism | feature | issue spec | not started | growing |
| #124 | Agent asks permission despite autonomy defaults | bug | issue spec | not started | growing |

### Last Post-Release Assessment

v3.24.0 assessment committed #64 as next MCA:
> "Last remaining P0 bug. #119 and #117 now shipped. #64 is the oldest open P0 (v3.11.0)."

## Selection Rules Applied

1. **P0 override (CDD section 3.1):** #64 is the last remaining P0 bug.
2. **Assessment commitment default (CDD section 3.3):** v3.24.0 assessment committed #64 as next MCA.
3. **Prior closure was premature:** Issue was closed on 2026-03-27 via "closure by verification" with no new code. The fix was purely instructional (RC text says "don't probe"). The v3.24.0 assessment — the most recent — still lists #64 as growing lag. Reopened.

## Why #64

The agent probes the filesystem for self-knowledge (version, config) despite the Runtime Contract declaring that information in packed context. The current "fix" is instructional — RC text says "Do not read cn.json." But the executor still processes the probe and returns `file_not_found`, wasting tokens and passes. No structural mechanism prevents probing.

An L7 boundary move is available: intercept self-knowledge probes at the executor level and return a `contract_redirect` response, making probing structurally unable to succeed.
