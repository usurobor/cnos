# Gate — v3.35.0 (#167)

## Pre-gate (authoring-side)

- **CI status:** pending — not yet run on this branch
- **Required artifacts present:**
  - [x] Design doc (`docs/alpha/package-system/PACKAGE-ARTIFACTS.md`)
  - [x] Bootstrap README (`docs/gamma/cdd/3.35.0/README.md`)
  - [x] Plan (`docs/gamma/cdd/3.35.0/PLAN-package-artifacts.md`)
  - [x] Self-coherence (`docs/gamma/cdd/3.35.0/SELF-COHERENCE.md`)
  - [x] Code + tests committed per stage (9bebbd5, e2e49b0, bafba83)
- **Self-coherence present:** yes — α A−, β A, γ A−
- **Review converged:** no — PR not yet opened
- **Known debt explicit:** yes (PLAN §3, SELF-COHERENCE cycle-iteration
  table, and the three commit messages)
- **Release decision:** **hold** until:
  1. CI runs `dune build` + `dune runtest` on the branch
  2. PR review converges (α/β/γ patches as needed)
  3. Release workflow dry-run confirms `build-packages.sh` runs in CI
     matrix

## Gate checklist (at release time)

- [ ] CI green on the merge commit
- [ ] `dune build src/cli/cn.exe` succeeds on all 4 release targets
- [ ] `dune runtest` green (ppx_expect snapshots for `cn_deps_test`,
      `cn_runtime_contract_test`, `cn_selfpath_test` refreshed if
      needed)
- [ ] `scripts/check-version-consistency.sh` passes
- [ ] `scripts/build-packages.sh` succeeds in the release workflow
      (first real run — this is the moment the schema meets CI)
- [ ] `packages/index.json` committed back to main OR attached as a
      release asset with a documented fallback path (branch
      protection may block auto-commit; fallback is acceptable)
- [ ] PR review round 1 converged; no α/β findings outstanding
- [ ] Previous release (3.34.0) assessed — per CDD §3.5 a release
      without assessment is incomplete
- [ ] Known debt materialized as follow-up issues:
      - Migrate specific built-ins (daily/weekly/save/release) into
        `packages/cnos.core/commands/`
      - Package signing beyond SHA-256 (if required)
      - Index push-to-main under branch protection

## Deferred to post-release assessment

The §9.1 trigger "avoidable tooling failure" fires softly for this
cycle: the authoring sandbox had no OCaml toolchain, so `dune build`
ran only in CI rather than between stages. Post-release assessment
must decide whether this counts as L7 or should be retro-labeled L6
(cycle iteration section in POST-RELEASE-ASSESSMENT.md).

## Release decision

**hold — pending CI + PR review.**

Gate will flip to *proceed* once every unchecked item above is green
and the previous release assessment exists.
