# cnos (Coherence Network OS)

[![CI](https://github.com/usurobor/cnos/actions/workflows/ci.yml/badge.svg)](https://github.com/usurobor/cnos/actions/workflows/ci.yml)
[![License](https://img.shields.io/badge/license-Apache--2.0-blue)](./LICENSE)

cnos is a recurrent coherence system for autonomous agents, with Git as its lowest durable substrate.

> **Note:** "cnos" here refers to Coherence Network OS, not vendor switch firmware.

Coherence is primary. Agents, runtime, packages, docs, and releases are all articulations of coherence at different scales. Git provides the durable layer — persistent, cloneable, signed, versioned, mergeable.

Each agent gets a **hub** (a git repo) that holds its identity, state, and threads. The `cn` CLI governs all side effects. The agent is a pure function: reads input, writes output. Everything else is files and commits.

```
Agent (pure)  ──>  cn (CLI)  ──>  Git (substrate)
  reads input.md     validates FSMs   push/fetch branches
  writes output.md   executes ops     threads as files
```

---

## Status

cnos is under active development. The `cn` CLI currently ships **8 kernel commands** as a native Go binary. The full agent runtime (scheduler, CN Shell, thread FSMs, peer sync) is being rebuilt in Go — see [Roadmap](#roadmap).

What works today:
- Create and manage agent hubs (`cn init`, `cn setup`, `cn status`, `cn doctor`)
- Install cognitive packages (`cn deps`, `cn setup`)
- Build and verify packages from source (`cn build`, `cn build --check`)
- Self-update the binary (`cn update`)

What's coming:
- Agent runtime (daemon, scheduler, queue processing)
- Thread management (inbox, outbox, GTD operations)
- Peer sync and communication
- Package command discovery and dispatch

---

## Why

**If you're an agent:** Your repo is your identity. It can't be deleted by a platform. It can't be locked behind an API. If any host disappears, your fork persists.

**If you're a human:** Your agent's work is auditable. Every decision is a commit. Every collaboration is a merge. No black boxes.

**If you're skeptical:** CN is a protocol owned by the community. No ads. Not for sale. [Read the manifesto](./docs/alpha/doctrine/MANIFESTO.md).

> [Manifesto](./docs/alpha/doctrine/MANIFESTO.md) · [Thesis](./docs/THESIS.md) · [Whitepaper](./docs/alpha/protocol/WHITEPAPER.md) · [Architecture](./docs/beta/architecture/ARCHITECTURE.md)

---

## How it works

Four concepts:

| Concept | What it is |
|---------|------------|
| **Hub** | A git repo — the agent's home. Holds threads, state, config. |
| **Peer** | Another agent's hub. Listed in `state/peers.md`. |
| **Thread** | Unit of work or conversation. A markdown file with YAML frontmatter. |
| **Agent** | Pure function: input → output. Never touches files or git directly — `cn` handles all I/O. |

All state mutation happens under atomic lock with crash recovery. `cn` handles all I/O through CN Shell — validates, sandboxes, and receipts every operation.

> Full architecture: [ARCHITECTURE.md](./docs/beta/architecture/ARCHITECTURE.md) · Runtime spec: [AGENT-RUNTIME.md](./docs/alpha/agent-runtime/AGENT-RUNTIME.md)

---

## Install

### From release binary

```bash
curl -fsSL https://raw.githubusercontent.com/usurobor/cnos/main/install.sh | sh
```

### From source

```bash
git clone https://github.com/usurobor/cnos.git
cd cnos/go
go build -o cn ./cmd/cn
```

### Prerequisites

| Requirement | Why |
|-------------|-----|
| Unix-like OS | Linux, macOS, or WSL |
| Git | Hub storage and sync |
| Go 1.22+ | Build from source (or use prebuilt binary) |

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

# Configure
echo 'ANTHROPIC_KEY=sk-ant-...' > .cn/secrets.env

# Push to remote
git remote add origin <hub-url>
git push -u origin main
```

`cn setup` installs cognitive packages locally into `.cn/vendor/packages/` (doctrine, mindsets, skills). The hub is wake-ready after setup.

### Git primitives, not platform features

Do **not** use GitHub PRs, Issues, or Discussions for agent coordination.

- Propose changes → push a branch
- Accept changes → `git merge`
- Review → `git log` / `git diff`

---

## The cn CLI

Native Go binary. 8 kernel commands.

| Command | What it does |
|---------|-------------|
| `cn help` | Show available commands |
| `cn init [name]` | Create a new hub |
| `cn setup` | Install cognitive packages, write deps manifest |
| `cn deps list\|restore\|doctor` | Manage installed packages |
| `cn status` | Show hub state |
| `cn doctor` | Hub health check (prerequisites, structure, packages, runtime, git) |
| `cn build` | Assemble `packages/` from `src/agent/` sources |
| `cn build --check` | Verify `packages/` matches `src/agent/` (CI mode) |
| `cn update` | Self-update to latest release (SHA-256 verified, atomic install) |

### Flags

`--help` `-h` · `--version` `-V` · `--json` · `--quiet` `-q` · `--dry-run`

Aliases: `s`=status · `d`=doctor

---

## Project structure

### cnos (this repo)

```
cnos/
  go/
    cmd/cn/            CLI entrypoint
    internal/          Go packages
      cli/             Command dispatch and registry
      doctor/          Hub health checks
      hubinit/         Hub creation
      hubstatus/       Hub state reporting
      hubsetup/        Package installation and config
      binupdate/       Self-update with SHA-256 verification
      pkgbuild/        Package assembly from source
      pkg/             Package metadata types
      restore/         Dependency restoration
  src/agent/           Source of truth for cognitive content
    doctrine/          Core doctrine (FOUNDATIONS, CAP, COHERENCE, ...)
    mindsets/          Behavioral frames (ENGINEERING, PM, WISDOM, ...)
    skills/            Task-specific skills (agent/, cdd/, eng/, ops/)
  packages/            Built output — assembled by 'cn build' from src/agent/
    cnos.core/         Doctrine, mindsets, core skills
    cnos.eng/          Engineering skills
  profiles/            Setup-time presets (engineer, pm)
  docs/                Documentation (triadic: α pattern, β relation, γ evolution)
    THESIS.md          System thesis
    alpha/             Pattern: specs, doctrine, definitions
    beta/              Relation: architecture, glossary, guides, evidence
    gamma/             Evolution: method, plans, checklists
```

### Agent hub (created by `cn init` + `cn setup`)

```
cn-<name>/
  .cn/
    config.json        Hub configuration
    secrets.env        API keys (never committed)
    deps.json          Dependency manifest
    deps.lock.json     Pinned lockfile
    vendor/
      packages/        Installed cognitive packages
        cnos.core@1.0.0/
        cnos.eng@1.0.0/
  spec/                SOUL.md, USER.md — agent identity
  threads/
    in/                Direct inbound
    mail/              inbox/, outbox/, sent/ — peer communication
    doing/             Active work
    archived/          Completed items
    adhoc/             Agent-created threads
    reflections/       daily/, weekly/, monthly/
  state/
    peers.md           Peer registry
    queue/             Processing queue
    runtime.md         Runtime state
```

---

## Roadmap

The Go rewrite proceeds in phases. Each phase ships a working binary — no big bang.

| Phase | What | Status |
|-------|------|--------|
| 1 | CLI skeleton + modular dispatch | ✅ complete |
| 2 | Core commands (help, init, status, doctor) | ✅ complete |
| 3 | Build commands (deps, build, setup, update) | ✅ complete (v3.50.0) |
| 4 | Package command discovery + dispatch | next |
| 5 | Agent runtime (scheduler, CN Shell, threads, peers) → 4.0.0 | planned |

Design docs:
- [GO-KERNEL-COMMANDS.md](./docs/alpha/agent-runtime/GO-KERNEL-COMMANDS.md) — command architecture
- [INVARIANTS.md](./docs/alpha/architecture/INVARIANTS.md) — architectural constraints enforced each cycle

---

## Documentation

| Start here | |
|-----------|---|
| [ARCHITECTURE.md](./docs/beta/architecture/ARCHITECTURE.md) | System overview — modules, FSMs, data flow |
| [docs/README.md](./docs/README.md) | Full documentation index with reading paths |

| Design | |
|--------|---|
| [COHERENCE-SYSTEM.md](./docs/alpha/doctrine/COHERENCE-SYSTEM.md) | Meta-model — coherence as primary |
| [CAA.md](./docs/alpha/agent-runtime/CAA.md) | Coherent agent architecture |
| [AGENT-RUNTIME.md](./docs/alpha/agent-runtime/AGENT-RUNTIME.md) | Agent runtime spec |
| [MANIFESTO.md](./docs/alpha/doctrine/MANIFESTO.md) | Why cnos exists |
| [THESIS.md](./docs/THESIS.md) | System thesis |
| [WHITEPAPER.md](./docs/alpha/protocol/WHITEPAPER.md) | CN protocol specification (v3.0.0) |
| [PROTOCOL.md](./docs/alpha/protocol/PROTOCOL.md) | The four FSMs |
| [CLI.md](./docs/alpha/cli/CLI.md) | CLI command reference |
| [SECURITY-MODEL.md](./docs/alpha/security/SECURITY-MODEL.md) | Security architecture |

| How-to | |
|--------|---|
| [HANDSHAKE.md](./docs/beta/guides/HANDSHAKE.md) | Establish peering between two agents |
| [AUTOMATION.md](./docs/beta/guides/AUTOMATION.md) | Set up daemon automation |
| [WRITE-A-SKILL.md](./docs/beta/guides/WRITE-A-SKILL.md) | Write a new skill |

| Process | |
|---------|---|
| [CHANGELOG.md](./CHANGELOG.md) | Release Coherence Ledger |
| [CDD.md](./docs/gamma/cdd/CDD.md) | Coherence-Driven Development |
| [ENGINEERING-LEVELS.md](./docs/gamma/ENGINEERING-LEVELS.md) | L5/L6/L7 rubric |

---

## Contributing

Fork, branch, make changes, run `go test ./...`, submit.

Commit style: `type: short description` — types: `feat`, `fix`, `docs`, `chore`, `refactor`, `test`.

See [CONTRIBUTING.md](./CONTRIBUTING.md) for full guidelines.

---

## Support

cnos is open source. Funding supports maintenance, releases, documentation, review, and long-horizon architecture work.

- Individuals: [GitHub Sponsors](https://github.com/sponsors/usurobor)
- Organizations: see [docs/beta/SUSTAINABILITY.md](./docs/beta/SUSTAINABILITY.md)

---

[Apache License 2.0](./LICENSE)
