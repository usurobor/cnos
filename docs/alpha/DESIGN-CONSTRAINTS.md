# cnos Design Constraints

**Version:** 1.0.0
**Status:** Active
**Doc-Class:** constitutive

This document defines the structural invariants of cnos. These constraints cannot be broken and must be validated each CDD cycle.

---

## 1. Kernel Constraints

### 1.1 The kernel is small and trusted

The kernel is the embedded bootstrap binary. It owns:

- package restore/install
- command registry + dispatch
- provider registry
- runtime contract
- doctor/status/help/update
- trust and precedence policy
- protocol semantics

The kernel does NOT own:

- every command implementation
- every provider implementation
- skill content
- doctrine content

**Invariant:** The kernel must remain small enough that one engineer can audit the entire binary in a single session.

### 1.2 The kernel is a package

`cnos.kernel` has an embedded `cn.package.v1`-compatible manifest. The platform is an instance of its own model. The kernel manifest uses the same schema and parser as normal packages.

**Invariant:** The kernel must parse its own manifest with the same code that parses any package manifest.

### 1.3 Kernel language is Go

The kernel is monolingual Go. No CGo, no embedded interpreters, no dynamic loading.

**Invariant:** `go build ./cmd/cn` must produce a single static binary with zero non-Go dependencies.

---

## 2. Package Constraints

### 2.1 One package substrate

There is exactly one package system. Every distributable unit — skills, commands, orchestrators, templates, doctrine, mindsets, extensions — is a package.

**Invariant:** No second distribution mechanism may exist alongside `cn.package.v1`.

### 2.2 The package is the unit of distribution

The implementation language inside a package is an implementation detail. The package boundary is the correct place for polyglot behavior.

**Invariant:** Package metadata is always language-neutral. The package system must never assume the language of a command binary, provider binary, or helper executable.

### 2.3 Independent package versioning

Each package has its own semantic version. The cnos binary has its own version. Compatibility is expressed via `engines.cnos` in `cn.package.json`.

**Invariant:** `package version ≠ cnos binary version`. No lockstep versioning between packages and the kernel.

### 2.4 Source → Artifact → Installed

```
src/packages/<name>/                    → authored source (single source of truth)
dist/packages/<name>-<version>.tar.gz   → distributable artifact
.cn/vendor/packages/<name>/             → installed active state
```

**Invariant:** `src/packages/` is the only authored source of truth. `dist/` is derived. `.cn/vendor/` is derived. Neither may be manually edited.

### 2.5 Content classes are fixed

The 7 content classes are: doctrine, mindsets, skills, extensions, templates, orchestrators, commands.

All 7 flow through the same pipeline: authored under `src/packages/<name>/<class>/`, built to `dist/packages/`, installed to `.cn/vendor/packages/<name>/<class>/`.

**Invariant:** Every content class uses the same source → build → install pipeline. No content class gets a special path.

---

## 3. Command Constraints

### 3.1 One command model

Every command, regardless of source, is normalized into one runtime descriptor model (`CommandSpec` + `Command` interface + `Invocation`).

**Invariant:** Source forms differ (kernel/repo-local/package). The runtime model is one.

### 3.2 Tier precedence

```
kernel > repo-local > package
```

**Invariant:** A kernel command always wins over a repo-local or package command with the same name.

### 3.3 Commands are not providers

Commands are exact-dispatch operator actions. Providers are executable capability surfaces invoked by the runtime. They may live in the same package but do not become the same runtime thing.

**Invariant:** The command registry and provider registry are separate. No command is automatically a provider. No provider is automatically a command.

---

## 4. Provider Constraints

### 4.1 One manifest type

Providers are declared via `cn.extension.v1` with a `capabilities` field. There is no separate provider manifest.

**Invariant:** `cn.extension.v1` is the single manifest schema for all extensions and providers.

### 4.2 Subprocess by default

The kernel launches providers as subprocesses and speaks a versioned protocol to them (`cn.ext.v1`). No reflection. No in-process plugin loading. No classloader model.

