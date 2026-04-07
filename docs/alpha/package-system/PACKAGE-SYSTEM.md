# Package Content Classes

## What the build system distributes via packages

**Version:** 1.0.0
**Status:** Draft
**Addresses:** #119 (template distribution), build-system content model
**Related:**
- docs/beta/architecture/PACKAGE-SYSTEM.md (system-level design)
- docs/alpha/cognitive-substrate/COGNITIVE-SUBSTRATE.md (asset taxonomy)
- docs/alpha/runtime-extensions/RUNTIME-EXTENSIONS.md (extension model)

---

## 0. Purpose

This document defines the set of content classes that `cn build` knows how
to assemble from `src/agent/` into distributable packages. It covers only
the build-system content pipeline -- not profiles, resolution, registry,
or other package-system layers (see docs/beta/architecture/PACKAGE-SYSTEM.md
for the full system design).
It answers:

1. What kinds of content can a package distribute?
2. How does each content class flow from source to installed package?
3. Why is the set explicit rather than generic?
4. What is the cost model for adding a new content class?

---

## 1. Content Classes

A package content class is a named category of assets that the build system
knows how to copy from `src/agent/<class>/` into `packages/<name>/<class>/`.

### 1.1 Content classes

| Class | Copy mode | Source location | Declared in manifest | Runtime role |
|-------|-----------|-----------------|---------------------|--------------|
| doctrine | wildcard or named | `src/agent/doctrine/` | `"doctrine": ["*"]` or `["FILE.md"]` | Always-on core principles |
| mindsets | named files | `src/agent/mindsets/` | `"mindsets": ["FILE.md", ...]` | Always-on behavioral frames |
| skills | directory trees | `src/agent/skills/` | `"skills": ["path/to/skill"]` | Keyword-scored, bounded |
| extensions | directory trees | `src/agent/extensions/` | `"extensions": ["ext.name"]` | Runtime capability providers |
| templates | named files | `src/agent/templates/` | `"templates": ["FILE.md"]` | Identity/config scaffolding for new hubs |
| commands | declared entries | `packages/<name>/commands/` | `"commands": { "<name>": { ... } }` | Operator-facing CLI commands |
| (metadata) | implicit | `packages/<name>/` | `cn.package.json` | Package identity, version, engine constraint |

Most content classes are copied from `src/agent/<class>/` by `cn build`.
The `commands` class is the exception: command files are authored
directly under `packages/<name>/commands/<file>` and ship with the
package tree. The manifest entry for a command is a JSON object
mapping the command name to `{ entrypoint, summary }`, where
`entrypoint` is a file path relative to the package root
(e.g. `commands/cn-daily`) and `summary` is a one-line description
shown by `cn help`.

Metadata (`cn.package.json`) is not a source-declared content class.
It is always present and not copied from `src/agent/`.

### 1.2 Copy modes

The build system uses two copy strategies:

- **Individual file copy**: Used by doctrine (when named), mindsets, and templates.
  Each declared entry is a single file name relative to `src/agent/<class>/`.
  The file is copied directly into `packages/<name>/<class>/<filename>`.

- **Directory tree copy**: Used by skills and extensions.
  Each declared entry is a directory path relative to `src/agent/<class>/`.
  The entire subtree is copied recursively.

Doctrine has a special case: `"*"` copies all `.md` files from the source
directory (wildcard mode).

---

## 2. Content Class Pipeline

Each content class flows through the same four-stage pipeline.
Angle-bracket segments are substitution variables, not literal paths.

```
src/agent/{class}/{entry}
    |
    | cn build         (copy from source to package output)
    v
packages/{name}/{class}/{entry}
    |
    | cn deps restore  (fetch + materialize into hub)
    v
.cn/vendor/packages/{name}@{version}/{class}/{entry}
    |
    | runtime read     (loaded at wake or on-demand)
    v
agent context / hub state
```

Concrete example for the templates content class:

```
src/agent/templates/SOUL.md
    |  cn build
    v
packages/cnos.core/templates/SOUL.md
    |  cn deps restore
    v
.cn/vendor/packages/cnos.core@3.24.0/templates/SOUL.md
    |  read_template
    v
spec/SOUL.md (in hub)
```

### 2.1 Build (cn build)

- Reads `cn.package.json` source declarations
- For each content class, copies declared entries from `src/agent/<class>/`
- Cleans stale content before copying

### 2.2 Check (cn build --check)

- Builds to a temp directory
- Diffs against existing `packages/<name>/<class>/`
- Reports any drift between source and package output

### 2.3 Clean (cn build clean)

- Removes all content class directories from `packages/<name>/`
- Preserves `cn.package.json`

### 2.4 Install (cn deps restore)

First-party packages are distributed as versioned tarball artifacts
published to GitHub releases. The restore flow is:

1. Read the lockfile (`.cn/deps.lock.json`) — name + version + sha256 per package
2. Look the name+version up in the package index (`packages/index.json`) for a URL
3. Download `<name>-<version>.tar.gz` over HTTPS
4. Verify the SHA-256 against the lockfile entry
5. Extract into `.cn/vendor/packages/<name>@<version>/`
6. Validate the extracted `cn.package.json`

The package index is the resolution authority (name+version → URL);
the lockfile is the integrity authority (name+version → sha256).
Hosting can move by republishing a new index without touching any
hub's lockfile.

When `cn deps restore` runs inside a cnos checkout, first-party
packages are copied directly from the local source tree after a
freshness check against `src/agent/`. This is the development path;
consumers always go through the index.

---

## 3. Manifest Schema

