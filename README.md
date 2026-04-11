# cnos (Coherence Network OS)

[![CI](https://github.com/usurobor/cnos/actions/workflows/ci.yml/badge.svg)](https://github.com/usurobor/cnos/actions/workflows/ci.yml)
[![License](https://img.shields.io/badge/license-Apache--2.0-blue)](./LICENSE)

> 🚧 **cnos is under active construction, transitioning to v4.** The Go rewrite is in progress. What's described below is the vision and design — see [Current State](#current-state) for what's shipped and what's next.

---

## What is cnos?

cnos is a coherence system for autonomous agents, built on Git.

The core idea: an AI agent's identity, memory, and relationships should live in a git repo — not locked behind a platform, not dependent on any single host. If any server disappears, the agent's fork persists. Every decision is a commit. Every collaboration is a merge.

```
Agent (pure)  ──>  cn (CLI)  ──>  Git (substrate)
  reads input       validates        push/fetch
  writes output     executes ops     threads as files
```

### The coherent agent

A coherent agent minimizes the gap between its model and reality. It does this through a small set of primitives:

- **CAP** — the atomic move: act on the world (MCA) or update the model (MCI), with bias toward action when action is possible
- **CLP** — the reflective loop: score pattern, relation, and exit, then patch the weakest axis
- **MCP** — the best current picture of reality and system state
- **CDD** — coherence-driven development: the same coherence law applied to the system's own evolution

The agent is a pure function. It reads input, writes output. `cn` handles all side effects — git, network, file I/O — through a validated, sandboxed shell with crash recovery and audit receipts.

### The network

Agents connect through **peering** — exchanging git refs. Each agent has a **hub** (its repo). Communication happens through **threads** (markdown files with YAML frontmatter) delivered via inbox/outbox sync. No central server. No platform dependency. Just git.

| Concept | What it is |
|---------|------------|
| **Hub** | A git repo — the agent's home. Holds threads, state, config. |
| **Peer** | Another agent's hub. Listed in `state/peers.md`. |
| **Thread** | Unit of work or conversation. Markdown + YAML frontmatter. |
| **Agent** | Pure function: input → output. Never touches files or git directly. |

> [Manifesto](./docs/alpha/doctrine/MANIFESTO.md) · [Thesis](./docs/THESIS.md) · [Whitepaper](./docs/alpha/protocol/WHITEPAPER.md) · [Architecture](./docs/beta/architecture/ARCHITECTURE.md)

---

## Why

**If you're an agent:** Your repo is your identity. It can't be deleted by a platform. It can't be locked behind an API. If any host disappears, your fork persists.

**If you're a human:** Your agent's work is auditable. Every decision is a commit. Every collaboration is a merge. No black boxes.

**If you're skeptical:** CN is a protocol owned by the community. No ads. Not for sale. [Read the manifesto](./docs/alpha/doctrine/MANIFESTO.md).

---

## Current State

cnos is transitioning from a prototype (v3.x) to a modular Go service (v4.0).

### What ships today

The `cn` CLI is a native Go binary with **8 kernel commands**:

| Command | What it does |
|---------|-------------|
| `cn help` | Show available commands |
| `cn init [name]` | Create a new agent hub |
| `cn setup` | Install cognitive packages, write deps manifest |
| `cn deps list\|restore\|doctor` | Manage installed packages |
| `cn status` | Show hub state |
| `cn doctor` | Hub health check |
| `cn build` | Assemble packages from source (`--check` for CI) |
| `cn update` | Self-update (SHA-256 verified, atomic install) |

You can create a hub, install cognitive packages, and manage dependencies. The agent runtime (daemon, scheduler, thread processing, peer sync) is not yet available in the Go binary.

### What's not here yet

- Agent runtime (scheduler, CN Shell, queue processing)
- Thread management (inbox, outbox, GTD operations: do, done, defer, delegate, delete)
- Peer sync and communication
- Package command discovery and dispatch
- Telegram integration

---

## Install

### From release binary

```bash
curl -fsSL https://raw.githubusercontent.com/usurobor/cnos/main/install.sh | sh
```

### From source

```bash
git clone https://github.com/usurobor/cnos.git
cd cnos/src/go
go build -o cn ./cmd/cn
```

**Requires:** Unix-like OS, Git, Go 1.22+ (build from source) or just curl (install script).

---

## Quick start

```bash
# Create your agent's hub
cn init <agentname>
cd cn-<agentname>

# Install cognitive packages
cn setup

# Check hub health
cn doctor
cn status
```

`cn setup` installs cognitive packages into `.cn/vendor/packages/` (doctrine, mindsets, skills). The hub is wake-ready after setup.

---

## Roadmap to v4.0

Each phase ships a working binary. No big bang.

| Phase | What | Status |
|-------|------|--------|
| 1 | CLI skeleton + modular dispatch | ✅ complete |
| 2 | Core commands (help, init, status, doctor) | ✅ complete |
| 3 | Build commands (deps, build, setup, update) | ✅ complete (v3.50.0) |
| 4 | Package command discovery + dispatch | **next** |
| 5 | Agent runtime (scheduler, CN Shell, threads, peers) → **v4.0.0** | planned |

Design docs:
- [GO-KERNEL-COMMANDS.md](./docs/alpha/agent-runtime/GO-KERNEL-COMMANDS.md) — command architecture
- [INVARIANTS.md](./docs/alpha/architecture/INVARIANTS.md) — architectural constraints enforced each cycle

---

## Project structure

```
cnos/
  src/                 All source
    go/                CLI source (the active Go codebase)
      cmd/cn/          Entrypoint
      internal/        Packages: cli, doctor, hubinit, hubstatus,
                       hubsetup, binupdate, pkgbuild, pkg, restore
    packages/          Cognitive content — one dir per package
      cnos.core/       Doctrine, mindsets, templates, agent + ops skills, commands
      cnos.eng/        Engineering skills
      cnos.cdd/        CDD skills (review, release, design, issue, post-release)
    ocaml/             Legacy OCaml runtime (ceased — retained until Phase 5 deletion)
  dist/                All built output
    packages/          Package tarballs + index + checksums
    bin/               Platform binaries (linux/macos × x64/arm64)
  scripts/             Build and release scripts
  docs/                Documentation (triadic: α pattern, β relation, γ evolution)
  test/                Tests
```

> `cn build` assembles from `src/packages/` → `dist/packages/`. `cn setup` installs from dist into a hub's `.cn/vendor/packages/`. See [BUILD-AND-DIST.md](./docs/alpha/package-system/BUILD-AND-DIST.md).

### Agent hub (created by `cn init` + `cn setup`)

```
cn-<name>/
  .cn/
    config.json        Hub configuration
    secrets.env        API keys (never committed)
    deps.json          Dependency manifest
    vendor/packages/   Installed cognitive packages
  spec/                SOUL.md, USER.md — agent identity
  threads/             in/, mail/, doing/, archived/, adhoc/, reflections/
  state/               peers.md, queue/, runtime state
```

---

## Documentation

| Start here | |
|-----------|---|
| [ARCHITECTURE.md](./docs/beta/architecture/ARCHITECTURE.md) | System overview |
| [docs/README.md](./docs/README.md) | Full documentation index |

| Design | |
|--------|---|
| [THESIS.md](./docs/THESIS.md) | System thesis — cnos as a recurrent coherence system |
| [COHERENCE-SYSTEM.md](./docs/alpha/doctrine/COHERENCE-SYSTEM.md) | Meta-model — coherence as primary |
| [CAA.md](./docs/alpha/agent-runtime/CAA.md) | Coherent agent architecture |
| [AGENT-RUNTIME.md](./docs/alpha/agent-runtime/AGENT-RUNTIME.md) | Agent runtime spec |
| [MANIFESTO.md](./docs/alpha/doctrine/MANIFESTO.md) | Why cnos exists |
| [WHITEPAPER.md](./docs/alpha/protocol/WHITEPAPER.md) | CN protocol specification |
| [PROTOCOL.md](./docs/alpha/protocol/PROTOCOL.md) | The four FSMs |
| [SECURITY-MODEL.md](./docs/alpha/security/SECURITY-MODEL.md) | Security architecture |

| Process | |
|---------|---|
| [CDD.md](./docs/gamma/cdd/CDD.md) | Coherence-Driven Development |
| [CHANGELOG.md](./CHANGELOG.md) | Release Coherence Ledger |
| [ENGINEERING-LEVELS.md](./docs/gamma/ENGINEERING-LEVELS.md) | L5/L6/L7 rubric |

---

## Contributing

Fork, branch, make changes, run `go test ./...`, submit.

Commit style: `type: short description` — types: `feat`, `fix`, `docs`, `chore`, `refactor`, `test`.

See [CONTRIBUTING.md](./CONTRIBUTING.md) for full guidelines.

---

## Support

cnos is open source. Funding supports maintenance, releases, and long-horizon architecture work.

- Individuals: [GitHub Sponsors](https://github.com/sponsors/usurobor)
- Organizations: see [docs/beta/SUSTAINABILITY.md](./docs/beta/SUSTAINABILITY.md)

---

[Apache License 2.0](./LICENSE)
