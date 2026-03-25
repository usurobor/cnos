# Implementation Plan — v3.18.0 Runtime Extensions Phase 2

## Scope

Close AC1 (build integration), AC5 (policy intersection), AC7 (host binary provable).

## Changes

### 1. Build integration (AC1)

**cn_build.ml**: Add `extensions` as a fourth source category.

- `source_decl` gains `extensions : string list`
- `parse_sources` reads `"extensions"` array from cn.package.json
- `build_one` copies `src/agent/extensions/<entry>/` → `packages/<pkg>/extensions/<entry>/`
- `check_one` includes extensions in diff comparison
- `clean_package_dir` removes `extensions/` alongside doctrine/mindsets/skills

**cn.package.json**: Add `"extensions": ["cnos.net.http"]` to the appropriate package manifest (likely a new `cnos.ext` package or added to `cnos.eng`).

### 2. Policy intersection (AC5)

**cn_extension.ml**: Add `effective_permissions` function.

```
effective_permissions : extension_manifest -> shell_config -> (string * Cn_json.t) list
```

Intersects extension-declared permissions with runtime config. The extension declares what it needs; the runtime config declares what's allowed. Effective = intersection.

**cn_executor.ml**: Pass effective permissions and limits to `Cn_ext_host.execute_extension_op`.

Currently the executor calls:
```ocaml
Cn_ext_host.execute_extension_op ~command ~op_kind:kind_name ~arguments ()
```

After: pass `~permissions` and `~limits` derived from policy intersection.

### 3. Host binary stub (AC7)

**src/agent/extensions/cnos.net.http/host/**: Create a minimal shell script `cnos-ext-http` that implements the host protocol (describe, health, execute) using curl for HTTP and basic JSON.

This proves the model is executable. The stub:
- Responds to `{"method":"describe"}` with extension metadata
- Responds to `{"method":"health"}` with `{"status":"ok"}`
- Responds to `{"method":"execute","op":{"kind":"http_get","url":"..."}}` by calling curl
- Is a shell script (not OCaml) — extensions are language-agnostic by design

### 4. Tests (invariant-first)

**Invariants:**
1. Build copies extensions: `cn build` produces identical extension tree in packages/
2. Policy intersection: extension cannot exceed runtime-granted permissions
3. Disabled extension never executes (negative space)
4. Host protocol: describe/health/execute round-trip through subprocess
5. Policy denial is traced: denied extension ops emit trace events with reason

## Active skills

- **eng/ocaml**: distinct field names, Result types, no partial functions, build-before-push
- **eng/testing**: invariant-first, negative space mandatory, match proof to claim
