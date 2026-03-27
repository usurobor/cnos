## Self-Coherence — v3.20.0

### Changes reviewed

1. `src/cmd/cn_extension.ml` — Added `extension_path` to `extension_entry`, set during discovery. Added `host_subdir` named constant (links to RUNTIME-EXTENSIONS.md v1.0.6 §5). Added `resolve_command` returning `(string list, string) result` with existence and permission validation.
2. `src/cmd/cn_executor.ml` — `execute_extension_op` handles `resolve_command` Result: Error produces a traced receipt with `host_resolution_failed` reason code; Ok proceeds to dispatch.
3. `src/cmd/cn_system.ml` — Doctor health check handles `resolve_command` Error before attempting host health.
4. `test/cmd/cn_extension_test.ml` — 9 new tests: bare name resolution (with real binary), missing binary error, non-executable error, absolute passthrough, empty command error; e2e discovery→resolve→host positive path, e2e missing host, e2e non-executable host, e2e malformed JSON response.

### α (structural)

**A-** — `resolve_command` is the single resolution point. It returns `Result` (per eng/ocaml §3.3) with two distinct error cases: not-found and not-executable. The `host_subdir` constant is named and documented with a design-doc reference, so changing the layout convention requires updating one line. Three cases in the match (empty/absolute/relative) each have corresponding tests.

### β (relational)

**A-** — All three consumers (executor, doctor, tests) handle the Result. The executor traces resolution failures as `host_resolution_failed` — a package-system error, not an opaque subprocess error. The doctor catches resolution errors before attempting health checks, producing "host binary not found" instead of "health_process_exit_127".

### γ (process)

**B+** — Active skills (eng/ocaml, eng/testing, eng/coding) applied to both positive and negative paths:
- eng/ocaml: Result type for expected failures, named constant, Unix.access for permission check
- eng/testing: 5 negative-path tests (missing binary, bad permissions, malformed JSON, empty command, resolution-only e2e)
- eng/coding: convention derived from named constant with doc link, not inline string

Cannot verify compilation or test execution (no OCaml toolchain in environment). This is a known limitation tracked in #117.
