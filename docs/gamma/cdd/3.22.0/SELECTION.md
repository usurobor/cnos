## CDD Selection — Post v3.21.0

**Date:** 2026-03-27
**Inputs read:** CHANGELOG TSC, encoding lag table, v3.20.0 post-release assessment

---

### 1. Observation

| Signal | Value |
|--------|-------|
| Baseline | v3.20.0 — α A-, β A-, γ B |
| This release | v3.21.0 — (release-only, no new assessment — bundles v3.20.0 work + CDD/emoji patches) |
| Weakest axis | γ (B) — process coherence |
| Mechanical ratio | 0% (v3.20.0 cycle) |
| Review rounds | 3 (v3.20.0 cycle, target ≤2) |
| MCI state | **Resumed** — freeze lifted in v3.20.0 assessment |
| Stale issues | 0 (freeze resolved) |
| Growing issues | 14 (#64, #110, #119, #117, #68, #84, #79, #94, #100, #96, #74, #101, #20, #43) |
| P0 bugs | 3 (#64 filesystem probing, #110 daemon restart, #119 setup stubs) |

### 2. Selection rules applied

| Priority | Rule | Result |
|----------|------|--------|
| 1 | P0 override | **Yes.** Three P0 bugs: #64 (v3.11.0), #110 (v3.16.2), #119 (recent). |
| 2 | Operational infrastructure | Skipped — P0 fires first. |
| 3 | Assessment commitment | None outstanding — v3.20.0 deferred selection. |
| 4 | MCI freeze check | N/A — freeze lifted. |

### 3. P0 triage

| Issue | Title | Severity | Age | Mitigation | Impact |
|-------|-------|----------|-----|------------|--------|
| #64 | Agent probes filesystem despite RC | P0 | v3.11.0 (old) | RC exists since v3.12.0; agent sometimes ignores it | Agent self-knowledge partially wrong |
| #110 | Daemon doesn't restart after self-update | P0 | v3.16.2 | Manual `systemctl restart` | **Stale binary in memory, wrong version in RC, package drift** |
| #119 | cn setup uses hardcoded stubs | P0 | recent | Setup works with stubs, just missing real templates | New hubs miss SOUL.md contract |

**#110 selected.** Rationale:
- Highest operational impact: stale binary means agent reports wrong version to itself and operator. Violates Runtime Contract I5 (self-knowledge membrane). Can cause package version drift.
- Clear fix path: version-drift check in maintenance loop. Infrastructure exists (`re_exec`, `maintain_once`, `update_check_once`). Bounded scope.
- #64 is older but mitigated (RC exists). #119 is lower severity (stubs work, templates are cosmetic).

### 4. Selected gap

**Next MCA:** #110 — P0: daemon does not restart after self-update

**Incoherence:** The daemon's update path has two gaps:
1. **External update blindness:** When an external process (`cn update` from another terminal, CI/CD) replaces the binary, the daemon has no way to detect the change. Its own `update_check_once` only triggers re-exec after its own `do_update` call.
2. **No version-drift detection:** The daemon never compares its compiled-in `Cn_lib.version` against the binary on disk. A stale process can run indefinitely after external binary replacement.

**What fails if skipped:** Operator updates binary → daemon continues with old version → Runtime Contract reports wrong version → agent's self-model is wrong → package operations may use stale version logic. Trust erosion: the system claims to know itself but doesn't.

### 5. Mode

**MCA** — fix the daemon version-drift detection and automatic re-exec after external binary replacement.

### 6. Acceptance criteria (from #110)

| AC | Description |
|----|-------------|
| AC1 | After `cn update` replaces the binary, the daemon restarts automatically |
| AC2 | Runtime Contract reports the new version on the next cycle after update |
| AC3 | No message loss during restart (drain current cycle, then restart) |
| AC4 | If restart fails, daemon continues on old binary with a logged warning |

### 7. Design

**Option 2 from #110:** Version-drift check in maintenance loop.

Implementation plan:
1. Add `version_drift_check` to `cn_maintenance.ml` — runs after `update_check_once`
2. Detect drift: run `{bin_path} --version` and compare against `Cn_lib.version`
3. On drift: log trace event, drain current work (same idle condition as update check), call `re_exec()`
4. On re-exec failure: log warning, continue on old binary (AC4)
5. Guard: same idle conditions as update check (no input.md, output.md, agent.lock)

**Why not hash-based:** Version string comparison is sufficient — if the binary changed, the version or commit hash changed. Hash comparison requires reading the entire binary on each maintenance tick. Version comparison requires one subprocess call.

### 8. Active skills

- eng/ocaml — Result types, safe subprocess calls, no partial functions
- eng/testing — positive and negative paths, e2e where possible
- eng/coding — minimal change, one new maintenance primitive

### 9. Deferred

- #64 (filesystem probing) — next P0 after #110
- #119 (setup stubs) — next P0 after #64
- #117 (pre-push gate) — process improvement, not P0
