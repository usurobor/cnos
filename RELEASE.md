# RELEASE.md

## Outcome

Coherence delta: C_Σ A (`α A`, `β A`, `γ A-`) · **Level:** L5

**Distribution pipeline proved end-to-end.** The `src/packages/ → cn build → dist/packages/ → cn deps restore → .cn/vendor/packages/` chain now works. Build and restore modules exchange real data for the first time. VendorPath aligned to BUILD-AND-DIST.md.

## Why it matters

The build and restore modules were written to the same spec (BUILD-AND-DIST.md) but had never exchanged real data. Three format mismatches existed between what `pkgbuild` produces and what `restore` expects. Until this cycle, the distribution pipeline was theoretical — now it's proven with automated round-trip tests.

## Fixed

- **VendorPath aligned to BUILD-AND-DIST.md** (#227): vendor path changed from `<name>@<version>` to `<name>/` — installed path no longer carries version. Version identity lives in the lockfile. Dead version parameter removed from `VendorPath` signature.
- **Lockfile types consolidated** (#227): inline `lockedDep`/`lockfile` structs in pkgbuild and restore replaced with canonical `pkg.Lockfile`/`pkg.LockedDep`. Single schema definition.
- **Non-deterministic lockfile output** (#227): `GenerateLockFromIndex` now sorts packages by name then version before marshaling. Deterministic output guaranteed.
- **Doctor drift detection updated** (#227): lockfile-based package presence check replaces `@version` parsing. Reports "no lockfile for drift check" when lockfile absent.

## Added

- **Local file restore** (#227): `fetchTarball` auto-detects local vs remote URLs. Relative paths in the index resolve against the index directory. Enables `cn build → cn deps restore` without a server.
- **`cn deps lock` subcommand** (#227): reads `dist/packages/index.json`, generates `.cn/deps.lock.json`. Decouples lockfile generation from the build step.
- **`TestBuildRestoreRoundTrip`** (#227): full pipeline test — build → index → lockfile → local restore → verify content + SHA-256. Primary round-trip proof.
- **4 additional tests** (#227): `TestRestoreLocalFile`, `TestGenerateLockfileData`, `TestGenerateLockfile`, `TestVendorPathVersionIgnored`.
- **Design and self-coherence docs** (#227): `DESIGN-227-distribution-pipeline.md`, `SELF-COHERENCE-227.md`.

## Validation

- All 9 Go test packages pass (66+ tests).
- `cn build` produces 3 tarballs + index + checksums in `dist/packages/`.
- `cn deps lock` generates lockfile from index.
- `cn deps restore` installs all 3 packages from local dist.
- Round-trip SHA-256 verified: tarball hash matches index entry.
- CI green (5/5: go, I1, I2, notify ×2).

## Known Issues

- #230 — `cn deps restore` skips version upgrades silently (version-less VendorPath, filed this cycle)
- #226 — Package command discovery + dispatch (MVA Step 3, next)
- #224 — Layout migration remaining ACs
- `scripts/check-version-consistency.sh` references stale `packages/` paths (pre-migration)
