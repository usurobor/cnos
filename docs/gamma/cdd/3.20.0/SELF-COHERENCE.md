## Self-Coherence — v3.20.0

### Changes reviewed

1. `src/cmd/cn_extension.ml` — Added `extension_path` to `extension_entry`, set during discovery. Added `resolve_command` that maps bare manifest commands to installed host paths.
2. `src/cmd/cn_executor.ml` — Switched from `entry.manifest.backend.command` to `Cn_extension.resolve_command entry`.
3. `src/cmd/cn_system.ml` — Doctor health check uses `resolve_command` instead of raw manifest command.
4. `test/cmd/cn_extension_test.ml` — 4 new tests: bare name resolution, absolute passthrough, empty command, e2e discovery→resolve→host.

### α (structural)

**B+** — The change is minimal and well-located. `resolve_command` is the single place where manifest command → executable path mapping happens. The function handles three cases (empty, absolute, relative) and each has a corresponding test. The `extension_path` field is set during discovery at the natural point where `ext_path` is already computed.

One minor concern: the convention that host binaries live in `host/` within the extension directory is implicit in `resolve_command` rather than derived from the manifest. This matches the current layout but isn't explicitly declared in the manifest schema. Acceptable for v1 — the design doc establishes this convention.

### β (relational)

**B+** — All three consumers of extension commands (executor dispatch, doctor health, tests) now go through `resolve_command`. The Runtime Contract doesn't need the resolved path — it reads manifest metadata, not execution details. No surface was missed.

The change aligns with the existing pattern in `cn_executor.ml` where `exec` ops resolve commands via PATH search (lines 679-694). Extension commands get analogous resolution but through the installed layout rather than PATH.

### γ (process)

**B** — The fix closes the concrete gap identified in SELECTION.md. Active skills (eng/ocaml, eng/testing) were applied. Tests cover the resolution logic and the e2e path through discovery → registry → resolve → host binary execution.

Cannot verify compilation or test execution (no OCaml toolchain in environment). This is a known limitation tracked in #117.
