# Workspace Constitution v1.0.0

**Status:** Draft
**Date:** 2026-03-12
**Authors:** usurobor (concept), Claude (design doc)
**Placement:** Design document (`docs/design/`)
**Runtime version:** AGENT-RUNTIME v3.9.0
**Audience:** Contributors, reviewers, runtime implementors, operators
**Scope:** Defines the workspace constitution — a runtime-generated, always-on context stratum that tells the agent what world it inhabits

---

## Coherence Contract

**Gap:** The agent currently lacks a first-class runtime model of its own workspace structure, forcing rediscovery and weakening determinism and security.

**Mode:** MCA — change the runtime architecture to provide workspace structure as an always-on stratum.

**Scope:** Architecture + runtime.

**Expected triadic effect:**
- α: the packed context strata become complete — the agent knows its identity, doctrine, *and* its workspace, not just the first two
- β: runtime behavior, packed context contract, traceability projections, and security model all align around an explicit workspace boundary
- γ: future workspace evolution (new roots, new package layouts, sandbox policy changes) can be expressed as schema changes to a versioned contract, not as ad hoc prompt rewrites

**Failure if skipped:** The agent wastes tokens rediscovering structure, behavior drifts when structure changes, and the agent is incentivized to explore rather than operate within a declared, bounded workspace.

---

## 1. Definition

The **Workspace Constitution** is a runtime-generated, always-on block in the packed context that declares the agent's workspace structure.

It tells the agent:
- what categories of space exist (identity, overrides, reflections, state, packages)
- which roots are writable vs protected
- which packages are installed
- where doctrine and skills come from
- what local overrides are active

The agent does not discover its workspace by exploration. The runtime tells it what its workspace is.

---

## 2. Why It Exists

Three problems motivate this stratum:

### 2.1 Cost
Without an explicit workspace model, the agent wastes tokens and ops rediscovering the shape of its own world. Every session that begins with "let me check the directory structure" is paying for information the runtime already has.

### 2.2 Drift
If workspace structure changes (new directories, moved packages, renamed roots), the agent's behavior becomes a prompt-accident rather than a runtime-contract consequence. Without a declared structure, there is no way to version or migrate the agent's spatial assumptions.

### 2.3 Security
An agent without a declared workspace boundary is incentivized to explore. Exploration is the opposite of governed operation. The Workspace Constitution establishes a bounded spatial contract — the agent operates *inside* declared space, not by inferring what might exist.

---

## 3. Relationship to Other Strata

The Workspace Constitution is a new stratum in the packed context, positioned between Task Skills and CN Shell Capabilities:

| # | Stratum | Source | Loaded |
|---|---------|--------|--------|
| 1 | Identity | `spec/SOUL.md`, `spec/USER.md` | Always |
| 2 | Core Doctrine | Installed `cnos.core` package | Always, not scored |
| 3 | Mindsets | All installed packages | Always, not scored |
| 4 | Reflections | `threads/reflections/` | Always (recent N) |
| 5 | Task Skills | All installed packages | Scored, bounded (top N) |
| **6** | **Workspace Constitution** | **Runtime-generated** | **Always** |
| 7 | CN Shell Capabilities | Runtime-generated | Always |
| 8 | Conversation | `state/conversation.json` | Recent N turns |
| 9 | Inbound message | Queue / stdin | Current demand |

### Why this position?

The ordering follows a principle: *first who you are, then what world you inhabit, then what tools exist in that world.*

- Strata 1–5 define the agent's identity, principles, personality, memory, and task knowledge
- Stratum 6 (Workspace Constitution) defines the world the agent inhabits
- Stratum 7 (Capabilities) defines what actions are possible in that world
- Strata 8–9 are the dynamic conversational context

### What it is NOT

- **Not capabilities.** Capabilities = what the runtime *can do*. Workspace Constitution = what the runtime world *looks like*. Both are needed. They are adjacent but distinct.
- **Not a replacement for any existing stratum.** This is additive.
- **Not a filesystem listing.** It declares *categories* and *policy*, not directory contents.

---

## 4. Schema

The runtime generates a block with schema version `cn.workspace.v1`:

```yaml
workspace:
  schema: "cn.workspace.v1"
  roots:
    identity: "spec/"
    overrides: "agent/"
    reflections: "threads/reflections/"
    state: "state/"
    packages: ".cn/vendor/packages/"
  writable:
    - "agent/**"
    - "threads/**"
  protected:
    - ".cn/**"
    - "state/receipts/**"
    - "state/artifacts/**"
    - "logs/**"
  packages:
    - "cnos.core@1.0.0"
    - "cnos.eng@1.0.0"
  doctrine:
    package: "cnos.core@1.0.0"
    files:
      - "doctrine/FOUNDATIONS.md"
      - "doctrine/COHERENCE.md"
      - "doctrine/CAP.md"
      - "doctrine/CA-CONDUCT.md"
      - "doctrine/CBP.md"
      - "doctrine/AGENT-OPS.md"
  local_overrides:
    enabled: true
    roots:
      - "agent/doctrine/"
      - "agent/mindsets/"
      - "agent/skills/"
```

