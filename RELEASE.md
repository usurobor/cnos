# RELEASE.md

## Outcome

Coherence delta: C_Sigma A (`alpha A`, `beta A`, `gamma A`) · **Level:** L6

**The kernel command chain now has a CI-enforced end-to-end proof, and `cn doctor` reports fresh-hub state truthfully.** Six Tier 1 kata scripts chain `cn help` → `cn init` → `cn status` → `cn doctor` → `cn build` → `cn deps restore` on every PR, and the kata-tier1 job gates merges on them all passing. Where doctor previously conflated "pending" with "failed" (fresh hubs exited non-zero before any lock or remote existed), it now renders three distinct states — `validated` (✓), `pending` (○), `broken` (✗) — and only broken gates the exit code.

## Why it matters

`scripts/kata/` used to mix pre-package and post-package kata in a flat suite whose headers claimed things the scripts didn't actually prove (e.g. `01-boot.sh` header mentioned `cn deps restore` but the script never ran it). None of them ran in CI. Regressions in the kernel command chain were caught manually or not at all — the `packages/index.json` migration leak was caught by accident, not by a named kata.

This cycle makes the bare-binary pipeline a structural invariant of the repo: the kernel command chain cannot silently break, because every PR must prove it end-to-end before merge. The three-tier kata model (Tier 1 bare binary here; Tier 2 runtime/package in `cnos.kata` #237; Tier 3 method/CDD in `cnos.cdd.kata`) gives future kata a clear home and keeps each tier focused on one failure class. The doctor three-way status is what made this possible without a script full of "expected warnings" exceptions — fresh-hub kata can now assert the absence of `✗` rather than tolerate a menagerie of pending-item noise.

## Added

- **Tier 1 bare-binary kata suite** (#236): six scripts at `scripts/kata/0{1..6}-*.sh` — binary, init, status, doctor, build, install. Each with a header comment stating exactly what it proves.
- **`run-all.sh` stop-on-first-failure** (#236): earliest failure surfaces first.
- **CI `kata-tier1` job** (#236): depends on `go`, runs the suite, gates merges.
- **Three-tier kata catalog** in `docs/gamma/cdd/KATAS.md` (#236).

## Changed

- **`cn help` always lists the 8 kernel commands** (#236): hub-requiring ones annotated with `(requires hub)` when no hub. Enables kata 01 to run before `cn init`.
- **`cn doctor` three-way Status** (#236): Pass/Info/Fail → ✓/○/✗, only Fail drives the exit code. Fresh-hub pending items (deps.lock.json, runtime contract, origin remote, vendor before any lock) are informational. deps.json after `cn setup` stays fatal when missing. Present-but-invalid artifacts still fail.

## Removed

- **`Registry.Available()`** — dead code after help always-list (#236).
- **`scripts/kata/01-boot.sh`, `02-command.sh`, `03-roundtrip.sh`** — post-package behavior moved to Tier 2 (#237). Old `04-doctor.sh` rewritten for clean-hub validation.

## Validation

- All 6 CI checks green on PR head (`go`, `kata-tier1`, Protocol contract schema sync I2, Package/source drift I1, 2× notify).
- `go test ./...`, `go vet ./...` clean; updated `registry_test.go` and `doctor_test.go` pass.
- `scripts/kata/run-all.sh` runs all 6 kata end-to-end on a freshly-built `cn` binary — first CI pass with the kata gate in place.
- γ review (§2.0 contract gate, §2.2.13 invariants, §2.2.14 architecture check): 0 D/C findings; §2.2.14.G improved — degraded paths now visible via `○` glyph.

## Known Issues

- #237 — Tier 2 runtime/package kata (`cnos.kata`) — not yet implemented.
- #238 — Release bootstrap / compatibility smoke — scope split from this cycle.
- Role configuration: γ+β collapse per CDD §1.4 (operator-authorized two-agent-minimum). Review posted as PR comment (#239) rather than native GitHub review state due to shared author identity (review/SKILL.md §7.1).
