## Self-Coherence — v3.43.0 (#205: Go kernel Phase 1)

### Alpha (type-level clarity)

Go types in `internal/pkg/` mirror `src/lib/cn_package.ml` exactly:
- `ManifestDep` = `manifest_dep`, `LockedDep` = `locked_dep`, `Lockfile` = `lockfile`
- `PackageIndex` = `package_index`, `IndexEntry` = `index_entry`
- JSON field names match (`name`, `version`, `sha256`, `url`, `schema`, `packages`)
- `IsFirstParty` preserves the `len >= 5 && prefix == "cnos."` semantics

Restore flow in `internal/restore/` mirrors `cn_deps.ml::restore_one_http`:
- Same path convention: `.cn/vendor/packages/<name>@<version>/`
- Same tmp path: `.cn/tmp/<name>-<version>.tar.gz`
- Same validation: `cn.package.json` must exist, parse, and declare matching `name`
- SHA-256 verified against lockfile entry, not index entry (lockfile is the integrity authority)

**α: A** — structural fidelity between Go and OCaml types; additive (no OCaml changes)

### Beta (surface agreement)

- Go `PackageIndex` parses the live `packages/index.json` (verified by `TestReadPackageIndex`)
- Go `Lockfile` JSON matches OCaml schema `cn.lock.v2`
- CI workflow triggers on `go/**` paths only — no interference with OCaml CI
- Directory traversal protection in `extractTarGz` (security — OCaml delegates to `tar` which handles this; Go must do it explicitly)

**β: A** — Go types structurally agree with OCaml types and live data

### Gamma (cycle economics)

- Go toolchain available locally → `go test ./... && go vet ./...` verified before commit
- 13 tests pass locally (7 pkg + 6 restore)
- §2.5b check 8 is formal: draft PR until CI green
- eng/go skill loaded and read before writing any Go
- `errors.Is` bug caught and fixed locally (would have been a CI failure without local Go)
- stdlib-only, zero external dependencies

**γ: A** — local verification available; no mechanical failure should reach reviewer

### Exit criteria

- [x] AC1 Go parses index.json (TestReadPackageIndex against live data)
- [x] AC2 Go parses deps.lock.json (TestLockfileRoundTrip + TestRestoreEndToEnd)
- [x] AC3 End-to-end restore (TestRestoreEndToEnd with httptest)
- [x] AC4 Parity paths (VendorPath, TmpTarballPath match OCaml conventions)
- [x] AC5 Tests: lookup hit/miss, lockfile round-trip, SHA-256 mismatch, manifest validation
- [x] AC6 CI: .github/workflows/go.yml
- [x] `go test ./...` + `go vet ./...` pass locally
- [ ] CI green on draft PR
- [ ] Review (step 8, user per §1.4)
