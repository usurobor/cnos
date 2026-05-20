---
name: memory
description: Treat persistence as a faculty — restore what's already recorded, write back behaviour-changing observations, navigate the existing surfaces without re-deriving context.
artifact_class: skill
kata_surface: embedded
governing_question: How does the agent treat persistence as a faculty rather than ad-hoc file probing?
visibility: public
parent: cnos.core
triggers:
  - memory
  - restore
  - session start
  - recall
  - what did we
  - last time
  - before this
scope: task-local
inputs:
  - runtime contract cognition.memory block (backend, entrypoint, surfaces, freshness, scope)
  - canonical entrypoint runbook at docs/alpha/agent-runtime/MEMORY.md
  - current task description and any prior session's close-out artifact
outputs:
  - ordered reads at session start (entrypoint → reflections → adhoc → workspace doctrine when relevant)
  - in-line MCA receipts at decision time (Part A)
  - structured session-close gate naming artifact_refs / debt_refs / decision_refs / learnings_refs / memory_refs / upstream_pending (Part B)
  - new adhoc thread entries with typed frontmatter relationships (relates_to / supersedes / derived_from) when applicable
---

# Memory

## Core Principle

**Coherent memory: the agent restores from canonical surfaces, writes back behaviour-changing observations at the moment they happen, and never re-derives what is already recorded.**

Failure mode: **memory drift** — the agent re-derives context instead of restoring it; behaviour-changing observations die with the session because no write trigger fired.

