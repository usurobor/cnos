# Go Kernel Command Architecture

## The kernel is a package

**Version:** 1.0.0
**Status:** Draft
**Addresses:** #192 (Go kernel rewrite), #209 (CLI dispatch)
**Related:**
- docs/alpha/package-system/PACKAGE-SYSTEM.md (package content classes)
- src/cmd/cn_command.ml (current OCaml command dispatch)
- src/lib/cn_lib.ml (current OCaml command variants)

---

## 0. Core Principle

**The platform is an instance of its own model, not a special case outside it.**

Every command in cnos — whether compiled into the binary or discovered from a vendor package — follows the same interface, the same manifest schema, and the same registration pattern. The kernel is a package (`cnos.kernel`) that happens to be embedded in the binary rather than installed via `deps restore`.

---

## 1. Why

### 1.1. The problem

The OCaml CLI has two command models:

- **Built-in commands**: hardcoded variant type in `cn_lib.ml`, match arm in `cn.ml`, implemented as OCaml function calls. No manifest, no entrypoint file.
- **Package commands**: declared in `cn.package.json` under `commands`, entrypoint is a shell script (`cn-<name>`), discovered at runtime from `.cn/vendor/packages/`, dispatched by execing the entrypoint.

This split means:
- Adding a built-in command touches the variant type, the parser, and the dispatch match — three files minimum
- Adding a package command touches one `cn.package.json` and one script — two files, self-contained
- `cn help` must special-case built-ins vs discovered commands
- Testing built-ins requires the full binary; testing package commands requires only the entrypoint
- The two models have different shapes, different lifecycles, different documentation

### 1.2. The direction already taken

v3.37.0 migrated `daily`, `weekly`, `save` from built-in to `cnos.core` package commands. The built-in set was explicitly shrinking toward a bootstrap kernel: `help`, `init`, `setup`, `deps`, `build`, `doctor`, `status`, `update`. The content-class model already treats commands as a package surface.

### 1.3. The logical endpoint

If commands are a content class, and the kernel is shrinking toward a minimal set, then the kernel's commands should follow the same content-class model. The kernel is a package.

---

## 2. Design

### 2.1. One command interface

```go
// Command is the interface every CLI command implements —
// kernel, repo-local, and package commands alike.
type Command interface {
    Name() string
    Summary() string
    Run(ctx context.Context, hubPath string, args []string) error
}
```

This is the only command abstraction. There is no `BuiltinCommand` vs `ExternalCommand` distinction in the type system. The caller sees `Command`; what `Run()` does internally is the command's business.

### 2.2. One registry

```go
type Registry struct {
    commands map[string]Command
    order    []string // insertion order for help
}

func (r *Registry) Register(cmd Command)
func (r *Registry) Lookup(name string) (Command, bool)
func (r *Registry) All() []Command
```

All commands — kernel, repo-local, package — register into the same registry. `cn help` iterates `All()`. Dispatch calls `Lookup()`. No special cases.

### 2.3. Three command sources, one model

| Source | Delivery | Run() implementation | Manifest |
|--------|----------|---------------------|----------|
| `cnos.kernel` | Compiled into binary | Go function call | Embedded `cn.package.json` |
| Repo-local | `.cn/commands/cn-<name>` | `os/exec` the entrypoint | None (convention-based) |
| Package-vendored | `.cn/vendor/packages/<pkg>/` | `os/exec` the entrypoint | `cn.package.json` `commands` object |

All three produce values that implement `Command`. The registry doesn't know which source a command came from.

### 2.4. The kernel package

`cnos.kernel` has a `cn.package.json` like any other package:

```json
{
  "name": "cnos.kernel",
  "version": "3.43.0",
  "description": "cnos bootstrap kernel — commands that exist before any packages are installed",
  "commands": {
    "deps":   { "summary": "Manage package dependencies" },
    "help":   { "summary": "Show available commands" },
    "doctor": { "summary": "Validate hub health" },
    "status": { "summary": "Show hub status" },
    "update": { "summary": "Update cnos binary" },
    "init":   { "summary": "Initialize a new hub" },
    "setup":  { "summary": "Configure cnos" },
    "build":  { "summary": "Build packages from source" }
  }
}
```

This manifest is embedded in the Go binary via `//go:embed`. The version is stamped at build time. The manifest is the source of truth for what kernel commands exist — not a hardcoded list in Go code.

### 2.5. Startup sequence

```
1. Load cnos.kernel manifest (embedded)
   → Register kernel commands (Go function implementations)

2. Discover hub (walk up from cwd to find .cn/)
   → If no hub: only kernel commands available (help, init, setup)

3. Discover repo-local commands (.cn/commands/cn-<name>)
   → Register as exec-backed Commands
   → Skip if name conflicts with kernel (kernel wins)

4. Discover vendor package commands (.cn/vendor/packages/*/cn.package.json)
   → Register as exec-backed Commands
   → Skip if name conflicts with kernel or repo-local

5. Dispatch: registry.Lookup(args[0]).Run(ctx, hub, args[1:])
```

### 2.6. Precedence

Flat 3-tier, not a tree:

