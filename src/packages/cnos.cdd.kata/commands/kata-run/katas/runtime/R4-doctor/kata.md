# R4 — Doctor Kata

**Class:** runtime
**Purpose:** Prove `cn doctor` catches broken package and command state.
**Requires:** cn >= 3.52.0

## Scenario

Install packages on a clean hub, verify doctor passes. Then break things (delete entrypoint, corrupt manifest) and verify doctor catches each failure.

## Inputs

- cnos repo for `cn build`
- clean temp hub

## Exact commands

```bash
cn build
cn init kata-hub && cd kata-hub
cn deps lock && cn deps restore
cn doctor                          # should pass
rm .cn/vendor/packages/cnos.core/commands/daily/cn-daily
cn doctor                          # should catch missing entrypoint
echo "NOT JSON" > .cn/vendor/packages/cnos.core/cn.package.json
cn doctor                          # should catch corrupted manifest
```

## Pass conditions

- doctor clean on fresh install
- doctor catches missing entrypoint
- doctor catches corrupted manifest
