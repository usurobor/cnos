# scripts/kata/ — Tier 1 (bare binary)

Automated proof that the `cn` kernel binary works end-to-end before any
package is installed. Runs in CI as a merge gate (see
`.github/workflows/ci.yml` job `kata-tier1`).

```bash
scripts/kata/run-all.sh        # run all 6, stop on first failure
scripts/kata/01-binary.sh      # run one
```

| # | Name | Proves | Pass condition |
|---|------|--------|----------------|
| 01 | binary  | `cn` runs                              | `cn help` exits 0, output lists the 8 kernel commands |
| 02 | init    | `cn init` creates a hub                | `.cn/` skeleton exists with expected dirs, `cn status` exits 0 |
| 03 | status  | `cn status` reads hub state            | output contains hub identity and installed-packages section |
| 04 | doctor  | `cn doctor` validates clean hub        | exits 0 on a freshly-init'd hub with no warnings |
| 05 | build   | `cn build` produces dist/              | `dist/packages/` contains at least one `.tar.gz` + `index.json` |
| 06 | install | `cn deps restore` installs from dist   | at least one package appears under `.cn/vendor/packages/` with `cn.package.json` |

## Kata tiers

- **scripts/kata/** — Tier 1: bare binary only, ends at package install (this directory).
- **cnos.kata** package — Tier 2: runtime/package proof (command dispatch, roundtrip, doctor-broken, self-describe).
- **cnos.cdd.kata** package — Tier 3: method/CDD proof (design, review, post-release).

Post-package and method kata do **not** live here. See #237 and #238 for the tier 2/smoke split.