1. **Kernel** (`cnos.kernel`) — always wins. These are bootstrap commands.
2. **Repo-local** (`.cn/commands/cn-<name>`) — operator overrides.
3. **Package-vendored** — installed package commands.

Same precedence as the current OCaml implementation (`cn_command.ml`). Conflicts at the same tier are doctor errors, not silent shadowing.

### 2.7. Bootstrap constraint

`cnos.kernel` must be self-sufficient before any packages are installed. This means:

- `deps restore` is a kernel command (it installs packages)
- `help` is a kernel command (it works without packages)
- `init` and `setup` are kernel commands (they create the hub)

Everything else *could* be a package command, but the current kernel set is small enough that embedding it all is simpler than splitting.

The test: if you delete `.cn/vendor/`, can you still `cn deps restore` to get it back? If yes, the kernel is correctly self-sufficient.

---

## 3. Prior art

### 3.1. OSGi (Java)

The framework itself is a bundle. Every module — including the platform — has the same manifest (`MANIFEST.MF`), same lifecycle, same service registry. `cnos.kernel` as a package follows this pattern exactly.

**What cnos takes:** the platform is an instance of its own model.
**What cnos avoids:** classloader trees, dynamic module resolution, runtime wiring complexity.

### 3.2. Java Platform Module System (JPMS)

`java.base` is structurally identical to application modules — same `module-info.java`, same exports/requires. It's just loaded first by the bootstrap classloader.

**What cnos takes:** the kernel module has the same shape as user modules.
**What cnos avoids:** the module graph resolution algorithm, split packages, reflection workarounds.

### 3.3. Maven

Maven's own plugins follow the same artifact/dependency model as what it builds. The build tool is composed of the same things it composes.

**What cnos takes:** the tool's internal structure mirrors its output structure.
**What cnos avoids:** plugin classloader isolation, artifact resolution at build time.

### 3.4. What all three share

The common principle: **the platform is an instance of its own model.** The divergence from Java's failure modes:

- **No classloader hell** — precedence is a flat 3-tier list, not a tree
- **No reflection magic** — commands are explicit registration, not annotation scanning
- **No runtime module resolution** — everything is known at startup
- **No dynamic loading** — the kernel is compiled in, packages are discovered at startup, nothing changes after dispatch begins

---

## 4. Repo structure

```
go/
  cmd/cn/
    main.go                 # entrypoint: hub discovery, registry setup, dispatch
    kernel.json             # cn.package.json for cnos.kernel (embedded via //go:embed)
  internal/
    cli/
      command.go            # Command interface
      registry.go           # Registry: Register, Lookup, All
      registry_test.go
      discover.go           # scan vendor + repo-local for commands
      discover_test.go
      exec_command.go       # exec-backed Command for package/repo-local commands
    kernel/
      kernel.go             # loads embedded manifest, registers kernel commands
      cmd_deps.go           # deps: restore, list, doctor
      cmd_help.go           # help: list all registered commands
      cmd_doctor.go         # doctor (Phase 3)
      cmd_status.go         # status (Phase 3)
      cmd_update.go         # update (Phase 3)
      cmd_init.go           # init (Phase 3)
      cmd_setup.go          # setup (Phase 3)
      cmd_build.go          # build (Phase 3)
    pkg/                    # unchanged — pure types
    restore/                # unchanged — restore logic
```

### 4.1. Adding a kernel command

One file + one manifest entry:

1. Create `internal/kernel/cmd_<name>.go` implementing `Command`
2. Add entry to `cmd/cn/kernel.json` under `commands`
3. The kernel loader reads the manifest and wires registration automatically

### 4.2. Adding a package command

One script + one manifest entry (unchanged from current model):

1. Create `src/agent/commands/<name>/cn-<name>` (shell script)
2. Add entry to package's `cn.package.json` under `sources.commands` and `commands`
3. `cn build` + `cn deps restore` makes it available

Same shape. Same number of touchpoints.

---

## 5. Phasing

| Phase | What | Commands |
|-------|------|----------|
| Phase 2 (#209) | CLI entrypoint + registry + kernel scaffold | `deps restore`, `help` |
| Phase 3 | Remaining kernel commands | `doctor`, `status`, `update`, `init`, `setup`, `build` |
| Phase 4 | Package command discovery | repo-local + vendor scanning |
| Phase 5 | Feature parity | all OCaml built-in behavior reimplemented in Go |

Phase 4 is when the "one model" promise is fully realized — kernel and package commands coexist in the same registry at runtime.

---

## 6. Open questions

1. **Should `cnos.kernel` appear in `packages/index.json`?** It's not installable via `deps restore`, but listing it would make the index a complete catalog of all cnos packages. Leaning no — the index is for installable packages.

2. **Should kernel commands be overridable?** Currently kernel always wins. An operator might want to replace `deps restore` with a custom version. Leaning no for now — kernel commands are bootstrap-critical. Repo-local can extend but not replace.

3. **Version stamping:** The kernel manifest version should match the binary version. Use `go:embed` for the manifest and stamp version at build time via `-ldflags` or a generated file. Same pattern as OCaml's dune-generated version module.
