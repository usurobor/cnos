# Memory — fresh-session restore runbook

**Status:** Runbook (v1, post-#100)
**Authority:** This file is the canonical restore entrypoint named by `cognition.memory.entrypoint` in the runtime contract.
**Owning skill:** `src/packages/cnos.core/skills/agent/memory/SKILL.md` (`cnos.core/skills/agent/memory`).
**Adjacent skills:** `cnos.core/skills/agent/reflect/SKILL.md` (reflective memory); `cnos.core/skills/ops/adhoc-thread/SKILL.md` (episodic memory).

This runbook tells a fresh session what to read first and in what order. It is the answer to "what should I read at session start" — without it, the agent re-derives context instead of restoring it.

---

## 0. Why this file exists

cnos agents have persistence in practice (reflections, adhoc threads, hub state, git history, runtime contract) but no canonical answer to: what to read at session start, what to write back, what counts as durable, what is only runtime projection.

Without that answer, every session re-derives. Behaviour-changing observations die with the session.

This file is the **fresh-session entrypoint**. The skill at `cnos.core/skills/agent/memory` is the **discipline**. Together they make memory a faculty rather than ad-hoc file probing.

---

## 1. What memory is — short form

Three surfaces, one entrypoint.

| Surface | Path | Owner | Contains |
|---|---|---|---|
| Reflective | `threads/reflections/` | `reflect` | daily / weekly / monthly / quarterly / yearly synthesis |
| Episodic | `threads/adhoc/` | `adhoc-thread` | typed standalone records: proposal, learning, question, decision |
| Working | `state/conversation.json` | runtime | recent turns across wake boundaries — useful, not canonical |

**Canonical retained memory is the first two.** Working continuity is useful retained state, not the source of truth. Everything else under `state/` is runtime projection — regenerated at wake, not memory.

The runtime contract exposes the same shape under `cognition.memory`:

```json
"cognition": {
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
}
```

`cn status` projects this block as a Memory section. `cn doctor` reports the entrypoint as missing (Fail), stale (Info, > 30 days since the most-recent thread mtime), or fresh (Pass).

---

## 2. Fresh-session restore — the ordered reads

When a new session starts, read in this order. Stop early when the task is bounded enough that further reads would only add noise.

1. **Runtime contract** — `cognition.memory` block (already in packed context). Confirms which entrypoint and surfaces are canonical for this hub.
2. **This file** — the runbook itself. The contract names it; reading it resolves the next-step pointers.
3. **The owning skill** — `cnos.core/skills/agent/memory/SKILL.md`. The discipline that names recall triggers, write triggers, and the index rule.
4. **Most-recent daily reflection** — the latest file under `threads/reflections/daily/`. Carries forward yesterday's judgment, open threads, and any in-flight cycle.
5. **Most-recent weekly** — `threads/reflections/weekly/` if newer than the daily or if the daily references it.
6. **Relevant adhoc threads** — open threads under `threads/adhoc/`, especially anything the daily or the current task references.
7. **Workspace doctrine / design docs** — when the task touches them. Recall is **hub threads + workspace doctrine**, not hub threads alone (#100 AC4, April-26 evidence point 1). For cnos, that means `docs/alpha/doctrine/`, `docs/alpha/agent-runtime/`, and any design doc named by the current task.

The skill (`cnos.core/skills/agent/memory`) also names triggers for *re-reading* during a session: before answering about prior work, before planning or reprioritizing, before filing or updating an issue, after a correction.

---

## 3. Write protocol — short form

Three rules. The skill carries the full protocol.

1. **Write at the moment of recognition** — a behaviour-changing observation is durable only when it is in a surface git can serve next session.
2. **Use the right surface** — daily/weekly synthesis goes to `threads/reflections/` (see `reflect`); a proposal / learning / question / decision goes to `threads/adhoc/` (see `adhoc-thread`); `state/` is not memory.
3. **Close the session with a structured gate** — Part B receipt naming `artifact_refs`, `debt_refs`, `decision_refs`, `learnings_refs`, `memory_refs`, `upstream_pending`. The full schema and the in-line MCA receipt form (Part A) are in the skill.

If a session produced any artifact / decision / learning and exits without the Part B gate, its work is at compaction risk.

---

## 4. Index — typed frontmatter relationships

Adhoc threads navigate by typed frontmatter, not prose pointers. The skill names this as a rule from this cycle forward; existing threads are not retrofitted by #100.

```yaml
---
type: learning
relates_to: [20260520-some-other-thread]
supersedes: [20260418-old-thread]
derived_from: [20260520-daily]
---
```

Restore reads `supersedes` to follow the chain to the current entry. Without typed relationships, links are not traversable; with them, the existing surfaces stay navigable without a retrieval index.

---

## 5. Freshness signal

`cn doctor` reports the memory entrypoint:

| State | Status | Meaning |
|---|---|---|
| Skill file missing | Fail | cnos.core not installed or memory skill missing |
| Present, no thread activity yet | Info | Legitimate fresh hub |
| Most-recent thread mtime > 30 days | Info | Stale (operator-visible, not merge-gating) |
| Most-recent thread mtime ≤ 30 days | Pass | Fresh |

The 30-day threshold is v1 hard-coded. The literal appears in the doctor check value text so the rule is data, not folklore. `cn status` shows the same freshness summary in its Memory section.

---

## 6. Known debt (v1 non-goals — future work)

- **Automated EOD transcript extraction** — write triggers remain manual; the discipline must exist before tooling can enforce it.
- **Contradiction detection at write time** — manual via `reflect` §3.6 decision-basis capture. Semantic scan is a future MCA candidate.
- **Adhoc-thread corpus retrofit** — typed relationships apply from this cycle forward. Migrating the existing corpus is a separate cycle (candidate: B9c / `forget` / `reindex`).
- **Retrieval backend** — Memory Palace–style retrieval (find facts by meaning) is a candidate future backend per `cognition.memory.backend`. The continuity stack (this file + skill + surfaces) comes first; retrieval sits underneath.

---

## §Supersession — v0.2.0 design history

This file previously held the v0.2.0 lean-triadic design for #100, written 2026-02–03 era. That design **explicitly rejected** a dedicated `agent/memory` skill, on the basis that `reflect` + `adhoc-thread` alone provided enough discipline.

#100 supersedes that rejection. The empirical anchors are documented in #100's 2026-04-26 evidence comment and the 2026-05-20 cnos#386 fold-in. Summary of what changed and why:

| v0.2.0 position | Post-#100 position | Why |
|---|---|---|
| "No new agent/memory skill is required in v1" | New skill at `cnos.core/skills/agent/memory` | Without a named faculty, every session re-derived context. The April-26 receipt-stream pattern (an essay sitting unread in the same repo) made the gap empirical. |
| Memory architecture is the three surfaces alone | Three surfaces **plus** an entrypoint **plus** a discipline (skill + runbook) | A taxonomy without a recall protocol is undiscoverable. The skill carries the recall + write protocol; this runbook is the single named entrypoint. |
| `state/conversation.json` rendered alongside reflections as "memory" | `state/conversation.json` is **working continuity, not canonical** | Distinction was implicit in v0.2.0 prose; #100 makes it normative in the contract field shape and in the skill body. |
| Recall surface is hub threads | Recall surface is hub threads **+ workspace doctrine/design docs** | April-26 evidence point 1 — the highest-leverage gap. |
| Write triggers implicit in `reflect` / `adhoc-thread` | Write triggers enumerated in the skill, with cnos#386's two-part shape (in-line MCA receipts + structured session-close gate) | cnos#386 named a concrete protocol shape worth folding in at AC5. |

What v0.2.0 got right and #100 preserves:

- Canonical retained memory is `threads/reflections/` + `threads/adhoc/` (not a third surface, not a vector store).
- `reflect` and `adhoc-thread` remain the practice layer — the memory skill **coordinates** them by name; it does not reach into them.
- No `threads/memory/INDEX.md`, no embeddings, no knowledge graph in v1 (non-goals preserved).

The v0.2.0 framing of episodic / reflective / working memory mapped onto the three surfaces and is still a useful narrative; #100 keeps it implicit rather than re-declaring it.

The v0.2.0 file's CDD-style frontmatter and Acceptance Criteria sections referred to a design cycle that has since merged; this file's authority is now the runbook, not the historical design.

---

## §Related

- `src/packages/cnos.core/skills/agent/memory/SKILL.md` — the discipline this runbook activates
- `src/packages/cnos.core/skills/agent/reflect/SKILL.md` — owns `threads/reflections/`
- `src/packages/cnos.core/skills/ops/adhoc-thread/SKILL.md` — owns `threads/adhoc/`
- `docs/alpha/agent-runtime/RUNTIME-CONTRACT-v2.md` — schema of `cognition.memory`
- Issue #100 — memory as first-class retention faculty (this runbook closes AC7)
- Issue #386 — session-receipt mechanism (folded into AC5 as Parts A and B of the write protocol)
- Issue #35 — adjacent companion: forget / reindex skills (B9c)