**Invariant:** stdout is machine-only protocol (NDJSON). Human/debug output goes to stderr. Providers must never emit unframed output on stdout.

### 4.3 Kernel decides

The provider may declare what it implements and what it needs. The kernel decides whether it is enabled, active, what permissions it gets, and whether it is invoked at all.

**Invariant:** Providers do not define policy. The kernel is the single policy decision point.

---

## 5. Purity Constraints

### 5.1 Parse vs Read boundary

Pure functions operate on bytes/data. IO functions operate on paths/network.

```
Parse*([]byte) → pure, no IO, no os imports
Read*(string)  → IO wrapper around Parse*
```

This mirrors the OCaml `src/lib/` (pure) vs `src/cmd/` (IO) discipline.

**Invariant:** `internal/pkg/` must have zero `os` imports. All IO enters through explicit IO wrapper functions.

### 5.2 cli/ owns dispatch, domain packages own logic

`cli/` contains: types, registry, thin command wrappers (≤30 lines of logic each).

Domain packages (`doctor/`, `pkgbuild/`, `restore/`, `hubinit/`, `hubstatus/`) contain the actual logic.

**Invariant:** No `cmd_*.go` file in `cli/` may exceed 30 lines of domain logic. If it does, the logic must be extracted to a domain package.

---

## 6. Hub Constraints

### 6.1 Hub structure is fixed

```
.cn/
  config.json (or config.yaml)
  deps.json
  deps.lock.json
  vendor/packages/
spec/
  SOUL.md
state/
  peers.md
  runtime-contract.json
agent/
threads/
```

**Invariant:** `cn doctor` must validate this structure. Any deviation is a reportable issue.

### 6.2 Hub is not source

`.cn/` is active runtime state. It is not part of the source tree. It only exists in a working hub.

**Invariant:** `.cn/` must never be committed to the source repository.

---

## 7. CDD Process Constraints

### 7.1 Two-agent minimum

Every code change requires at least two agents in the CDD cycle: one implements, one reviews.

**Invariant:** No PR may merge without a review from an agent other than the author.

### 7.2 Findings before merge

All review findings (A/B/C/D severity) must be resolved on-branch before merge. No "approved with follow-up."

**Invariant:** The only exception is design-scope deferral explicitly named by the reviewer, with the author filing an issue before merge.

### 7.3 Hub memory at cycle close

Every CDD cycle must produce a daily reflection and update relevant adhoc threads before the cycle closes.

**Invariant:** Post-release assessment §8 (Hub Memory) must reference committed hub artifacts.

---

## 8. Validation

These constraints must be validated each CDD cycle:

| # | Constraint | Validated by |
|---|-----------|-------------|
| 1.1 | Kernel is small | Post-release assessment: binary size, command count |
| 1.2 | Kernel is a package | `cn build --check` validates kernel manifest |
| 1.3 | Kernel is pure Go | CI: `go build` with no CGo |
| 2.1 | One package substrate | Review: no second distribution mechanism |
| 2.4 | Source → Artifact → Installed | `cn build --check` (I1 CI) |
| 2.5 | Content class pipeline | `cn build --check` (I1 CI) |
| 3.1 | One command model | Review: all commands implement `Command` interface |
| 3.2 | Tier precedence | Tests in `cli/` |
| 4.1 | One manifest type | Review: no `cn.provider.v1` |
| 4.3 | Kernel decides | Review: no policy in provider code |
| 5.1 | Parse vs Read boundary | CI: `go vet` + review of `internal/pkg/` imports |
| 5.2 | cli/ dispatch only | Review: no `cmd_*.go` exceeds 30 lines of logic |
| 6.1 | Hub structure | `cn doctor` |
| 7.1 | Two-agent minimum | PR review comments |
| 7.2 | Findings before merge | PR review trail |
| 7.3 | Hub memory at close | Post-release assessment §8 |

---

## 9. Amendment

This document may change only through explicit proposal and confirmation, with evidence justifying the change. Convenience does not justify weakening a constraint. Evidence of persistent friction may justify restructuring one.
