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

---

## §ACs

AC text is #100 verbatim. Evidence is named at file:line where appropriate; behavioural evidence (test runs) cites the runner output.

### AC1 — Runtime contract declares `memory` under `cognition`

> Runtime contract declares `memory` under `cognition` as a retention faculty. Fields: `backend` (e.g. `git+threads+state`), `entrypoint` (canonical restore surface), `surfaces` (readable/writable paths), `freshness` (last-update / staleness signal), `scope` (what memory is expected to preserve).

**Met.** Evidence:

- `src/ocaml/lib/cn_contract.ml:124-148` — new `type memory` record `{backend; entrypoint; surfaces; freshness; scope}`; `cognition` record extended with `memory : memory` field. Pure-type module; no IO.
- `src/ocaml/cmd/cn_runtime_contract.ml:73-87` — type re-export mirror (Cn_contract.memory = …) preserves the type-equality syntax discipline so existing callers continue to resolve through Cn_runtime_contract.
- `src/ocaml/cmd/cn_runtime_contract.ml:222-281` — `memory_state ~hub_path` helper: derives `freshness` from filesystem mtime over `threads/reflections/{daily,weekly}` + `threads/adhoc/`; renders as "most-recent: N days ago" / "no memory activity"; v1 defaults for backend (`git+threads+state`), entrypoint, surfaces, scope.
- `src/ocaml/cmd/cn_runtime_contract.ml:368-374` — `gather` threads `memory` into the `cognition` construction.
- `src/ocaml/cmd/cn_runtime_contract.ml:455-465` — `render_markdown` writes a `memory:` block after `active_overrides` with the five fields (preserves prompt-cache-stable deterministic ordering).
- `src/ocaml/cmd/cn_runtime_contract.ml:563-571` — `to_json` serializes `cognition.memory` as a JSON object with the five fields.
- `docs/alpha/agent-runtime/RUNTIME-CONTRACT-v2.md` §2.2 (Cognition table + sub-shape table); §4 (JSON example with cognition.memory block); §5 (Markdown rendering with memory lines); §6 (doctor validation note for checkMemoryEntrypoint + 30-day threshold).

Peers updated:
- Type-construction sites: `test/lib/cn_contract_pure_test.ml:195-225` (CG1) and `:262-282` (RC1) — both record literals updated; `dune runtest test/lib` exit 0.
- The two type-equality-mirror sites (`cn_contract.ml` + `cn_runtime_contract.ml`) both received the new field.

### AC2 — Agent skill at canonical role-skill location

> Agent skill at the canonical role-skill location (post-B14a rename: `self/memory/SKILL.md`; pre-rename: `agent/memory/SKILL.md`) defines: storage taxonomy, write triggers, recall triggers, indexing/restore discipline.

**Met.** Evidence:

- `src/packages/cnos.core/skills/agent/memory/SKILL.md` — 326 lines, conforms to `cnos.core/skills/skill/SKILL.md` meta-skill (Define → Unfold → Rules → Verify → Kata; declares `artifact_class: skill`, `kata_surface: embedded`, governing question).
- Storage taxonomy at §2.1 (table form: surface ↔ owner ↔ contains).
- Write triggers enumerated at §2.3 (six trigger types; AC5-verbatim).
- Recall triggers enumerated at §2.2 (five trigger types; AC4-verbatim).
- Indexing/restore discipline at §2.4 (typed frontmatter relationships `relates_to`, `supersedes`, `derived_from`).
- Length is within the sibling-skill band (~300–500 lines per scaffold §6.2); siblings under `cnos.core/skills/agent/` range 24–497 lines, median ~110.
- `.gitignore` adjusted: top-level `memory/` rule (hub-instance protection) broadly matched the skill path; added `!src/packages/cnos.core/skills/agent/memory/**` negation so the skill is trackable while hub-instance memory/ stays ignored.

### AC3 — Storage taxonomy

> Storage taxonomy: `threads/reflections/` owned by `reflect`; `threads/adhoc/` owned by `adhoc-thread`; memory index/restore entrypoint owned by `memory`; `state/` is runtime projection (not canonical retained memory).

**Met.** Evidence:

