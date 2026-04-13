# scripts/kata/

Runtime katas — executable verification that the cnos package pipeline works.

These prove the system, not any specific package. For CDD method katas, see `src/packages/cnos.cdd.kata/`.

```bash
scripts/kata/run-all.sh       # run all runtime katas
scripts/kata/01-boot.sh       # run one
```

| # | Name | Proves | Requires |
|---|------|--------|----------|
| 01 | Boot | `cn init` → hub → `cn status` | cn ≥ 3.50.0 |
| 02 | Command | build → restore → `cn daily` dispatches | cn ≥ 3.52.0 |
| 03 | Round-trip | author → build → install → dispatch | cn ≥ 3.52.0 |
| 04 | Doctor | break state → `cn doctor` catches it | cn ≥ 3.52.0 |
