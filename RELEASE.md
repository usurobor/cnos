# RELEASE.md

## Outcome

Coherence delta: C_Sigma A (`alpha A`, `beta A`, `gamma A`) · **Level:** L5

**cn status now surfaces truthful package and command state from manifests.** Installed packages display name, version, and content classes read from cn.package.json — not parsed from directory names. Command registry shows all registered commands grouped by tier (kernel / repo-local / package) with source attribution. Version drift compares engines.cnos from manifest against the running binary.

## Why it matters

Since #229 changed vendor paths from `name@version/` to `name/`, `cn status` was broken — it parsed directory names for version info that was no longer there. This cycle fixes the broken path and simultaneously upgrades the status display to show richer package metadata and the full command registry. This is MVA Step 4 (#228), the final step of the minimum viable agent sprint, and satisfies #192 AC4 (Go kernel rewrite: cn status surfaces installed packages and commands).

## Fixed

- **Broken vendor path parsing** (#233): `hubstatus.go` no longer parses `name@version` from directory names. Reads cn.package.json manifests from each vendor dir for name, version, engines.cnos, and content classes.
- **Version drift detection** (#233): now compares `engines.cnos` from manifest against running binary version, not directory name parsing.

## Added

- **Installed package content summary** (#233): each package displays content classes present (skills, commands, orchestrators, extensions, providers).
- **Command registry display** (#233): `cn status` lists all registered commands grouped by tier (kernel / repo-local / package) with source attribution.
- **pkg.ContentClasses()** (#233): pure method on FullPackageManifest that returns content classes in stable order.
- **pkg.EnginesJSON / SkillsJSON types** (#233): manifest schema types for engines and skills objects.

## Validation

- All 11 Go test packages pass (80+ tests).
- `go build ./...`, `go vet ./...` clean.
- 6 new tests in hubstatus: packages, content classes, version drift, no-packages, command registry, skip-junk-dirs.
- CI green on merge (5/5 checks: go, I1, I2, notify x2).

## Known Issues

- #230 — `cn deps restore` skips version upgrades silently
- #224 — Layout migration remaining ACs
- ContentClasses() detects 5 of 8 content classes (doctrine, mindsets, templates lack cn.package.json schema fields)
