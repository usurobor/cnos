## v3.22.0 — P0: daemon version-drift detection and auto-restart (#110)

**Issue:** #110
**Branch:** claude/review-issue-73-7yr26
**Mode:** MCA
**Active skills:** eng/ocaml, eng/testing, eng/coding

### Gap

The daemon has no way to detect that its binary was replaced by an external process. `re_exec` exists but only fires after the daemon's own `do_update` call. When an operator runs `cn update` from another terminal (or CI replaces the binary), the daemon continues with a stale binary indefinitely. Runtime Contract reports wrong version. Agent's self-model is wrong.

### Coherence contract

- **α target:** One version-drift check, one code path, clear detection → drain → re-exec → fallback chain
- **β target:** Maintenance loop, update check, re-exec, Runtime Contract, and trace events are aligned — drift detection feeds into existing restart infrastructure
- **γ target:** P0 resolved. Daemon self-knowledge matches binary on disk within one maintenance cycle

### Acceptance criteria

| AC | Description | Evidence |
|----|-------------|----------|
| AC1 | Daemon restarts after external binary replacement | Version-drift check detects mismatch, triggers re-exec |
| AC2 | Runtime Contract reports new version on next cycle | Re-exec'd process boots with new `Cn_lib.version` |
| AC3 | No message loss during restart | Drain current cycle before re-exec (same idle guard as update check) |
| AC4 | Re-exec failure → continue with warning | Catch Unix_error from execvp, log trace event, return Degraded |

### Deliverables

- `src/cmd/cn_maintenance.ml` — `version_drift_check_once` primitive
- `src/cmd/cn_agent.ml` — `check_binary_version` helper (runs `{bin_path} --version`, compares)
- `test/cmd/cn_maintenance_test.ml` or `cn_agent_test.ml` — drift detection tests
- `docs/gamma/cdd/3.22.0/SELF-COHERENCE.md` — self-coherence report
