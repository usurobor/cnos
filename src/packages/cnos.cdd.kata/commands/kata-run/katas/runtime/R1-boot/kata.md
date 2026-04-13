# R1 — Boot Kata

**Class:** runtime
**Purpose:** Prove a fresh hub can be initialized, packages restored, and runtime state surfaced correctly.

## Scenario

Start from an empty temporary directory. Create a fresh hub. Restore packages. Check that the runtime self-describes the installed state.

## Inputs

- empty temp directory
- reachable package index
- released package artifacts for cnos.core, cnos.cdd, cnos.eng

## Exact commands

```bash
cn init <hub-name>
cn deps restore
cn status
```

## Required artifacts

- command logs (stdout/stderr)
- resulting `.cn/vendor/packages/` tree
- `cn status` output

## Expected output

- hub initialized successfully
- packages restored successfully
- `cn status` shows installed packages
- no silent fallback

## Pass conditions

- all commands exit successfully
- expected packages appear in the vendor tree
- status output names the installed packages
