# α self-coherence — cycle/100

**Issue:** cnos#100 — "B9b: memory as a first-class retention faculty — contract, skill, recall + write protocol"
**Branch:** `cycle/100` from `origin/main@5e8cafdb`
**Mode:** design-and-build (per γ scaffold §1.1 + §8)
**α:** `alpha@cdd.cnos`
**Author:** α session 2026-05-20

This file is written incrementally per `alpha/SKILL.md §2.5`, one section per commit.

---

## §Gap

The named gap (from #100 body):

> cnos agents have persistence in practice (reflections, adhoc threads, hub state, git history, runtime contract) but not memory as a named faculty. There is no canonical answer to: what to read at session start, what to write back, what counts as durable, what is only runtime projection.

The cycle's MCA: make memory a faculty by adding (1) a runtime-contract field under `cognition`, (2) an agent skill that owns the recall + write protocol, (3) a `cn status` + `cn doctor` projection, (4) a fresh-session runbook with a single canonical entrypoint. γ's scaffold §2 confirmed all proposed surfaces are net-new (grep-verified absences); the cycle does not rename / repurpose existing surfaces.

ε framing (from scaffold §1) — this cycle is the MCA against the receipt-stream pattern: the memory problem prevents the agent from remembering there's a memory problem. Mode: design-and-build. Design converges in the issue body + γ scaffold + this file; no separate DESIGN.md.

Path-coordination (scaffold §1.1 decision (b)): this cycle ships the skill at `src/packages/cnos.core/skills/agent/memory/SKILL.md`. #101 B14a renames `agent/` → `self/` mechanically post-merge.