### 4.1 Field definitions

| Field | Type | Description |
|-------|------|-------------|
| `schema` | string | Schema version identifier. Always `cn.workspace.v1` for this version. |
| `roots` | map | Logical root directories by category. Hub-relative paths. |
| `writable` | list | Glob patterns for directories the agent may propose writes to. |
| `protected` | list | Glob patterns for directories the agent MUST NOT modify. |
| `packages` | list | Installed packages with versions (from lockfile). |
| `doctrine` | object | Source package and file list for always-on doctrine. |
| `local_overrides` | object | Whether hub-local overrides are active and where they live. |

### 4.2 All paths are hub-relative

This is an explicit design choice. The Workspace Constitution uses hub-relative logical roots, not absolute host paths.

Rationale:
- Relative paths are what the runtime and sandbox reason over
- Absolute paths leak unnecessary host detail
- Relative roots are portable across environments
- The agent needs to know *categories of space*, not the host filesystem layout

The runtime MUST NOT include absolute paths like `/home/user/.config/cn/agents/pi` in the Workspace Constitution block.

---

## 5. Writable vs Protected vs Derived

The Workspace Constitution distinguishes three spatial categories:

### 5.1 Writable
Directories the agent may propose mutations to (via effect ops or coordination ops):
- `agent/**` — local overrides for doctrine, mindsets, skills
- `threads/**` — reflections, mail, conversations

### 5.2 Protected
Directories managed by the runtime or operator, not the agent:
- `.cn/**` — runtime configuration, vendor packages, lockfile, secrets
- `state/receipts/**` — execution receipts (runtime-written)
- `state/artifacts/**` — capability artifacts (runtime-written)
- `logs/**` — event logs, IO-pair archives (runtime-written)

### 5.3 Derived
State files that are projections, not source-of-truth:
- `state/ready.json` — boot readiness projection
- `state/runtime.json` — runtime state projection
- `state/coherence.json` — structural coherence projection

The agent reads derived state for awareness but does not write to it.

---

## 6. Relationship to CAR

The Workspace Constitution's `packages` and `doctrine` fields are derived from the CAR lockfile (`.cn/deps-lock.json`).

