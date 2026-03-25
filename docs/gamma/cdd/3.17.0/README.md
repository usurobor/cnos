# v3.17.0 — Runtime Extensions Phase 1: Open Op Registry

**Issue:** #73 — Runtime Extensions — Capability Providers, Discovery, and Isolation
**Branch:** `claude/3.17.0-73-runtime-extensions-phase1`
**Mode:** MCA (new subsystem — extensible op dispatch)
**Prior version:** v3.16.2
**Consolidates:** #67 (network access — first reference extension)

---

## §0 Observation Inputs

### CHANGELOG TSC (v3.16.2 baseline)
α A / β A / γ B+. Weakest axis: γ (5+ review rounds, 53% mechanical ratio on v3.16.2).

### Encoding Lag
- #67 closed (consolidated into #73)
- #65 closed (descoped — hybrid architecture supersedes pure-cnos comms design)
- #73 selected from stale set via §3.4 re-evaluation
- 13 remaining open issues, 0 stale (freeze cleared)

### Doctor / Status
N/A (#59 partial impl).

### Last Assessment (v3.16.2)
- No specific next MCA committed
- Recommended: stale backlog triage → #73 or γ process improvement
- γ weakest axis (B+)

## §1 Selection

**Rule:** §3.4 (stale backlog re-evaluation). Three stale issues triaged:
- #73: real gap, clear fix path → **committed as next MCA**
- #67: consolidated into #73 (first reference extension)
- #65: descoped (hybrid architecture supersedes)

§3.4 freeze cleared by selecting from the stale set.

## §2.3 Gap

**What incoherence exists:**
The CN Shell op vocabulary is closed — hardcoded in `cn_shell.ml`. Adding a new capability (network access, browser, device IO) requires modifying core runtime code. Cognitive substrate is packageable and local; runtime capabilities are not equally extensible.

**Why it matters:**
Every new capability requires core changes. Capability growth is tied to core releases. The system cannot grow coherently. #67 (network access) has been blocked for 7 cycles because the extension architecture didn't exist.

**What fails if skipped:**
Agents remain network-blind. Future capabilities (API integrations, browser, device bridges) each require invasive core changes. The runtime grows by accretion rather than composition.

## §2.4 Mode

**MCA** — change the runtime. The op registry is closed in code; it must become open. This requires new types, dispatch logic, manifest parsing, discovery, and a reference extension to prove the model.

## Phase 1 Scope (from #73 design spec)

Phase 1 delivers the minimum viable extension architecture:

1. **Extension manifest schema** (`cn.extension.json`) — declares ops, backend, permissions, engines
2. **Op registry** — replaces closed built-in vocabulary with registry + dispatch
3. **Discovery** — scan installed packages at boot, build registry
4. **Subprocess host** — execute extension ops via subprocess
5. **First reference extension** — `cnos.net.http` providing `http_get` (observe op)
6. **Runtime Contract integration** — extensions visible in cognition + body layers

**Out of Phase 1 scope:** native backends, marketplace, migration of existing built-ins, doctor validation (Phase 2+).

## Frozen Artifacts

| Artifact | File | Status |
|----------|------|--------|
| Snapshot manifest | `README.md` (this file) | complete |
| Self-coherence report | `SELF-COHERENCE.md` | stub |

## Scope — Affected Files (preliminary)

| File | Change |
|------|--------|
| `src/cmd/cn_shell.ml` | Open op registry, dispatch by registry lookup |
| `src/cmd/cn_executor.ml` | Extension op dispatch to subprocess host |
| `src/cmd/cn_extension.ml` | New — manifest parsing, discovery, registry |
| `src/cmd/cn_ext_host.ml` | New — subprocess host protocol |
| `src/cmd/cn_runtime_contract.ml` | Extensions in cognition + body layers |
| `src/cmd/cn_capabilities.ml` | Extension ops in capability declarations |
| `src/agent/extensions/cnos.net.http/` | First reference extension source |
| `test/cmd/cn_extension_test.ml` | New — manifest, discovery, dispatch tests |
| `test/cmd/cn_shell_test.ml` | Open registry tests |
| `docs/alpha/runtime-extensions/RUNTIME-EXTENSIONS.md` | Status update |
