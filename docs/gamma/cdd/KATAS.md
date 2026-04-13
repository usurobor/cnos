# Agent Kata

Executable verification scripts that prove the cnos package pipeline works end-to-end.

**Source of truth:** `scripts/kata/` (executable scripts)
**This file:** human-readable catalog (not authoritative — scripts are)

## Usage

```bash
# Run all katas
scripts/kata/run-all.sh

# Run one kata
scripts/kata/01-boot.sh
```

## Kata Catalog

| # | Name | Proves | Requires | Script |
|---|------|--------|----------|--------|
| 01 | Boot | `cn init` → hub exists, `cn status` runs | cn ≥ 3.50.0 | `scripts/kata/01-boot.sh` |
| 02 | Command | `cn build` → `cn deps restore` → `cn daily` dispatches | cn ≥ 3.52.0 | `scripts/kata/02-command.sh` |
| 03 | Round-trip | Author new command → build → install → dispatches | cn ≥ 3.52.0 | `scripts/kata/03-roundtrip.sh` |
| 04 | Doctor | Break packages → `cn doctor` catches it | cn ≥ 3.52.0 | `scripts/kata/04-doctor.sh` |

## Version gating

Each kata declares its minimum `cn` version. Katas that require features not yet in the installed binary are skipped (not failed). This keeps the suite truthful to current reality.

## Post-release usage

In each `POST-RELEASE-ASSESSMENT.md`, the Production Verification section should reference:
- Which kata(s) were run
- On what environment
- Pass/fail
- Deviations if any

Example:
```markdown
### Production Verification
**Katas run:** 01-boot, 02-command, 03-roundtrip, 04-doctor
**Environment:** cn 3.53.0, Linux x64
**Result:** 4/4 pass, 0 skip
```

## Adding a new kata

1. Add `scripts/kata/NN-name.sh`
2. Source `lib.sh` for helpers (`pass`, `fail`, `skip`, `require_version`, `setup_temp_hub`)
3. Use the standard structure: scenario comment at top, numbered steps, `kata_summary` at end
4. Update this catalog
5. `run-all.sh` picks it up automatically (globs `[0-9]*.sh`)
