# SELF-COHERENCE

Issue: #146
Version: 3.29.0
Mode: MCA
Active Skills: ocaml, coding, testing

## Terms

- **bin_path**: Runtime-resolved path to the `cn` binary. Resolution chain: `$CN_BIN` env var > `/proc/self/exe` readlink > `Sys.executable_name`.
- **repo**: GitHub owner/repo identifier. Resolution chain: `$CN_REPO` env var > build-time extraction from `cn.json`.
- **cn_repo_info**: Dune-generated module that extracts `repo` from `cn.json` at build time.
- **cnos_repo**: Exposed via `Cn_lib.cnos_repo` as the single source of truth for downstream consumers (`cn_agent.ml`, `cn_deps.ml`).

## Pointer

- `src/cmd/cn_agent.ml:475-489` — `resolve_bin_path`, `resolve_repo`, module-level `bin_path`/`repo` bindings
- `src/lib/cn_lib.ml:726` — `cnos_repo` re-export from build-time module
- `src/lib/dune:18-21` — `cn_repo_info.ml` generation rule
- `src/cmd/cn_deps.ml:21` — `default_first_party_source` derived from `cnos_repo`
- `test/cmd/cn_selfpath_test.ml` — 7 ppx_expect tests covering resolution chains

## Exit

All five ACs verified:

- [x] AC1: No `/usr/local/bin/cn` literal in `src/**/*.ml`
- [x] AC2: Repository sourced from cn.json via `Cn_repo_info.repo`, not hardcoded
- [x] AC3: Self-update functional for any writable install prefix (`resolve_bin_path` uses runtime location)
- [x] AC4: `$CN_BIN` and `$CN_REPO` environment variable overrides available
- [x] AC5: `grep -r "usr/local/bin" src/**/*.ml` returns zero matches

## Acceptance Criteria Check

- [x] AC1: No `/usr/local/bin/cn` literal in src/ (.ml files)
- [x] AC2: Repository sourced from cn.json, not hardcoded
- [x] AC3: Self-update functional for any writable install prefix
- [x] AC4: `$CN_BIN` environment variable override available
- [x] AC5: `grep -r "usr/local/bin" src/` returns zero matches for .ml files

## Triadic Self-Check

- alpha: 4/4 — `resolve_bin_path` and `resolve_repo` are pure resolution chains with well-defined fallbacks. Build-time `cn_repo_info` extraction is deterministic. No type ambiguity.
- beta: 4/4 — All consumers (`do_update`, `re_exec`, `check_binary_version_drift`, `get_latest_release`, `default_first_party_source`) now use the resolved values. Test references updated. Skill docs retained as historical reference (not executable code).
- gamma: 4/4 — 7 tests cover override precedence, fallback behavior, format validation, and negative space (no hardcoded literal). Single-session implementation.
- Weakest axis: none — all axes clean
- Action: none

## Known Debt

- Skill reference docs (`src/agent/skills/eng/coding/SKILL.md`, `references/auto-update-case.md`) still mention `/usr/local/bin/cn` as illustrative examples. These are documentation, not executable code — updating them is a separate editorial concern, not a code debt.
