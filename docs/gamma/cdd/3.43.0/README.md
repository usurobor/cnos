## CDD Bootstrap — v3.43.0 (#205: Go kernel Phase 1)

**Issue:** #205 — Go kernel Phase 1: package index / lockfile / restore (#192 umbrella)
**Branch:** `claude/go-205-restore`
**Level:** L7 — new system boundary (Go module alongside OCaml); additive; first Go code in cnos
**Skills:** cdd (§1.4 + §2.5b 8-check), eng/go (loaded + read before writing any Go)

### Gap

`cn deps restore` exists only in OCaml. The Go kernel rewrite (#192) starts with restore because it has clear inputs/outputs, no runtime entanglement, and proves the Go approach. After Move 2 completed (v3.42.0), `src/lib/` holds the pure type spec; the Go module mirrors those types and reimplements the IO path.

### ACs

1. Go binary parses `packages/index.json` (schema `cn.package-index.v1`)
2. Go binary parses `.cn/deps.lock.json` (schema `cn.lockfile.v1`)
3. End-to-end restore: lockfile → index lookup → HTTP download → SHA-256 verify → tar extract → validate `cn.package.json`
4. Parity-compatible output with OCaml (same installed path, same extracted file bytes, same manifest validation)
5. Tests: index lookup hit/miss, lockfile round-trip, SHA-256 mismatch rejection, manifest validation
6. CI workflow runs `go test ./...` on push

### Plan

| Stage | Scope | ACs |
|-------|-------|-----|
| A | `go/internal/pkg/` — pure types + tests (7 tests) | AC1, AC2, AC5 |
| B | `go/internal/restore/` — HTTP restore + tests (6 tests) | AC3, AC4, AC5 |
| C | `.github/workflows/go.yml` — CI workflow | AC6 |
| D | CDD artifacts | — |
| E | §2.5b 8-check + draft PR + CI green + ready-for-review | — |

### CDD Trace

| Step | Decision |
|------|----------|
| 0 Observe | Move 2 complete (v3.42.0); Go skill shipped; #192 umbrella unblocked; #205 filed |
| 1 Select | #205 (first Go code — proves the approach) |
| 2 Branch | `claude/go-205-restore` |
| 3 Bootstrap | this file |
| 4 Gap | restore exists only in OCaml; Go module starts the kernel rewrite |
| 5 Mode | MCA, L7, eng/go + cdd |
| 6 Artifacts | Go code (tests-alongside, not tests-before for Go convention) + CI workflow |
| 7 Self-coherence | SELF-COHERENCE.md (pending) |
| 7a Pre-review | §2.5b 8-check (all formal); Go available locally so check 8 = local test pass + draft-until-CI-green |
| 8 Review | PR body (reviewer = user per §1.4) |
| 9–13 | Release/assess = user per §1.4 |
