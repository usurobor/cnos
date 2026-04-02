# v3.29.0 — Remove Hardcoded Paths

Issue: #146
Branch: claude/execute-issue-146-cdd-O6Rl3
Mode: MCA
Active skills: ocaml, coding, testing

## Snapshot Manifest

- README.md — this file
- SELF-COHERENCE.md — triadic self-check

## Deliverables

- Derive `bin_path` from runtime self-location with `$CN_BIN` override
- Derive `repo` from `cn.json` metadata with `$CN_REPO` override
- Remove all `/usr/local/bin/cn` literals from src/
- Remove hardcoded `"usurobor/cnos"` from cn_agent.ml
- Tests for resolution chain
