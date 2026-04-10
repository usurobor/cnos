# RELEASE.md

## Outcome

Coherence delta: C_Σ A (`α A+`, `β A`, `γ A`) · **Level:** `L6`

Go purity boundary corrected. Three eng skills converged. Two architecture design docs shipped.

## Why it matters

v3.43.0 introduced the first Go code but left a β gap: `internal/pkg/` claimed "no IO" but contained `ReadLockfile`/`ReadPackageIndex`. That's now fixed — the Go module mirrors the OCaml `src/lib/` vs `src/cmd/` purity split exactly. The boundary discipline that Move 2 established in OCaml now carries into Go.

The command architecture design (GO-KERNEL-COMMANDS.md) converged through 3 review iterations to a clean model: one runtime descriptor, one registry, three source forms. The kernel is a real `cn.package.v1` manifest — the platform is an instance of its own model.

## Fixed

- **Go purity boundary** (#207, PR #208): `ReadLockfile`/`ReadPackageIndex` moved from `internal/pkg/` to `internal/restore/`. `pkg` now exports `Parse*` (pure, `[]byte`); `restore` wraps with `Read*` (IO, path). `ValidatePackageManifest` → `ValidatePackageManifestData` follows same split. Zero `os` imports in `internal/pkg/`.
- **HTTP timeout** (F2): `httpClient` with 300s timeout, matching OCaml curl `--connect-timeout 10 --max-time 300`.
- **Traversal hardening** (F3): `filepath.Separator` appended to destDir before prefix check.
- **Test cleanup** (F1): `contains`/`containsAt` replaced with `strings.Contains`. Live index test no longer hardcodes specific version.

## Added

- **OCaml skill v2**: full L6 rewrite — frontmatter, determinism/reproducibility, idempotence/receipts, cnos runtime boundaries, two kata. All 3 eng skills (Go, TypeScript, OCaml) at same standard.
- **GO-KERNEL-COMMANDS.md** (v1.2): the kernel is a package. `CommandSpec` runtime descriptor, `Invocation` with IO streams, `Command` interface (`Spec()` + `Run()`), 3-tier precedence, `Available(hasHub)` filtering. Kernel manifest is real `cn.package.v1`. Prior art: Git subcommands, Cargo, kubectl, npm bin.
- **HYBRID-LLM-ROUTING.md** (v0.1): body-plane routing matrix for local/remote/escalation model selection. Thresholds (8k/12k tokens, depth, file count, task class), mandatory receipts, no silent provider swap. Implementation deferred.

## Validation

- CI green: go ✅ ocaml ✅ I2/I3 ✅
- I1 drift resolved by this release (packages/index.json updated)
- `internal/pkg/` imports: `encoding/json`, `fmt` only — verified by grep
- All 13 Go tests pass

## Known Issues

- #209 (Go kernel Phase 2: CLI dispatch) — next implementation target
- HYBRID-LLM-ROUTING.md — design only, implementation deferred
