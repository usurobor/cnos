# Agent Kata

Two kata families, two homes.

## Runtime katas (`scripts/kata/`)

Prove the cnos package pipeline works end-to-end. System-level — not package-specific.

| # | Name | Proves | Script |
|---|------|--------|--------|
| 01 | Boot | `cn init` → hub → `cn status` | `scripts/kata/01-boot.sh` |
| 02 | Command | build → restore → `cn daily` dispatches | `scripts/kata/02-command.sh` |
| 03 | Round-trip | author → build → install → dispatch | `scripts/kata/03-roundtrip.sh` |
| 04 | Doctor | break state → `cn doctor` catches it | `scripts/kata/04-doctor.sh` |

```bash
scripts/kata/run-all.sh
```

## Method katas (`src/packages/cnos.cdd.kata/`)

Prove CDD adds value over ad hoc execution. Package-distributed.

| ID | Name | Purpose |
|---|------|---------|
| M1 | Design | artifact completeness + traceability |
| M2 | Review | evidence-bound + architecture-aware |
| M3 | Post-release | closure quality + measurement |

```bash
cn kata-list
cn kata-run M1-design --mode cdd
cn kata-judge <run-dir>
```

## Post-release usage

Reference which katas were run, on what environment, pass/fail.
