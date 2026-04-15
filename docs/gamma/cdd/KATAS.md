# Agent Kata

Kata are executable proofs. Scripts and packages are the source of truth;
this catalog is a secondary index.

## Tier model

| Tier | Home | What it proves |
|------|------|----------------|
| 1 — bare binary | `scripts/kata/` | `cn` binary works end-to-end before any package is installed |
| 2 — runtime/package | `src/packages/cnos.kata/` | post-package behavior: command dispatch, roundtrip, doctor-broken, self-describe |
| 3 — method/CDD | `src/packages/cnos.cdd.kata/` | CDD adds value over ad hoc execution: design, review, post-release |

Release-bootstrap and network-dependent compatibility checks belong in
`scripts/smoke/`, not here — they are production-facing, not kata.

## Tier 1 — bare binary (`scripts/kata/`)

CI gate: `.github/workflows/ci.yml` job `kata-tier1`. Failure = red build.

| # | Name | Proves | Script |
|---|------|--------|--------|
| 01 | binary  | `cn` runs                            | `scripts/kata/01-binary.sh` |
| 02 | init    | `cn init` creates a hub              | `scripts/kata/02-init.sh`   |
| 03 | status  | `cn status` reads hub state          | `scripts/kata/03-status.sh` |
| 04 | doctor  | `cn doctor` validates clean hub      | `scripts/kata/04-doctor.sh` |
| 05 | build   | `cn build` produces dist/            | `scripts/kata/05-build.sh`  |
| 06 | install | `cn deps restore` installs packages  | `scripts/kata/06-install.sh` |

```bash
scripts/kata/run-all.sh
```

## Tier 2 — runtime/package (`cnos.kata`)

Proves post-package behavior after at least one package is installed.
CI gate: `.github/workflows/ci.yml` job `kata-tier2` (`needs: kata-tier1`).
Failure = red build.

| ID | Name | Proves |
|----|------|--------|
| R1 | Command         | package command discovery + dispatch (`cn help`, `cn daily`) |
| R2 | Round-trip      | author → `cn build` → `cn deps restore` → dispatch in an isolated workdir |
| R3 | Doctor (broken) | `cn doctor` catches `chmod -x` on an installed command entrypoint |
| R4 | Self-describe   | `cn status` surfaces installed package name, version, and commands |

```bash
cn kata-runtime                # run R1..R4, stop on first failure
cn kata-runtime R2-roundtrip   # run one
```

The kata package must be installed (`cn deps restore`) before
`cn kata-runtime` can be dispatched — the dispatch itself is weak proof
that the runtime package loop works; R1-R4 make the proof explicit.

## Tier 3 — method/CDD (`cnos.cdd.kata`)

Proves CDD adds value over ad hoc execution. Package-distributed.

| ID | Name | Purpose |
|---|------|---------|
| M0 | Gap | frame the right incoherence before design |
| M1 | Design | artifact completeness + traceability |
| M2 | Review | evidence-bound + architecture-aware |
| M3 | Post-release | closure quality + measurement |
| M4 | Full cycle | end-to-end CDD loop vs ad hoc on the same change |

```bash
cn kata-list
cn kata-run M1-design --mode cdd
cn kata-judge <run-dir>
```

## Post-release usage

Reference which katas were run, on what environment, pass/fail.