Content classes are declared in the `sources` object of `cn.package.json`:

```json
{
  "schema": "cn.package.v1",
  "name": "cnos.core",
  "version": "3.24.0",
  "kind": "package",
  "engines": { "cnos": "3.24.0" },
  "sources": {
    "doctrine": ["*"],
    "mindsets": ["ENGINEERING.md", "PM.md", "WISDOM.md"],
    "skills": ["agent/agent-ops", "cdd", "eng/coding"],
    "extensions": ["cnos.net.http"],
    "templates": ["SOUL.md", "USER.md"],
    "commands": {
      "daily": {
        "entrypoint": "commands/cn-daily",
        "summary": "Create or show the daily reflection thread"
      }
    }
  }
}
```

All content class keys are optional. A package may declare any subset.
Missing keys default to empty lists (or empty objects for `commands`).

---

## 4. Design Rationale

### 4.1 Why explicit classes, not a generic tree model

The content classes are explicit record fields in the build system:

```ocaml
type source_decl = {
  doctrine   : string list;
  mindsets   : string list;
  skills     : string list;
  extensions : string list;
  templates  : string list;
}
```

An alternative design would use a generic `(string * copy_mode) list`,
removing the per-class cost of adding new categories.

**Why explicit is preferred now:**

- **Readability**: Each class has a named field. Typos are compile errors.
- **Semantics**: Different classes have different copy modes (file vs tree vs wildcard). These are not interchangeable.
- **Debugging**: A mismatch in one class is easy to identify. A generic list requires parsing the class name from strings.
- **Cost**: Adding a new class requires touching ~5 locations (type, parser, build, check, clean). This is bounded and mechanical.
- **Current scale**: 6 classes. The explicit model is not yet a maintenance burden.

**When to reconsider:**

If a 7th or 8th content class creates enough pressure that the per-class
mechanical cost outweighs the readability benefit, refactoring to a generic
model is the right move. The signal is: "adding this class feels like
boilerplate, not design."

### 4.2 Why templates are a content class (not special-cased)

Before v3.24.0, SOUL.md and USER.md were hardcoded inline strings in
`cn_system.ml`. This violated the single-source-of-truth principle:
the canonical templates lived in `src/agent/` but were duplicated
(and divergent) in the setup code.

Templates could have been special-cased:
- Read directly from `src/agent/` at build time
- Embedded as OCaml string literals
- Treated as a build-system concern only

Instead, templates became a content class because:
- They follow the same source -> build -> install -> read path
- They benefit from the same drift detection (`cn build --check`)
- They can be overridden by future third-party packages
- No special cases in the build, install, or restore pipelines

### 4.3 Why the set is closed (for now)

The current 6 content classes cover all shipped cognitive assets plus
identity templates. The set is intentionally closed:

- New classes should be added only when an existing asset type cannot
  be served by any current class
- Each new class should follow the existing pattern (add field, add
  copy logic, add check/clean support)
- The design doc (this file) should be updated when the set changes

---

## 5. Tradeoffs

### Explicit classes vs generic model

| Dimension | Explicit (current) | Generic |
|-----------|--------------------|---------|
| Adding a class | ~5 code locations | 0 code, 1 config |
| Typo protection | Compile-time | Runtime/none |
| Copy mode per class | Type-safe branches | String dispatch |
| Readability | High (named fields) | Lower (dynamic) |
| Maintenance at N=6 | Low | Unnecessary |
| Maintenance at N=12 | Noticeable | Justified |

### Templates as content class vs special case

| Dimension | Content class (current) | Special case |
|-----------|------------------------|--------------|
| Drift detection | Automatic (cn build --check) | Must build separately |
| Install path | Same as all other content | Custom install logic |
| Third-party override | Possible | Not without custom code |
| Code complexity | Zero new abstractions | New special-case path |

---

## 6. History

| Version | Change |
|---------|--------|
| v3.4.0 | Package system introduced (doctrine, mindsets, skills) |
| v3.18.0 | Extensions added as 4th content class |
| v3.24.0 | Templates added as 5th declared content class (#119) |

---

## 7. Command Discovery

CLI commands resolved by `cn <name>` follow a fixed precedence order. The first match wins; later layers are not consulted.

1. **Built-in commands** — compiled into the `cn` binary (`cn status`, `cn doctor`, `cn deps`, ...). Authoritative.
2. **Repo-local commands** — executable files at `.cn/commands/cn-<name>` inside the current hub. Discovered at dispatch time. Used for hub-specific automation that should not be packaged.
3. **Vendored package commands** — declared under the `commands` content class of any installed package in `.cn/vendor/packages/<name>@<version>/`. Resolved by walking each installed package's `cn.package.json` and matching `commands.<name>`.

There is no PATH fallback. If two external commands at the **same precedence level** claim the same name, that is a `cn doctor` error (the package author or hub operator must rename). Built-ins always shadow external commands silently — built-ins are part of the system surface.

External commands are dispatched via `exec`: argv (minus `cn`) is passed through, the working directory is the hub root, and a small set of environment variables (`CN_HUB_PATH`, `CN_PACKAGE_ROOT` for package commands) is exported so the script can locate hub state without re-discovering it.

`cn help` lists all three layers with source and summary. `cn doctor` validates package command integrity: duplicate names within a layer, missing entrypoints, non-executable command files, and malformed metadata are all errors.

Runtime capability extensions (see `RUNTIME-EXTENSIONS.md`) are a **separate** system and unaffected by command discovery. Extensions provide typed capability providers for the agent runtime; commands are operator-facing CLI entry points. Both can ship in the same package without overlap.
