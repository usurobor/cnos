# Runtime Contract v2 — Vertical Self-Model (Issue #62)

**Status:** Design
**Depends on:** #63 (contract authority — shipped v3.12.2)
**Enables:** #65 (communications design)

---

## 1. Problem

The Runtime Contract v1 (issue #56) solved the "agent must not probe for self-knowledge" problem with three flat blocks: self_model, workspace, capabilities. But it treats all filesystem paths uniformly — the agent can't distinguish:

- Its constitutive identity (SOUL.md, doctrine) from its working memory (reflections)
- Its private runtime internals (.cn/, state/) from legitimate work surfaces (src/, docs/)
- Communication channels (outbox, peers) from storage

The agent must infer these boundaries through probing, which is exactly what the contract was supposed to eliminate.

## 2. Design

Replace the flat three-block contract with a **four-layer vertical self-model**:

### 2.1 Identity — "Who am I?"

| Field | Source |
|-------|--------|
| `cn_version` | `Cn_lib.version` |
| `hub_name` | `Filename.basename hub_path` |
| `profile` | `assets.profile` or `"engineer"` |

### 2.2 Cognition — "What shapes my thinking?"

| Field | Source |
|-------|--------|
| `installed_packages` | Package inventory with doctrine/mindset/skill counts |
| `active_overrides` | Hub-local overrides by category |
| `activation_index` | Skills exposed with declarative triggers |
| `extensions_installed` | Extension manifest entries with lifecycle state |
| `memory` | Retention faculty (issue #100): `backend`, `entrypoint`, `surfaces`, `freshness`, `scope` |

#### Memory sub-shape (issue #100)

The `memory` record names how the agent treats persistence as a faculty rather than ad-hoc file probing. The runbook at `docs/alpha/agent-runtime/MEMORY.md` is the canonical `entrypoint` value.

| Field | Type | Meaning |
|-------|------|---------|
| `backend` | string | Storage backend literal. v1: `git+threads+state` (protocol + discipline over git-native surfaces; open-string so future retrieval backends can populate without contract change). |
| `entrypoint` | string | Hub-relative path to the canonical restore surface — the single file an agent reads at session start. Default: `.cn/vendor/packages/cnos.core/skills/agent/memory/SKILL.md` (post-B14a / #101 rename: `self/memory/SKILL.md`). |
| `surfaces` | string list | Hub-relative paths to canonical memory surfaces. v1 defaults: `threads/reflections/`, `threads/adhoc/`, `state/conversation.json`. |
| `freshness` | string | Most-recent thread mtime across canonical memory directories, rendered as "most-recent: N days ago" / "no memory activity". Doctor consumes the same mtime signal with a 30-day stale threshold. |
| `scope` | string | What memory is expected to preserve. v1 default: "decisions, learnings, reflections, working continuity". |

Producer: `Cn_runtime_contract.gather` calls `Cn_runtime_contract.memory_state` to derive `freshness` from filesystem mtime and emit the record. Defaults align with the doctor and `cn status` Go-side consumers so the OCaml emitter and Go renderer agree on shape.

### 2.3 Body — "What can my body do?"

| Field | Source |
|-------|--------|
| `capabilities` | observe/effect kinds, apply_mode, exec_enabled, budgets |
| `peers` | Known peer names for coordination ops |

Capabilities move under body — they describe the runtime's physical abilities, not the agent's identity or world.

### 2.4 Medium — "What world do I inhabit?"

Replaces the flat `workspace` block with **zone-classified paths**:

| Zone | Meaning | Paths |
|------|---------|-------|
| `constitutive_self` | Identity substrate — cannot be modified during normal operation; may be modified only in explicit configuration mode with operator confirmation or an explicitly recorded auto-apply policy (see CONFIGURE-AGENT.md) | `spec/SOUL.md`, `spec/USER.md`, installed doctrine, installed mindsets |
| `memory` | Temporal record — agent's reflections and conversation | `threads/reflections/`, `state/conversation.json` |
| `private_body` | Runtime internals — opaque to agent | `.cn/`, `state/` (except conversation.json), `logs/` |
| `work_medium` | Legitimate work surfaces | `src/`, `docs/`, `agent/` |
| `projection_surface` | Communication channels | `threads/outbox/`, peer sync surfaces |

## 3. Migration Mapping

| v1 | v2 |
|----|-----|
| `self_model.cn_version` | `identity.cn_version` |
| `self_model.hub_name` | `identity.hub_name` |
| `self_model.profile` | `identity.profile` |
| `self_model.installed_packages` | `cognition.installed_packages` |
| `self_model.active_overrides` | `cognition.active_overrides` |
| `workspace.directories` | `medium.zones` (classified) |
| `workspace.writable` | Derived from zone classification |
| `workspace.protected` | Derived from zone classification |
| `capabilities` | `body.capabilities` |
| `peers` | `body.peers` |

## 4. JSON Schema

```json
{
  "schema": "cn.runtime_contract.v2",
  "identity": {
    "cn_version": "3.13.0",
    "hub_name": "my-agent",
    "profile": "engineer"
  },
  "cognition": {
    "installed_packages": [...],
    "active_overrides": { "doctrine": [], "mindsets": [], "skills": [] },
    "activation_index": {
      "skills": [
        {
          "id": "cdd",
          "package": "cnos.core",
          "summary": "Coherence-Driven Development...",
          "triggers": ["review", "release", "design"]
        }
      ]
    },
    "memory": {
      "backend": "git+threads+state",
      "entrypoint": ".cn/vendor/packages/cnos.core/skills/agent/memory/SKILL.md",
      "surfaces": [
        "threads/reflections/",
        "threads/adhoc/",
        "state/conversation.json"
      ],
      "freshness": "most-recent: 2 days ago",
      "scope": "decisions, learnings, reflections, working continuity"
    }
  },
  "body": {
    "capabilities": {
      "observe": [...],
      "effect": [...],
      "apply_mode": "branch",
      "exec_enabled": false,
      "max_passes": 5,
      "budgets": { ... }
    },
    "peers": ["sigma"],
    "commands": [
      { "name": "daily", "source": "package", "package": "cnos.core", "summary": "Daily reflection" }
    ],
    "orchestrators": [
      { "name": "daily-review", "source": "package", "package": "cnos.core", "trigger_kinds": ["command", "schedule"] }
    ]
  },
  "medium": {
    "zones": [
      { "path": "spec/SOUL.md", "zone": "constitutive_self" },
      { "path": "threads/reflections/", "zone": "memory" },
      { "path": ".cn/", "zone": "private_body" },
      { "path": "src/", "zone": "work_medium" },
      { "path": "threads/outbox/", "zone": "projection_surface" }
    ]
  }
}
```

## 5. Markdown Rendering

```markdown
## Runtime Contract

**Authority:** [preserved from #63]

### Identity
cn_version: 3.13.0
hub_name: my-agent
profile: engineer

### Cognition
installed_packages:
  - cnos.core (6 doctrine, 2 mindsets, 0 skills)
  - cnos.eng (0 doctrine, 0 mindsets, 3 skills)
active_overrides: 0 (none)
memory:
  backend: git+threads+state
  entrypoint: .cn/vendor/packages/cnos.core/skills/agent/memory/SKILL.md
  surfaces: threads/reflections/, threads/adhoc/, state/conversation.json
  freshness: most-recent: 2 days ago
  scope: decisions, learnings, reflections, working continuity

### Body
[capabilities block — observe/effect/budgets]
peers: sigma

### Medium
constitutive_self: spec/SOUL.md, spec/USER.md
memory: threads/reflections/
private_body: .cn/, state/, logs/
work_medium: src/, docs/, agent/
projection_surface: threads/outbox/
```

## 6. Doctor Validation (v2)

**Structural checks (this issue):** `cn doctor` validates that `state/runtime-contract.json` contains the four top-level keys: `identity`, `cognition`, `body`, `medium`.

**Memory entrypoint check (issue #100 AC6):** `cn doctor` additionally validates the memory entrypoint via `checkMemoryEntrypoint`. Three states:

- `StatusFail` — entrypoint file missing (cnos.core not installed or memory skill missing).
- `StatusInfo` — entrypoint present but stale: most-recent thread mtime under canonical memory dirs is older than the v1 30-day threshold; or no memory activity yet (legitimate fresh hub).
- `StatusPass` — entrypoint present and fresh.

The 30-day threshold is hard-coded in v1; the literal is observable in the check value text (`stale (most-recent N days ago; threshold 30d)`). `cn status` projects the same `cognition.memory` block as a Memory section.

**Semantic consistency checks (deferred to #59):** deeper validation that the contract matches live hub state — e.g., profile matches installed packages, lockfile matches vendor, overrides resolve to real files, zone paths match actual directory layout. This is tracked as issue #59 (enhancement, not a #62 blocker).

## 7. Invariant (preserved)

After wake, the agent MUST be able to answer from packed context alone:
- Who am I? → identity
- What shapes my thinking? → cognition
- What can my body do? → body
- What world do I inhabit? → medium

## 8. Non-goals

- No changes to `Cn_capabilities.render` internals (just moved under body)
- No changes to sandbox enforcement (Cn_sandbox is the execution-time guard)
- No schema migration for existing `state/runtime-contract.json` files (overwritten on next wake)