- `packages` lists what CAR has installed
- `doctrine.package` and `doctrine.files` identify which package provides always-on doctrine
- `local_overrides.roots` identify where hub-level overrides live (per CAR's two-layer resolution: hub override > installed package)

The Workspace Constitution does not replace or duplicate CAR. It *projects* the relevant subset of CAR state into the agent's packed context so the agent knows its cognitive supply chain without needing to read the lockfile.

---

## 7. Relationship to Traceability

The Workspace Constitution should be projectable for operators.

### 7.1 Event
- `workspace.rendered` — emitted after Workspace Constitution block is generated during context packing
  - carries: schema version, package count, override status, writable/protected root counts

### 7.2 Projection
- `state/workspace.json` — operator-facing snapshot of the current Workspace Constitution
  - written at boot alongside `state/ready.json` and `state/runtime.json`
  - allows operators to inspect the agent's declared workspace without reading the packed context

### 7.3 Schema

```json
{
  "schema": "cn.workspace.v1",
  "generated_at": "2026-03-12T10:00:00Z",
  "roots": {
    "identity": "spec/",
    "overrides": "agent/",
    "reflections": "threads/reflections/",
    "state": "state/",
    "packages": ".cn/vendor/packages/"
  },
  "writable": ["agent/**", "threads/**"],
  "protected": [".cn/**", "state/receipts/**", "state/artifacts/**", "logs/**"],
  "packages": ["cnos.core@1.0.0", "cnos.eng@1.0.0"],
  "doctrine_package": "cnos.core@1.0.0",
  "local_overrides_enabled": true
}
```

---

## 8. Invariants

1. **Always-on.** The Workspace Constitution is loaded every wake-up. It is never dropped for context budget. It is not optional.

2. **Runtime-generated.** The block is produced by the runtime from lockfile, config, and hub state. It is not hand-authored.

3. **Local-only.** No network fetch is needed. All information comes from local state (lockfile, config, directory presence).

4. **Deterministic.** Same lockfile + same config + same hub state → same Workspace Constitution block. No ordering surprises.

5. **Hub-relative paths only.** No absolute host paths leak into the agent context.

6. **No exploration needed.** The agent knows its workspace categories, boundaries, and sources without running any observe ops or filesystem commands. This is the core design intent.

7. **Schema-versioned.** The `schema` field enables future evolution without ambiguity.

---

## 9. Packed Context Rendering

The runtime renders the Workspace Constitution as a markdown block in the packed context, placed after skills and before capabilities:

```markdown
## Workspace

```yaml
workspace:
  schema: "cn.workspace.v1"
  roots:
    identity: "spec/"
    overrides: "agent/"
    reflections: "threads/reflections/"
    state: "state/"
    packages: ".cn/vendor/packages/"
  writable:
    - "agent/**"
    - "threads/**"
  protected:
    - ".cn/**"
    - "state/receipts/**"
    - "state/artifacts/**"
    - "logs/**"
  packages:
    - "cnos.core@1.0.0"
    - "cnos.eng@1.0.0"
  doctrine:
    package: "cnos.core@1.0.0"
  local_overrides:
    enabled: true
```​

### Token estimate

The Workspace Constitution block is compact — estimated at ~150–200 tokens. This is a fixed cost that eliminates variable exploration costs that would otherwise be much higher.

| Component | Tokens (est.) |
|-----------|---------------|
| Section header + schema line | ~10 |
| Roots (5 entries) | ~30 |
| Writable/protected (6 entries) | ~40 |
| Packages (2–5 entries) | ~20 |
| Doctrine + overrides | ~30 |
| YAML formatting overhead | ~20 |
| **Total** | **~150** |

---

## 10. Implementation Guidance

### 10.1 Runtime (`cn_context.ml`)

`Cn_context.pack` gains a new step between skill loading and capability rendering:

```
load_identity → load_doctrine → load_mindsets → load_reflections →
load_skills → render_workspace_constitution → render_capabilities →
load_conversation → append_inbound
```

The `render_workspace_constitution` function:
1. Reads `.cn/deps-lock.json` for installed packages
2. Reads `.cn/config.json` for override settings
3. Probes for `agent/` directory existence (override roots)
4. Renders the YAML block
5. Emits `workspace.rendered` event (per TRACEABILITY.md)

### 10.2 Boot sequence

The boot sequence (per TRACEABILITY.md §8) gains a new event:

```
boot.start → config.loaded → deps.lock.loaded → assets.validated →
doctrine.loaded → mindsets.loaded → skills.indexed →
workspace.rendered → capabilities.rendered → boot.ready
```

### 10.3 State projection

At boot, write `state/workspace.json` alongside existing projections.

---

## 11. Failure Modes

| Failure | Violated invariant | Symptom |
|---------|-------------------|---------|
| No workspace block at wake-up | #1 | Agent wastes tokens exploring structure |
| Hand-authored workspace block | #2 | Block drifts from actual state |
| Network fetch for workspace info | #3 | Flaky, non-deterministic starts |
| Different block from same state | #4 | Prompt cache misses, inconsistent behavior |
| Absolute paths in block | #5 | Host detail leaked to agent context |
| Agent explores despite block | #6 | Wasted ops, security boundary erosion |
| No schema version | #7 | Migration ambiguity |

Each failure maps to a specific invariant. If the invariant holds, the failure cannot occur.

---

## 12. Relationship to Other Documents

| Document | Scope | Relationship |
|----------|-------|-------------|
| CAA.md | Architecture / what | Workspace Constitution is a new stratum in the wake-up strata table |
| AGENT-RUNTIME.md | Runtime / how | Workspace Constitution is rendered during context packing |
| CAR.md | Distribution / how | Workspace Constitution projects CAR lockfile state into context |
| TRACEABILITY.md | Observability | Workspace Constitution has events and a state projection |
| SECURITY-MODEL.md | Security | Writable/protected boundaries formalize the sandbox contract |
| CDD.md | Development method | This change follows CDD process (coherence contract, design first) |

---

## 13. Migration

### From v3.6.0 to v3.9.0

- **Additive change.** No existing strata are modified or removed.
- **New stratum inserted.** Workspace Constitution appears between skills and capabilities.
- **Context budget impact.** ~150 tokens added to the stable prefix (cacheable).
- **New state file.** `state/workspace.json` added to projections.
- **New event.** `workspace.rendered` added to boot sequence.
- **No breaking changes to agent output format.** The agent gains awareness but the output contract (frontmatter ops + body) is unchanged.

### Schema evolution

Future workspace changes are expressed as schema version bumps (`cn.workspace.v2`, etc.). The runtime includes the schema version in the block, enabling agents to adapt to structural changes through the contract rather than through exploration.

---

## Summary

The Workspace Constitution closes a real gap in the agent's self-model: it knew its doctrine, mindsets, skills, and capabilities — but not its own workspace structure.

By making workspace structure a first-class, always-on, runtime-generated stratum:
- **cost** drops (no exploration tokens)
- **determinism** rises (same state → same block → same behavior)
- **security** improves (bounded, declared workspace instead of inferred space)

The right concept is: **the runtime tells the agent what world it inhabits, instead of making it rediscover it.**
