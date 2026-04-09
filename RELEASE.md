# RELEASE.md

## Outcome

Coherence delta: C_Σ A- (`α A`, `β A`, `γ B+`) · **Level:** `L6`

Commands join the standard package pipeline. All 7 content classes (doctrine, mindsets, skills, extensions, templates, orchestrators, commands) now flow through the same `src/agent/` → `cn build` → `packages/` → `cn deps restore` → vendor path. The last structural asymmetry in the package system is removed.

## Why it matters

Commands were the only content class authored directly under `packages/` instead of flowing through the build pipeline. This meant adding a new command required a core code change. Now commands are package assets — `daily`, `weekly`, and `save` are the first three to migrate out of built-in, proving the model works. The built-in command set begins its shrink toward the bootstrap kernel.

## Added

- **Commands as 7th content class in `cn build`** (#184): `source_decl.commands` added to the build pipeline. `cn build` copies, `cn build --check` verifies sync, `cn build clean` removes. `chmod +x` preserves executable bit on `cn-*` entrypoint scripts post-copy.
- **3 package commands** (#184): `daily`, `weekly`, `save` migrated from built-in OCaml to shell-script package commands in `cnos.core`. Each uses `CN_HUB_PATH` / `CN_PACKAGE_ROOT` / `CN_COMMAND_NAME` environment variables exported by `Cn_command.dispatch`.
- **Dual-field manifest design** (#184): `sources.commands` is a string array for the build pipeline (like `sources.skills`). Top-level `commands` is an object map with `entrypoint` + `summary` for runtime discovery/validation. Build reads one, runtime reads the other.
- **6 new build tests** (#184): build copies commands + preserves exec bit, clean removes commands, check detects drift.

## Changed

- **`cn_command.ml`** (#184): `parse_package_commands` and `validate` now read from top-level `commands` field instead of `sources.commands`. Discovery and validation logic simplified (one less nesting level).
- **`cn_lib.ml`** (#184): `Save`, `Daily`, `Weekly` removed from the command variant type and `parse_command`. These commands are now resolved through external command discovery when the built-in parser returns `None`.
- **`cn.ml`** (#184): Built-in dispatch arms for `daily`, `weekly`, `save` removed. The existing external command fallback path handles them.
- **`cn_gtd.ml`** (#184): `run_daily` and `run_weekly` removed — logic now lives in the shell entrypoint scripts.
- **`cn_hub.ml`** (#184): `threads_reflections_daily` and `threads_reflections_weekly` path helpers removed — owned by the shell scripts.
- **`PACKAGE-SYSTEM.md` §1.1** (#184): Updated to note commands flow through the standard pipeline.

## Removed

- **Built-in `daily`, `weekly`, `save` commands** — replaced by package commands in `cnos.core`. Same behavior, different dispatch path.

## Validation

- CI green on merge commit (30fa8de): OCaml build + tests + package/source drift + protocol traceability.
- Deployed to [target], validated with `cn --version` + `cn deps restore` + `cn daily` (discovered via package command path).

## Known Issues

- `cn help` shows a placeholder note for migrated commands instead of dynamically listing discovered package commands. Acceptable for v1.
- 3 review rounds (over ≤2 target) — test fixture used old manifest schema in two separate files; R1 fix only caught one. Post-release learning: grep all consumers before declaring a schema-change fix complete.
