## v3.20.0 — Runtime Extensions: end-to-end execution (#73)

**Issue:** #73 (remaining ACs — end-to-end validation)
**Branch:** claude/review-issue-73-7yr26
**Mode:** MCA
**Active skills:** eng/ocaml, eng/testing, eng/coding

### Gap

The extension architecture is type-complete and discovery-complete (Phase 1+2 shipped in v3.17.0–v3.18.0), but cnos.net.http has never executed end-to-end. The host binary exists but the dispatch pipeline cannot reach it: the executor passes the manifest's bare command name (`cnos-ext-http`) to `exec_args` without resolving it relative to the extension's installed path. The binary lives at `.cn/vendor/packages/<pkg>@<ver>/extensions/<ext>/host/cnos-ext-http`, not on PATH.

### Coherence contract

- **α target:** Extension host commands resolve correctly from installed layout — the dispatch pipeline works end-to-end
- **β target:** Discovery, registry, executor, and host protocol are connected — an extension op written by the agent reaches the subprocess host and returns a result
- **γ target:** The full extension pipeline is validated by tests that exercise the real host binary through the real dispatch path

### Acceptance criteria (this cycle)

| AC | Description | Evidence |
|----|-------------|----------|
| E2E-1 | Extension host command resolved from installed path | Executor resolves `["cnos-ext-http"]` → `{extension_path}/host/cnos-ext-http` |
| E2E-2 | End-to-end dispatch validated | Test: discovery → registry → executor → host → receipt |
| E2E-3 | cnos.net.http proves the model | `http_get` dispatched through full pipeline, host binary responds correctly |

### Deliverables

- `src/cmd/cn_extension.ml` — add `extension_path` to entry, add `resolve_command` helper
- `src/cmd/cn_executor.ml` — use resolved command path for extension ops
- `test/cmd/cn_extension_test.ml` — e2e dispatch test through real pipeline
- `docs/gamma/cdd/3.20.0/SELF-COHERENCE.md` — self-coherence report
