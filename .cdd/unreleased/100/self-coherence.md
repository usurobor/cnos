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

---

## §Skills

Active skill set (per γ dispatch + scaffold §1.2):

| Tier | Skill | Where it constrained authoring |
|---|---|---|
| 1 | `cnos.cdd/skills/cdd/alpha/SKILL.md` | role contract + load order + pre-review gate (this file's structure) |
| 1 | `cnos.core/doctrine/KERNEL.md §1.4 Memory` | memory faculty doctrine context |
| 2 | `cnos.eng/skills/eng/document/SKILL.md` | MEMORY.md runbook + RUNTIME-CONTRACT-v2.md schema doc form |
| 2 | `cnos.eng/skills/eng/ocaml/SKILL.md` | OCaml type extension + emitter authoring |
| 2 | `cnos.eng/skills/eng/go/SKILL.md` | doctor + hubstatus authoring (table-driven tests, eng/go §2.18 dispatch boundary respected) |
| 3 | `cnos.core/skills/skill/SKILL.md` | meta-skill conformance for the new memory skill (Define → Unfold → Rules → Verify → Kata; declared `artifact_class: skill`, `kata_surface: embedded`) |
| 3 | `cnos.core/skills/agent/reflect/SKILL.md` | referenced by path from new memory skill; not edited (non-goal #3) |
| 3 | `cnos.core/skills/ops/adhoc-thread/SKILL.md` | referenced by path from new memory skill; not edited (non-goal #3) |

MEMORY.md v0.2.0 supersession (scaffold §2.3): read as historical context for the lean-triadic α/β/γ memory-class framing; #100 supersedes its §3 / §Alternatives rejection of an agent/memory skill. The supersession is documented in MEMORY.md's new §Supersession block as a paired-state table (v0.2.0 position ↔ post-#100 position ↔ why).
