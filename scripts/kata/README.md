# scripts/kata/

**Deprecated.** The kata source of truth is now `src/packages/cnos.cdd.kata/`.

These scripts remain as a convenience wrapper. For the authoritative katas, use:

```bash
cn kata-list          # list available katas
cn kata-run R1-boot   # run one kata
cn kata-run --all     # run all katas
```

Or run directly from source:

```bash
bash src/packages/cnos.cdd.kata/commands/kata-run/katas/runtime/R1-boot/run.sh
```
