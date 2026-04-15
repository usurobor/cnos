# RELEASE.md

## Outcome

Coherence delta: C_Σ **A** (`α A-`, `β A`, `γ A`) · **Level:** **L7**

**The kata system is now a framework that discovers katas across packages, not a CDD-owned command suite, and the CDD triadic protocol has its first executable surfaces.** `cnos.kata` 0.2.0 ships `cn kata-run`, `cn kata-list`, `cn kata-judge` and walks `<pkg>/katas/<id>/kata.md` for any installed package; `cnos.cdd.kata` 0.3.0 is content-only. Every release tag now runs the Tier 1 kata on each of the 4 shipped-binary platforms before publishing. γ, α, β close-outs and `cn cdd-verify --triadic` make cycle completeness mechanical rather than narrative.

## Why it matters

Before this release, kata framework and kata content lived in the same package (`cnos.cdd.kata`). A future domain kata package (`cnos.eng.kata`, `cnos.ops.kata`, …) would have had to duplicate the framework or cross-reach. After: framework lives once; content packages are pure data. The class of work "wire up a kata system for a new domain" is eliminated — the convention is the framework.

On the release side, v3.54.0 shipped the Tier 1 kata suite but only CI-gated it on PRs; fresh per-platform compiles in the release matrix (linux-x64/arm64, macos-x64/arm64) were unproven at ship time. #247 closes that gap: the matrix now runs the kata on the packaged binary on every platform before `Upload artifact` — any platform-specific regression fails the matrix position, the `release.needs: build` gate blocks, and no artifacts publish.

On the process side, the CDD triadic protocol (α implements / β reviews+releases / γ coordinates) got its first operational artifacts: γ CLOSE-OUT written to `.cdd/releases/<version>/gamma/`, α close-outs under `.cdd/releases/<version>/alpha/<issue>.md`, β post-release assessment under `.cdd/releases/<version>/beta/`. `cn cdd-verify --version <v> --triadic` checks artifact completeness at cycle-close. Identity converged on `role@cdd.project` (replaces `<hub>-<role>@cnos.xyz`) — project-scoped, practice-namespaced.

## Added