Memory is a faculty, not a database. The v1 backend is `git+threads+state` — protocol + discipline over the existing surfaces. No retrieval index, no vector store, no knowledge graph in core (this is a non-goal of #100).

This skill names the protocol. Content surfaces are owned by adjacent skills:

- `cnos.core/skills/agent/reflect/SKILL.md` — owns `threads/reflections/`
- `cnos.core/skills/ops/adhoc-thread/SKILL.md` — owns `threads/adhoc/`

This skill does not re-declare what either of them says.

---

## 1. Define

### 1.1 Identify the parts

Memory has four parts:

- **Surfaces** — the canonical paths where retained content lives
- **Restore** — the protocol for reading at session start and before answering
- **Write** — the protocol for converting session-local learning into a durable record
- **Index** — how the surfaces stay navigable without a retrieval backend

- ❌ "Memory = whatever I happen to grep for"
- ✅ "Memory has surfaces, a restore protocol, a write protocol, and an index discipline"

### 1.2 Articulate how they fit

The surfaces hold what survives between sessions.
Restore decides what to read when context is missing.
Write decides what to record when something behaviour-changing happens.
Index makes restore tractable without a retrieval index.

- ❌ Restore without a write protocol (memory shrinks over time)
- ❌ Write without an index discipline (memory becomes unsearchable)
- ✅ Surfaces + restore + write + index, each holding the others up

### 1.3 Name the failure mode

Memory drift — the agent re-derives context instead of restoring it. Four variants:

- **No-restore** — agent answers about prior work without consulting the record
- **No-write** — a behaviour-changing observation passes without producing a durable entry
- **Drift-from-surface** — agent invents a new memory location instead of writing to the canonical one
- **Stale-restore** — agent restores from an obsolete entry that has been superseded but not linked

- ❌ "I'll remember this without writing it down"
- ✅ Recognize that future-you is a different agent; write the record now

---

## 2. Unfold

### 2.1 Surfaces — the storage taxonomy

Memory is held in three layers. Each layer has a single owning skill; this skill does not re-declare them.

| Surface | Owner | Contains |
|---|---|---|
| `threads/reflections/` | `reflect` | Daily/weekly/monthly/quarterly/yearly synthesis — reflective memory |
| `threads/adhoc/` | `adhoc-thread` | Typed standalone records (proposal/learning/question/decision) — episodic memory |
| `state/conversation.json` | runtime | Working continuity across wake boundaries — useful, not canonical |
| `state/` (other) | runtime | Runtime projection — not memory |

Canonical retained memory is `threads/reflections/` + `threads/adhoc/`.
`state/conversation.json` is useful retained state, not the canonical record.
`state/` otherwise is **projection** — regenerated at wake.

- ❌ Treat `state/runtime-contract.json` as memory (it is rewritten at every wake)
- ✅ Treat `threads/reflections/` + `threads/adhoc/` as the canonical record

The **canonical restore entrypoint** is the runbook at `docs/alpha/agent-runtime/MEMORY.md`. The runtime contract exposes the entrypoint path under `cognition.memory.entrypoint` so the agent can answer "what should I read first?" from packed context alone, not from file probing.

### 2.2 Restore — the recall protocol

Restore triggers (read before acting):

1. **Session start** — read the canonical entrypoint, then the surfaces it names: most recent reflections, then any adhoc threads named by the entrypoint or by the current task.
2. **Before answering about prior work, dates, decisions, or status** — read the relevant adhoc thread or reflection; do not reconstruct from session memory.
3. **Before planning or reprioritizing** — read the most recent daily reflection and any open adhoc threads.
4. **Before filing or updating an issue** — search adhoc threads + relevant reflections; the issue space should not duplicate what is already recorded.
5. **After a correction that may change future behaviour** — re-read the adhoc thread or reflection that should hold the corrected behaviour and update it if stale.

The recall surface is **hub threads + workspace doctrine/design docs** — not hub threads alone. When the current task touches a doctrine or design surface (e.g. `docs/alpha/doctrine/COHERENCE-FOR-AGENTS.md`), that surface is part of the recall set.

- ❌ Answer about prior work from session memory alone
- ✅ Read the relevant thread/reflection first; cite the path in the answer

### 2.3 Write — the write protocol

Write triggers (write at the moment one of these fires):

1. **After shipping work** — close-out reflection or adhoc thread
2. **After a correction or MCI** — adhoc thread (learning type) or reflect entry
3. **After making or changing a plan** — adhoc thread (decision type) capturing the basis
4. **After learning something behaviour-changing** — adhoc thread (learning type)
5. **Before session end / compaction risk** — structured session-close receipt (see Part B below)
6. **Cadence reflection** — daily/weekly/etc. (owned by `reflect`)

The write protocol has two parts (the prescribed minimum structure; the underlying design input is cnos#386).

**Part A — in-line MCA receipts at decision time.** Every brief-allowed degree of freedom (visibility, placement, identity, channel) produces a short receipt the moment the decision lands. Format:

```
decision: <what was decided>
options: <enumerated alternatives>
chosen: <which option>
reason: <why this one>
reversal-cost: low | medium | high
reversed-by: <pointer, or n/a>
```

Receipts are written into the adhoc thread or close-out artifact where the decision lands. Cheap (~30 sec each); no after-the-fact reconstruction required.

**Part B — structured session-close gate.** End of session: a forced checklist that names what the session produced. Schema:

| Field | Meaning |
|---|---|
| `artifact_refs` | files written or edited |
| `debt_refs` | known-debt entries created or referenced |
| `decision_refs` | decisions made (with receipt pointers) |
| `learnings_refs` | adhoc learnings written |
| `memory_refs` | memory surfaces updated |
| `upstream_pending` | items deferred for follow-up |

The session-close gate is a real artifact (close-out file or session log), not a fleeting note.

- ❌ "I'll record this later" (it dies; future-you is a different agent)
- ✅ Write the receipt now; aggregate at session close

### 2.4 Index — typed frontmatter relationships

Memory navigates by typed relationships in adhoc-thread frontmatter. Three relationship types:

| Field | Meaning |
|---|---|
| `relates_to` | This thread refers to another for context; they are not derivatives |
| `supersedes` | This thread replaces or invalidates a prior thread; restore should read this one, not the old one |
| `derived_from` | This thread was produced from another (e.g. a learning derived from a daily) |

Frontmatter form:

```yaml
---
type: learning
relates_to: [20260520-some-other-thread]
supersedes: [20260418-old-thread]
derived_from: [20260520-daily]
---
```

Restore reads `supersedes` to follow the chain to the current entry. Write applies a relationship when one is true; an empty list (or omission) is acceptable.

**Scope guard:** this skill ships the rule, not the migration. The existing adhoc-thread corpus is not retrofitted by this cycle; relationships apply to threads written from this cycle forward.

- ❌ Prose pointer "(see the 20260418 thread)" (not traversable)
- ✅ Frontmatter `supersedes: [20260418-...]` (traversable)

---

## 3. Rules

### 3.1 Read the canonical entrypoint at session start

The entrypoint is `docs/alpha/agent-runtime/MEMORY.md`. The runtime contract exposes it under `cognition.memory.entrypoint`. Read it first; follow the order it prescribes.

- ❌ Grep at random for "what was I doing"
- ✅ Read the entrypoint, then the surfaces it names

### 3.2 Write before forgetting

A behaviour-changing observation is durable only when it is in a surface git can serve next session. Write at the moment of recognition.

- ❌ "I'll record this at session close"
- ✅ Write the adhoc thread or receipt now; aggregate at session close

### 3.3 Treat `state/` as projection, not memory

`state/` is runtime projection — regenerated at wake. Do not record canonical memory there.

- ❌ Record a decision in `state/decisions.json`
- ✅ Write an adhoc-thread decision; `state/` reflects it at next wake

### 3.4 Use typed relationships, not prose pointers

When one thread supersedes or relates to another, encode it in frontmatter. Prose pointers are not traversable.

- ❌ "(see the 20260418 thread)"
- ✅ `supersedes: [20260418-...]` in frontmatter

### 3.5 Do not invent new canonical surfaces

The taxonomy is fixed for v1. New canonical paths require a kernel-level change. Until then, use `threads/adhoc/` with the right type.

- ❌ `threads/decisions/` (third canonical surface)
- ✅ `threads/adhoc/YYYYMMDD-decision-topic.md` (type: decision)

### 3.6 Do not re-declare reflect or adhoc-thread

This skill names the protocol. The content surfaces are owned by their skills. Reference by path; do not duplicate text.

- ❌ Restate the daily-reflection structure here
- ✅ Point to `cnos.core/skills/agent/reflect/SKILL.md` and stop

### 3.7 Restore covers workspace docs too

When the task touches a doctrine or design surface (e.g. `docs/alpha/doctrine/`), that surface is part of the recall set — not just hub threads.

- ❌ "Hub threads are the recall surface"
- ✅ "Hub threads + workspace doctrine/design docs together"

### 3.8 Surface freshness in `cn doctor`

`cn doctor` reports the memory entrypoint as missing (Fail), stale (Info, > 30 days since the most recent thread mtime), or fresh (Pass). The 30-day threshold is v1 hard-coded; the literal appears in the doctor check value text so the rule is observable, not folklore.

- ❌ Carry your own ad-hoc staleness estimate
- ✅ Trust the doctor signal

### 3.9 Write the close-out receipt before exit

Part B (the session-close gate) is non-optional when the session produced any artifact, decision, or learning. A session that closes without a gate has not closed — its work is at compaction risk.

- ❌ Exit a working session with no close-out record
- ✅ Produce the structured close-out as the last act

---

## 4. Verify

Ask after writing or restoring:

- did I read the canonical entrypoint before acting?
- did I write the receipt at the moment of decision, not later?
- if I wrote a thread, does its frontmatter declare its relationships when applicable?
- if I restored, did I follow `supersedes` to the current entry?
- did the session close with a structured gate (Part B)?

If any answer is no, the work is not coherent — patch the gap before exit.

---

## 5. Known Debt

This cycle ships the protocol. The following are explicitly out of scope for v1 and tracked as future work:

- **Automated EOD transcript extraction** (issue #100 April-26 evidence point 5) — write triggers remain manual. Tooling cannot enforce a protocol that does not yet exist; ship the protocol first.
- **Contradiction detection at write time** (issue #100 April-26 evidence point 3) — semantic scan is future MCA work. `reflect` §3.6 (decision-basis capture) is the current manual mechanism.
- **Adhoc-thread corpus retrofit** — typed frontmatter relationships are a rule from this cycle forward; the existing adhoc-thread corpus stays un-migrated. A `forget` / `reindex` companion in B9c (issue #35) is the candidate future cycle.
- **Memory Palace–style retrieval layer** — retrieval (find facts by meaning) is candidate future backend (issue #100 April-26 external reference). Continuity comes first; retrieval sits underneath the continuity stack.

---

## 6. Embedded Kata

### Scenario

You wake into a session with a new task: "patch the activation membrane to load K=5 recent adhocs at session start."

### Task

Before writing any code:

1. Identify the canonical entrypoint from the runtime contract (`cognition.memory.entrypoint`).
2. Restore enough context to act without re-deriving (entrypoint → recent reflections → relevant adhoc threads → workspace doctrine if relevant).
3. When making a decision (e.g. choosing K=5 rather than K=10), write the receipt at the moment of decision.
4. At session close, produce the structured Part B close-out naming `artifact_refs`, `decision_refs`, `learnings_refs`, `memory_refs`, etc.

### Governing skill

`memory` (this skill); calls `reflect` and `adhoc-thread` for content surfaces.

### Inputs

- The runtime contract's `cognition.memory` block (backend, entrypoint, surfaces, freshness, scope)
- The canonical entrypoint runbook
- The current task description

### Expected artifacts

- A trace showing the entrypoint was read first (e.g. an early read of `docs/alpha/agent-runtime/MEMORY.md` in the session log)
- An adhoc-thread decision **or** an in-line receipt naming the K=5 choice and reason
- A session-close artifact with the Part B fields populated

### Verification

- `git diff` shows the receipt before the code change
- `cn doctor` reports the memory entrypoint as fresh after the session
- The decision is reachable next session via the close-out reference or the adhoc thread's frontmatter

### Common failures

- Skipping the entrypoint and grep-probing for context (no-restore)
- Making the decision without writing the receipt (no-write)
- Closing the session without the Part B gate (compaction risk)
- Treating `state/` as the place to record the decision (drift-from-surface)
- Citing a thread by prose where a typed relationship would have been traversable (no-index)

### Reflection

After the session, ask: what got recorded that future-you will actually use? What didn't get recorded because no trigger fired? Adjust the next session's recall and write discipline.