- Memory skill §2.1 (table form): `threads/reflections/` → `reflect`; `threads/adhoc/` → `adhoc-thread`; `state/conversation.json` → runtime (working continuity, not canonical); `state/` (other) → runtime projection, not memory.
- MEMORY.md runbook §1 mirrors the same taxonomy.
- Rule 3.3 ("Treat `state/` as projection, not memory") enforces the projection ↔ memory distinction with ❌/✅.
- `reflect` and `adhoc-thread` are referenced by path only — not edited (non-goal #3 preserved).

### AC4 — Recall protocol

> Recall protocol: minimum triggers documented (session start; before answering about prior work / dates / decisions / status; before planning / reprioritizing; before filing or updating issues; after corrections that may change future behavior).

**Met.** Evidence:

- Memory skill §2.2 enumerates all five triggers verbatim.
- §2.2 closes with the recall-surface scope: "hub threads + workspace doctrine/design docs" (April-26 evidence point 1 — the highest-leverage gap is the *surface* widening, captured here).
- MEMORY.md runbook §2 prescribes the ordered reads (runtime contract → runbook → owning skill → latest daily → weekly → adhoc → workspace doctrine).
- Memory skill rule 3.1 ("Read the canonical entrypoint at session start") + rule 3.7 ("Restore covers workspace docs too") embed the protocol as imperative rules.

### AC5 — Write protocol

> Write protocol: minimum triggers (after shipping work; after corrections / MCIs; after making or changing a plan; after learning something behavior-changing; before session end / compaction risk; cadence reflection).

**Met.** Evidence:

- Memory skill §2.3 enumerates all six triggers verbatim.
- §2.3 prescribes cnos#386's two-part shape as the canonical minimum structure (scaffold §3 AC5 γ note): Part A (in-line MCA receipts at decision time, with full receipt format) + Part B (structured session-close gate with the six-field schema `artifact_refs` / `debt_refs` / `decision_refs` / `learnings_refs` / `memory_refs` / `upstream_pending`).
- Rule 3.9 ("Write the close-out receipt before exit") makes Part B non-optional when the session produced any artifact / decision / learning.
- Out-of-scope items (automated EOD transcript extraction, contradiction detection) are documented as known debt in §5, not implemented (non-goal #1 preserved; scaffold §6.1).

### AC6 — `cn status` + `cn doctor` surfaces

> `cn status` surfaces memory state. `cn doctor` (post-B10a) can report missing/stale memory entrypoint.

**Met.** Evidence:

- `src/go/internal/hubstatus/hubstatus.go:38-50` — `Run` calls `showMemory` after `showPackages`.
- `src/go/internal/hubstatus/hubstatus.go:54-101` — `showMemory` reads `state/runtime-contract.json`, projects `cognition.memory` as a Memory section. Three states: contract absent → pending; unparseable → pending (diagnostic); present → render five fields.
- `src/go/internal/hubstatus/hubstatus_test.go:217-280` — two new tests: `TestRunMemoryPending` (contract absent), `TestRunMemoryFromContract` (happy-path projection).
- `src/go/internal/doctor/doctor.go:121-126` — `RunAll` calls `checkMemoryEntrypoint`.
- `src/go/internal/doctor/doctor.go:343-394` — `checkMemoryEntrypoint` implementation. Three-state semantics: missing entrypoint → StatusFail; present with no thread activity or stale (most-recent > 30 days) → StatusInfo; fresh → StatusPass. 30-day threshold literal surfaced in the value text.
- `src/go/internal/doctor/doctor_test.go:218-322` — four new tests covering all four states (Missing, PresentNoActivity, Fresh, Stale). The Stale test asserts the literal "30" appears in the value text (scaffold §6.5 happy-path + unhappy-path coverage).
- `go test ./...` exit 0 (all 13 packages; cached after first run).

### AC7 — Fresh-session restore entrypoint

> Fresh-session restore has one named entrypoint instead of ad-hoc file probing. Verified by a runbook in `docs/alpha/agent-runtime/MEMORY.md` (or equivalent).

**Met.** Evidence:

- `docs/alpha/agent-runtime/MEMORY.md` rewritten as the runbook (per scaffold §3 AC7 γ recommendation). §0 names the gap; §1 names the three surfaces and the entrypoint; §2 prescribes the ordered reads; §3 carries the write-protocol short form (full form in the skill); §4 names the index discipline; §5 names the freshness signal semantics; §6 enumerates known debt.
- v0.2.0 design lineage preserved in §Supersession (paired-state table: v0.2.0 position ↔ post-#100 position ↔ why; what v0.2.0 got right and #100 preserves).
- Mutual reference: memory skill names the runbook as the canonical entrypoint; runbook names the skill as the discipline. Runtime contract's `cognition.memory.entrypoint` points at the skill (the installed file every hub has); the runbook is named in the skill body and in the schema doc. Both surfaces agree on the canonical entrypoint (scaffold §6.3 consistency check).