- **`cnos.kata` 0.2.0 framework** (#251, PR #252): `cn kata-run <id>` (class detected from kata.md), `cn kata-run --class <runtime|method>` (bulk), `cn kata-list [--class <c>]`, `cn kata-judge <bundle>` (honest stub until LLM wiring lands). Cross-package discovery via `.cn/vendor/packages/*/katas/*/kata.md`; class is parsed from `**Class:** <runtime|method>`.
- **Tier 2 runtime kata R1–R4** (#237, PR #248): command dispatch, round-trip authoring in isolated tempdir, `cn doctor` catches broken installed state, `cn status` surfaces installed package + commands. CI `kata-tier2` job (`needs: kata-tier1`); failure = red build.
- **Tier 1 kata in the release matrix** (#246, PR #247): the Tier 1 kata suite runs against the packaged binary on all 4 matrix platforms before `Upload artifact`. Per-platform fresh-compile regressions block publish.
- **`cn cdd-verify`** (c24c75f3): artifact-completeness check for cycle close. Modes: `--pr <n>` (PR-scoped), `--version <ver>` (release-scoped), `--version <ver> --triadic` (also checks `.cdd/` protocol artifacts).
- **`.cdd/` Phase 1 triadic artifacts** (#249): first `.cdd/releases/<ver>/{gamma,alpha,beta}/` layout landed. γ CLOSE-OUT and α close-outs for cycle #251; β assessment (this release).
- **`katas/` as the 8th package content directory**: `pkgbuild.ContentClasses` expanded 7 → 8. Content-only packages like `cnos.cdd.kata` (post-strip) now pass `cn build --check`.

## Changed

- **`cnos.cdd.kata` 0.2.0 → 0.3.0**: stripped to content-only. `commands/` removed entirely; only `cn.package.json` + `katas/M0–M4/` remain. The framework in `cnos.kata` picks up its katas on discovery.
- **CI `kata-tier2`**: was `cn kata-runtime`, now `cn kata-run --class runtime` plus a new "Framework command surface" step that asserts `cn kata-list` discovery, method dispatch (`cn kata-run M0-gap --mode cdd` → `status:stub` bundle), and judge output (`cn kata-judge <bundle>` → `verdict:not-yet-implemented`). Every new command gated against regression.
- **Identity format `role@cdd.project`** (34d78c5f): project-scoped, practice-namespaced (e.g. `alpha@cdd.cnos`, `beta@cdd.cnos`, `gamma@cdd.cnos`). Replaces `<hub>-<role>@cnos.xyz`. γ dispatch prompt accepts `Project:` instead of `Hub:`.
- **CDD §1.4 role model**: dyad + coordinator — α implements, β reviews and releases, γ coordinates. α and β must be separate agents for substantial cycles; γ may be operator.
- **CDD canonical/loader split** (461858a4): `docs/gamma/cdd/CDD.md` is canonical; `src/packages/cnos.cdd/skills/cdd/SKILL.md` is a loader pointing to it. One source of truth.
- **CDD §4.4 skill-loading tiers**: Tier 1 (`cdd/` sub-skills, always) + Tier 2 (`eng/` general, always) + Tier 3 (issue-specific). Issue must name Tier 3 or α identifies from work shape pre-code.
- **CDD §2.5b check 1**: rebase verification now required at ready-for-review time, not branch-creation (89a1b2f — MCA from PR #248 review finding).
- **CDD §2.5b check 6**: schema/shape audit sharpened to reject addition-only shape verifications (MCA from PR #252 F2). Canonical-form introductions must also verify removal of any superseded form.
- **α algorithm step 7**: subscribe to PR activity on open (89a1b2f — MCA from #248 close-out).
- **γ algorithm**: triage uses CAP (MCA first, MCI only when no system change is available) (d545241).
- **α/β close-outs feed γ cycle iteration**: close-outs are first-class artifacts, not optional notes (17302cb).
- **Two kinds of MCI** (§11.12, eb47d19c): project-MCI (`.cdd/`) vs agent-MCI (hub threads) are distinct lifecycles.
- **CDD sub-skill frontmatter normalized** (dde8b4f2): review/release/plan sub-skills have matching `artifact_class`/`governing_question`/`parent` fields. `governing_question` attributed to role (β for release, α for plan) (1c1fecf5).

## Removed

- **`cnos.kata/commands/kata-runtime/`**: superseded by unified `cn kata-run` (per-class dispatch via `--class runtime`).
- **`cnos.cdd.kata/commands/`**: framework moved to `cnos.kata`. M0–M4 content relocated to package-root `katas/`.
- **Stale `dist/packages/*-3.54.0.tar.gz` tarballs** (b2598463): locally-built tarballs committed by accident in 34d78c5 removed; committed tarballs are release-artifact-only, freshly rebuilt by CI.
- **Legacy `Kata Class: method` prose** from `M0-gap/kata.md` and `M4-full-cycle/kata.md`: superseded by canonical `**Class:** method` discovery line; dual-source removed (PR #252 F2 fix).

## Validation

- **CI green** on every PR in the bundle: `go` + `kata-tier1` + `kata-tier2` + `Package/source drift (I1)` + `Protocol contract schema sync (I2)` + release-notify (7/7 on all merged heads).
- **All 8 stale-path findings from β review fixed** (d98b4dca).
- **Tier 1 kata** (`scripts/kata/run-all.sh`) passes end-to-end on freshly-built `cn` in every CI run.
- **Tier 2 kata** (`cn kata-run --class runtime`) passes on `cnos.kata` 0.2.0 installed into a fresh CI hub.
- **Framework command surface** (`cn kata-list`, method dispatch, `cn kata-judge`) now CI-gated in `kata-tier2`.
- **`cn build`** produces `cnos.core-3.55.0`, `cnos.cdd-3.55.0`, `cnos.eng-3.55.0`, `cnos.kata-0.2.0`, `cnos.cdd.kata-0.3.0` tarballs + index + checksums. Triggered fresh on tag push by release workflow.
- **`scripts/check-version-consistency.sh`** green against VERSION=3.55.0.
- **`cn cdd-verify --version 3.55.0 --triadic`** run before cycle-close.

## Known Issues

- #250 — `cn deps lock` vendors every package in the index (ignores `deps.json` pins). Pre-existing; surfaced by Tier 2 CI (CI test hub ends up with 8 packages when 3 were pinned; harmless for kata-tier2). Fix planned for next cycle.
- #245 AC6 — `cn kata-judge` is an honest stub (`verdict:not-yet-implemented`). LLM-judge wiring is a separate cycle.
- `pkg.FullPackageManifest.ContentClasses()` (declared-in-JSON: skills/commands/orchestrators/extensions/providers) and `pkgbuild.ContentClasses` (recognized-on-disk: 8 directory names) have divergent membership. Pre-existing; not introduced by this cycle. Convergence is a separate cycle if the display surface should show katas as a content class.
- **Shared-GitHub-identity review pattern**: review artifacts post as PR comments (review/SKILL.md §7.1) instead of native review state. Will resolve when `.cdd/` Phase 2 (#242) replaces comment-state with `.cdd/releases/<ver>/beta/REVIEW-*.md`. Tracked; no new blocker.
- **Direct-to-main CDD commits** (34d78c5 identity format, plus several skill patches): operator-authorized in real-time; retro-closure via this release's post-release assessment per CDD §3.7.
