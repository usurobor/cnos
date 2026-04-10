# RELEASE.md

## Outcome

Coherence delta: C_Σ A (`α A`, `β A`, `γ A`) · **Level:** `L7`

First Go code in cnos. The runtime kernel rewrite begins with package restore — the most self-contained subsystem, proving the Go approach before touching command dispatch or orchestration.

## Why it matters

The OCaml toolchain has been an environmental constraint for 9+ authoring cycles. The Go kernel rewrite (#192) was blocked on Move 2 (pure type extraction) and #180 (doc authority convergence) — both now shipped. This release proves that Go can faithfully reimplement the package restore path against the `src/lib/` type spec, with structural parity in installed output.

A new system boundary exists: Go module alongside OCaml. The kernel transitions; the content classes stay language-agnostic.

## Added

- **Go kernel Phase 1** (#205, #192 umbrella): `go/` subtree with `internal/pkg/` (pure types mirroring `src/lib/cn_package.ml`) and `internal/restore/` (HTTP restore mirroring `src/cmd/cn_deps.ml`). Module: `github.com/usurobor/cnos/go`, Go 1.22, stdlib-only, zero external deps. 13 tests covering index lookup, lockfile round-trip, end-to-end restore with httptest, SHA-256 mismatch rejection, manifest validation, already-installed skip.
- **Go CI workflow** (`.github/workflows/go.yml`): `go build`, `go test`, `go vet` on `go/**` path changes. Telegram notifications.

## Validation

- CI green on all 4 checks (ocaml, I1, I2/I3, go) — first push, zero draft iterations
- `TestRestoreEndToEnd`: httptest server → download → SHA-256 verify → extract → validate manifest → same vendor path as OCaml
- `TestReadPackageIndex`: parses live `packages/index.json` from repo
- Directory traversal protection in `extractTarGz`
- OCaml CI unaffected (Go workflow triggers only on `go/**` paths)

## Known Issues

- F2: `http.DefaultClient` has no timeout (OCaml: curl `--connect-timeout 10 --max-time 300`) — follow-up
- F3: Traversal check should append `filepath.Separator` to destDir — security hardening follow-up
- F4: `ReadLockfile`/`ReadPackageIndex` do IO in the "pure" `pkg` package — should move to `internal/restore/` to mirror `src/lib/` vs `src/cmd/` purity boundary — follow-up
