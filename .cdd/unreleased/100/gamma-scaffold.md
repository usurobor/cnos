# γ scaffold — cycle/100

**Issue:** cnos#100 — "B9b: memory as a first-class retention faculty — contract, skill, recall + write protocol"
**Branch:** `cycle/100` from `origin/main@5e8cafdb`
**Mode:** design-and-build (operator-set; per §1.3 below)
**Dispatch:** §5.1 canonical multi-session (γ → α → β; one `claude -p` at a time; operator/SKILL.md §5.3 escalation: 7 ACs **and** new contract surface)
**γ:** `gamma@cdd.cnos`
**Author:** γ session 2026-05-20

---

## 1. ε framing — why this cycle is happening now

This cycle is the MCA against an ε-observed receipt-stream pattern (per `cnos.cdd/skills/cdd/epsilon/SKILL.md §1`).

- cnos#100 was filed 2026-03-24 declaring memory as a kernel faculty (already in `cnos.core/doctrine/KERNEL.md §1.4`). Two months later the faculty is named but unimplemented; every cnos session since has run without the memory skill the kernel says is supposed to exist.
- 2026-05-20 (today) is an empirical anchor: Σ filed cnos#386 — a session-receipt mechanism that is a subset of #100 AC5 — **without first checking the existing issue space**, despite the durable rule that already exists at `cn-sigma:threads/adhoc/20260519-cross-repo-feedback-loop.md`. The discipline that exists on disk did not fire because the memory faculty that would carry it forward is itself the thing that is broken.
- The recursive structure (the memory problem prevents the agent from remembering there's a memory problem) is the receipt-stream pattern ε observes. The MCA available now is to ship #100.

This framing is the cycle's **why**. It does not expand the AC set; ACs are still #100 AC1–AC7 verbatim. ε's `cdd-iteration.md` at close-out will name this finding (the receipt-stream pattern that triggered the cycle).

---

## 1.1 Operator decisions captured before dispatch

The operator framed three load-bearing decisions in the γ briefing. They are recorded here so future readers of the cycle artifact set do not have to reconstruct them from chat:

- **Mode:** `design-and-build`. Design converges in #100 body + this scaffold; **no separate DESIGN.md**. Per `issue/SKILL.md` mode taxonomy, MCA preconditions do not all hold (the plan path is not committed at a stable location), so MCA mis-labelling is ruled out by construction. `design-and-build` is the correct label.
- **Dispatch:** §5.1 canonical multi-session (γ → α → β). Per `operator/SKILL.md §5.3` escalation criteria, BOTH triggers fire (≥7 ACs **and** new contract surface). δ-as-γ collapse is rejected. One `claude -p` per role.
- **Path coordination (operator override per §4):** #100 names cnos#101 (B14a — skill corpus normalize) as the hard blocker for `self/memory/` vs `agent/memory/`. #101 is OPEN. Operator decision (2026-05-20): path (b) — **coordinate the path explicitly**. Use `agent/memory/SKILL.md` for this cycle. When #101 lands B14a, the rename moves the file to `self/memory/SKILL.md` mechanically. γ records this as a candidate `cdd-protocol-gap` for cdd-iteration.md: "cycle/100 used pre-B14a path; rename pending #101."

These three decisions stand for the cycle. α and β do not re-litigate them.

---

## 1.2 γ-side Tier 3 clarification

#100 body lists Tier 3 skills: `eng/document`, `eng/go`, `cnos.core/skills/skill`. The contract emitter that produces `state/runtime-contract.json` is **OCaml** (`src/ocaml/cmd/cn_runtime_contract.ml` + canonical types in `src/ocaml/lib/cn_contract.ml`), not Go. AC1 lands in OCaml (record types + emitter + JSON projection + markdown rendering); AC6 lands in Go (`cn status` + `cn doctor` consumption). γ adds **`eng/ocaml`** to the Tier 3 set so the contract-emitter half of AC1 has a loaded skill. This is a clarification, not a target-gap change; `eng/go` and `eng/ocaml` together cover the actual implementation surfaces #100 names.

**Effective Tier 3 for α:** `eng/document`, `eng/go`, `eng/ocaml`, `cnos.core/skills/skill`.

α loads `cnos.core/skills/skill/SKILL.md` when authoring `agent/memory/SKILL.md` so the new skill conforms to the meta-skill. γ does not name Tier 1 / Tier 2 here (`write/SKILL.md` is always included by α; `eng/*` Tier 2 bundles per `cnos.eng/skills/eng/README.md`).

---

## 2. Gap

### 2.1 Surface-level statement

cnos agents have persistence in practice (reflections, adhoc threads, hub state, git history, runtime contract) but **memory is not yet a named faculty with a declared recall + write protocol**. The kernel (`cnos.core/doctrine/KERNEL.md §1.4`) lists the four memory surfaces (Traces / Adhoc / Reflections / Promotion) as a principle. #100 turns the principle into protocol: a contract field, a skill, a runbook, and a `cn status` / `cn doctor` projection.

### 2.2 Empirical evidence (grep-confirmed)

Per `gamma/SKILL.md §2.2a`, γ confirmed the absences before scaffolding. Commands run from `/root/cnos` against `origin/main@5e8cafdb`:

| Claim | Grep | Result | Implication |
|---|---|---|---|
| No `agent/memory/` skill dir | `ls src/packages/cnos.core/skills/agent/memory` | absent | AC2 is a wholly new skill, not a patch |
| No `self/memory/` skill dir | `ls src/packages/cnos.core/skills/self/memory` | absent | Confirms path-coordination decision (`agent/memory/`) |
| No `cognition.memory` field in code | `rg "cognition\.memory" src/` | absent | AC1 is a new field, not a rename |
| No `Memory_zone` / `memory_entrypoint` constructor | `rg "Memory_zone\|MemoryZone\|memory_entrypoint" src/` | absent | AC1's `entrypoint` field is structurally new |
| `memory` exists only as a *medium zone* | `rg "Memory" src/ocaml/cmd/cn_runtime_contract.ml` | 1 match (zone constructor at L52, L458) | Current contract treats memory as a path-zone, not a cognition record. AC1 lifts it to a cognition record with structured fields |
| `cn status` does not surface memory | `rg "memory" src/go/internal/hubstatus/` | absent | AC6 (`cn status` projection) is a wholly new surface |
| `cn doctor` does not check memory entrypoint | `rg "memory" src/go/internal/doctor/` | absent | AC6 (`cn doctor` freshness/missing check) is a wholly new check |
| `docs/alpha/agent-runtime/MEMORY.md` exists (v0.2.0) | `git ls-files docs/alpha/agent-runtime/MEMORY.md` | present | **Supersession context, not a constraint** — see §2.3 below |
| `retention faculty` referenced | `rg "retention faculty"` | 2 hits (this issue's analysis doc + MEMORY.md self-reference) | Term is owned by #100; this cycle implements it |

The gap is real and the proposed surfaces do not partially exist. AC1, AC2, AC6, AC7 each add net-new artifact surface; AC3, AC4, AC5 codify protocol that lives only as implicit practice.

### 2.3 MEMORY.md v0.2.0 supersession

`docs/alpha/agent-runtime/MEMORY.md` was authored as a lean-triadic design for #100. It explicitly states (§3 Ownership Split): *"No new agent/memory skill is required in this v1 design."* It also rejects (§Alternatives Considered): *"New dedicated agent/memory skill now — Rejected."*

#100's body, as canonically updated through the 2026-04-26 evidence comment and the 2026-05-20 cnos#386 fold-in, **supersedes** that part of MEMORY.md. AC2 mandates the skill. α must read MEMORY.md as historical context (the lean-triadic α/β/γ memory-class model is still useful framing for AC3 storage taxonomy), not as a binding constraint that blocks AC2. The Acceptance Criteria of MEMORY.md itself (its line: *"Existing reflect and adhoc-thread skills remain the practice layer for memory"*) is a non-goal pattern preserved by #100's non-goals ("Replacing `reflect` or `adhoc-thread`") — the discipline is preserved; the addition is the entrypoint skill that *coordinates* them.

α's `self-coherence.md` should record this supersession explicitly in §Debt or §Skills.

---

## 3. Acceptance criteria — γ notes on how comment evidence and cnos#386 fold in

The AC text below is **#100 verbatim**. γ does not paraphrase. Each γ-side note explains how the 2026-04-26 evidence comment and the cnos#386 sibling proposal fold into the AC at scaffold time, **without** expanding the AC.

### AC1 — Runtime contract: memory under cognition

> Runtime contract declares `memory` under `cognition` as a retention faculty. Fields: `backend` (e.g. `git+threads+state`), `entrypoint` (canonical restore surface), `surfaces` (readable/writable paths), `freshness` (last-update / staleness signal), `scope` (what memory is expected to preserve).

**γ note.** The contract emitter is OCaml (`src/ocaml/cmd/cn_runtime_contract.ml`, with canonical types in `src/ocaml/lib/cn_contract.ml`). AC1 adds a `memory` record to the `cognition` record type, threads it through `gather`, `render_markdown`, and `to_json`, and includes it in `src/go/internal/doctor/doctor.go` `checkRuntimeContract` (currently checks the four top-level keys `identity/cognition/body/medium`; the cognition sub-shape check may stay structural). The April-26 comment point (4) — *"`last_referenced` frontmatter + `cn doctor` flagging threads not referenced in 30+ days"* — sharpens AC1's `freshness` field to mean: derive freshness from filesystem mtime of the memory entrypoint and the most-recent adhoc/reflection file under the surfaces. The `staleness signal` is observable in `state/runtime-contract.json` and projected by `cn status` / `cn doctor` (AC6).

**γ note (backend value).** The issue body example uses `git+threads+state` as a backend literal. Treat this as a canonical default for v1; the field is open-string so future backends (e.g. memory-palace per April-26 external reference, or any other retrieval layer) can populate it without contract change.

### AC2 — Agent skill at canonical role-skill location

> Agent skill at the canonical role-skill location (post-B14a rename: `self/memory/SKILL.md`; pre-rename: `agent/memory/SKILL.md`) defines: storage taxonomy, write triggers, recall triggers, indexing/restore discipline.

**γ note (path decision).** Per operator decision (§1.1), this cycle uses `src/packages/cnos.core/skills/agent/memory/SKILL.md`. When #101 B14a ships the rename, the file moves mechanically. α writes the skill against the canonical meta-skill (`cnos.core/skills/skill/SKILL.md`): Define / Unfold / Rules / kata.

**γ note (April-26 evidence point 2).** *"Relationships between threads are implicit. 139 adhoc threads reference each other in prose. Links aren't traversable."* This sharpens AC2's *indexing/restore discipline* clause: the skill prescribes typed frontmatter relationships (`relates_to`, `supersedes`, `derived_from`) as the canonical surface for inter-thread links. **Scope guard:** this is a recommendation pattern in the skill, not a corpus-wide retrofit. The cycle does NOT migrate the existing 139 adhoc threads — that is downstream work (a `forget`/`reindex` companion in B9c per #35). The cycle ships the rule, not the migration.

### AC3 — Storage taxonomy

> Storage taxonomy: `threads/reflections/` owned by `reflect`; `threads/adhoc/` owned by `adhoc-thread`; memory index/restore entrypoint owned by `memory`; `state/` is runtime projection (not canonical retained memory).

**γ note.** AC3 is doctrinal — the skill body declares the split. MEMORY.md v0.2.0's lean-triadic α/β/γ framing (episodic / reflective / working continuity) maps onto AC3's three surfaces and is acceptable as the skill's narrative; the canonical names `threads/reflections/`, `threads/adhoc/`, `memory index/restore entrypoint`, `state/` are #100's authority and override any sub-naming MEMORY.md uses.

### AC4 — Recall protocol

> Recall protocol: minimum triggers documented (session start; before answering about prior work / dates / decisions / status; before planning / reprioritizing; before filing or updating issues; after corrections that may change future behavior).

**γ note (April-26 evidence point 1).** *"Recall surface too narrow. `memory_search` covers hub threads but not workspace docs."* This sharpens AC4's *session start* trigger and *before answering about prior work* trigger: the canonical entrypoint must enumerate **both** hub threads *and* workspace doctrine/design docs (e.g. `cnos/docs/alpha/doctrine/COHERENCE-FOR-AGENTS.md` was the unread doc in the April-26 receipt). The skill names the surface set rather than a tool — the surface is what the protocol prescribes; the tool is downstream. The April-26 phrase *"expanding recall to cover cnos doctrine/design docs is the single highest-leverage fix"* is exactly an AC4 deliverable in this cycle.

### AC5 — Write protocol

> Write protocol: minimum triggers (after shipping work; after corrections / MCIs; after making or changing a plan; after learning something behavior-changing; before session end / compaction risk; cadence reflection).

**γ note (cnos#386 fold-in).** cnos#386 (filed 2026-05-20 by Σ) proposes a two-part shape for the write protocol: (A) in-line MCA receipts at decision time (one short file per brief-allowed degree of freedom); (B) a structured session-close gate (schema-validated checklist of `artifact_refs`, `debt_refs`, `decision_refs`, `learnings_refs`, `memory_refs`, `upstream_pending`).

**Disposition:** fold #386's two-part shape into AC5 as the **prescribed minimum write-protocol structure**. The memory skill names the write triggers (AC5 list verbatim) and then prescribes #386's two-part shape as the canonical surface form for each trigger. Specifically:
- After shipping work / after corrections / after plan change / after learning → Part A (in-line MCA receipt) **or** an adhoc-thread (when the content is substantive enough to warrant `adhoc-thread` skill ownership).
- Before session end / compaction risk → Part B (structured session-close checklist).
- Cadence reflection → owned by `reflect` skill (existing).

#386 itself stays OPEN as a sibling (operator decision 2026-05-20); when this cycle lands AC5 with #386's shape, γ records a post-merge action: post a comment on #386 noting the fold-in, and close #386 as `subsumed by #100` (or hold open for the V-validator portion if α surfaces design tension that warrants keeping #386 as a separate validator-enforcement issue).

**γ note (April-26 evidence point 3).** *"Contradiction detection is manual."* AC5 does NOT require automated contradiction scan in v1. It is reasonable to mention contradiction-detection as a known-debt entry in the skill body ("future MCA: semantic scan at write time"), but it is **out of scope** for this cycle. Non-goal #1 ("Vector store or external memory database in v1") covers this.

**γ note (April-26 evidence point 5).** *"Write triggers are manual. Automated EOD transcript extraction to catch missed write triggers."* AC5 ships the manual checklist (Part B). Automation is downstream — the protocol must exist before tooling can enforce it. Out of scope for this cycle; note as known debt.

### AC6 — cn status + cn doctor surfaces

> `cn status` surfaces memory state. `cn doctor` (post-B10a) can report missing/stale memory entrypoint.

**γ note.** `cn status` lives at `src/go/internal/hubstatus/hubstatus.go` (Go). `cn doctor` lives at `src/go/internal/doctor/doctor.go` (Go). Both consume `state/runtime-contract.json` (or recompute from hub layout). AC6 adds:
- `cn status`: render a `Memory` section after `Cognition`, projecting the new `cognition.memory` record from AC1 (entrypoint, backend, surfaces, freshness summary).
- `cn doctor`: a `checkMemoryEntrypoint` (or equivalent) that returns `StatusFail` when the memory entrypoint is missing, `StatusInfo` when it exists but is stale beyond a configurable threshold, `StatusPass` otherwise. Freshness threshold may be hard-coded for v1 (e.g. 30 days per April-26 point 4); make it explicit in the check value text.

The issue body parenthetical "(post-B10a)" indicates B10a is the canonical post-extraction package for doctor. As of `5e8cafdb`, doctor lives at `src/go/internal/doctor/`; this is the canonical surface today regardless of B10a status. α adds the check there.

### AC7 — Fresh-session restore entrypoint

> Fresh-session restore has one named entrypoint instead of ad-hoc file probing. Verified by a runbook in `docs/alpha/agent-runtime/MEMORY.md` (or equivalent).

**γ note.** AC7 wants a **runbook** that (a) names a single canonical entrypoint a fresh session reads first, and (b) sequences the reads (entrypoint → recent reflections → relevant adhoc → workspace doctrine when applicable). The runbook may extend the existing `docs/alpha/agent-runtime/MEMORY.md` (replacing the v0.2.0 design content with the post-#100 runbook), or be a sibling file (`MEMORY-RUNBOOK.md`) with MEMORY.md retained as historical design context. α decides; the issue grants either path with "(or equivalent)."

**γ recommendation:** replace MEMORY.md's body with the runbook; preserve the v0.2.0 design lineage in a §Design history or §Supersession block at the bottom. This avoids two files with overlapping authority.

---

## 4. Non-goals (verbatim from #100, with γ enforcement note)

1. Vector store or external memory database in v1 (faculty is protocol + discipline; backends are future).
2. Redefining memory as a body capability provider (it's cognition, not body).
3. Replacing `reflect` or `adhoc-thread` (those remain adjacent skills).
4. Collapsing runtime projection (`state/`) into canonical retained memory.
5. Cross-agent memory federation (one agent's memory; cross-agent is #218 / B12 territory).

**γ enforcement note.** Non-goal 1 explicitly rules out the automated contradiction scan (April-26 point 3) and automated EOD transcript extraction (April-26 point 5). β should reject any diff that introduces a vector index, embedding store, or retrieval backend; those belong to a follow-up cycle if the operator ever opens one. Non-goal 3 means `reflect` and `adhoc-thread` skill bodies are **untouched** by this cycle — the new memory skill *coordinates* them by name; it does not reach into them and edit their text.

---

## 5. Peer enumeration

Per `gamma/SKILL.md §2.2a`, the directories named by #100's impact graph were listed and grep'd. Result enumerated in §2.2 above (all surfaces grep-confirmed absent). Peers in the **issue graph** (not the same as code peers):

| Peer issue | Relationship | Sequencing |
|---|---|---|
| **cnos#101** (B14a — skill corpus normalize, `agent/` → `self/` rename) | Hard blocker per #100; γ coordinated path explicitly (§1.1). Cycle uses `agent/memory/`. | Independent; rename moves file mechanically post-B14a |
| **cnos#386** (session-receipt mechanism) | Sibling AC5 design input. Folded into AC5 per §3 AC5 γ note. Stays OPEN as sibling. | Folds in this cycle; closure follow-up post-merge |
| **cnos#35** (B9c — daemon reflection cadence + forget skill) | Adjacent. Consumes the same surfaces this cycle ships. Not blocked by #100, but #100 makes #35's work cheaper. | Independent; lands after #100 |
| **cnos#84** (B16 — CA mindset reflection requirement, direct skill-text sweep) | Companion. Ships separately in B16. No code path conflict. | Independent |
| **cnos#149** (B16 — UIE skill loading) | Companion. Ships separately. No code path conflict. | Independent |
| **cnos#218** (B12 — cross-agent memory federation) | Downstream. Non-goal of this cycle. | Independent; downstream |
| **cnos#15** (forget skill) | Adjacent companion in B9c. | Independent |
| **cnos#45** (B12 — native issues issue-thread substrate) | Blocked by #100 (issue-thread substrate references memory entrypoint). | Downstream |

**Code peers** (touched by the diff):
- `src/ocaml/lib/cn_contract.ml` — canonical record types (`cognition` record extends; new `memory` record type)
- `src/ocaml/cmd/cn_runtime_contract.ml` — emitter (`gather`, `render_markdown`, `to_json`)
- `src/go/internal/doctor/doctor.go` — `checkRuntimeContract` + new `checkMemoryEntrypoint`
- `src/go/internal/doctor/doctor_test.go` — fixture for memory field + new check
- `src/go/internal/hubstatus/hubstatus.go` — Memory section in `Run`
- `src/go/internal/hubstatus/hubstatus_test.go` — golden output update
- `src/packages/cnos.core/skills/agent/memory/SKILL.md` — new skill
- `docs/alpha/agent-runtime/RUNTIME-CONTRACT-v2.md` — schema doc update (§2.2 Cognition table + JSON example + markdown rendering example)
- `docs/alpha/agent-runtime/MEMORY.md` — runbook (rewrite body to runbook form; preserve v0.2.0 design as §Supersession)
- `src/packages/cnos.core/skills/agent/memory/kata/` — kata content if the meta-skill rubric requires it (α decides per `cnos.core/skills/skill/SKILL.md` rubric)

α's peer enumeration in `self-coherence.md` §ACs should re-enumerate this list against the actual diff at review-readiness time and either name each peer as updated or flag exempt-with-reason.

---

## 6. Pre-flagged failure modes

γ pre-flags the failure shapes most likely to surface in this cycle. β reviews against these; α reads them as authoring constraints. Each is grounded in either #100's own non-goals, the April-26 evidence comment, or known CDD cycle history.

### 6.1 AC5 over-scopes into retrieval-layer features

**Risk.** #100 AC5 + cnos#386 fold-in is a write-protocol surface. α may be tempted to add semantic search, embeddings, vector-store hooks, or contradiction-scan tooling because the April-26 comment explicitly named them as gaps. Those are non-goal #1.

**Pre-flag.** β rejects any code that adds an embedding library, vector store, retrieval index, or knowledge-graph construct. The memory skill may **mention** them as known future-work pointers in a §Known debt or §Future work block; it may not implement them. Document the boundary; do not blur it.

### 6.2 AC2's skill bloat — taxonomy ≠ all-of-memory

**Risk.** AC2's skill body is the natural home for storage taxonomy + write triggers + recall triggers + indexing/restore discipline. α may pull in adjacent material (reflect's evidence→interpretation→conclusion structure, adhoc-thread's type-selection rules) and end up with a 1000-line skill that re-declares neighbors. Non-goal #3.

**Pre-flag.** The memory skill **references** `reflect` and `adhoc-thread` by name and skill-path. It does not re-declare their content. Skill body length should be comparable to siblings under `cnos.core/skills/agent/*` (the largest in the corpus are ~300–500 lines). If α ships >700 lines, β questions the boundary.

### 6.3 MEMORY.md identity conflict

**Risk.** `docs/alpha/agent-runtime/MEMORY.md` v0.2.0 is a design document that explicitly rejects an agent/memory skill (§3, §Alternatives). α may either (a) leave MEMORY.md unchanged and create a conflict with AC2's skill, or (b) rewrite MEMORY.md as the AC7 runbook without preserving the v0.2.0 lineage.

**Pre-flag.** Per §3 AC7 γ recommendation, α rewrites MEMORY.md as the runbook and preserves v0.2.0 design lineage in a §Supersession block. Both surfaces (the new skill AND the new MEMORY.md runbook) must agree on the canonical entrypoint. Either path is acceptable provided AC2 ↔ AC7 are mutually consistent; pre-flag is the *consistency check*, not a path mandate.

### 6.4 Runtime-contract OCaml emitter drift

**Risk.** OCaml record-type changes (`cn_contract.ml`) ripple through every consumer (`cn_runtime_contract.ml`, `cn_system.ml`, `cn_context.ml`, `cn_activation.ml`, plus tests). α may patch the type and only one consumer.

**Pre-flag.** `alpha/SKILL.md §2.4` (Harness audit for schema-bearing changes) is binding here — the cognition record IS a schema-bearing change. Enumerate every producer/consumer of `Cn_contract.cognition` before claiming closure. The pattern is exactly the polyglot re-audit row (#287 lineage). `dune build` + `dune test` is mandatory before review-readiness.

### 6.5 `cn doctor` test fixture drift

**Risk.** `doctor_test.go` currently asserts `cognition: map[string]any{}` as a placeholder (empty). Adding the memory sub-shape requires updating the fixture. α may patch production code without updating tests, or update tests without exercising the new freshness check.

**Pre-flag.** AC6 deliverable includes both the new check and its test. β checks `go test ./src/go/internal/doctor/...` is green AND that the new check has both happy-path (entrypoint present, fresh) and unhappy-path (entrypoint missing, entrypoint stale) coverage.

### 6.6 Path-coordination drift mid-cycle

**Risk.** #101 B14a could in principle merge mid-cycle, which would rename `agent/` → `self/` on `origin/main`. α working on `cycle/100` against `agent/memory/SKILL.md` would have a merge conflict.

**Pre-flag.** Probability is low (B14a is a multi-PR effort per #101 body; #101 mode is `multi-PR (3 cycles)` and is not currently being dispatched). If it does happen, α's `self-coherence.md` §Debt names the path-rename collision and γ coordinates a path-update commit before β merges. Pre-merge gate row 1 (cycle branch rebased onto current `origin/main`) catches this mechanically.

### 6.7 cnos#386 sibling-issue closure ambiguity

**Risk.** #386 stays OPEN as a sibling per operator decision. When cycle/100 lands AC5 with #386's two-part shape, #386's authoritative disposition is ambiguous: closed-as-subsumed? Closed-as-design-input-only? Open for the V-validator portion?

**Pre-flag.** γ post-merge action: write a comment on #386 naming the cycle/100 merge SHA, summarize what AC5 absorbed, and close as `subsumed by #100`. This is a γ-side artifact, not α/β work. Records here as a γ next-action; cycle does not block on it.

---

## 7. Closure gate notes (for γ at close-out time)

These are γ-side reminders for cycle close-out, captured in the scaffold so the close-out triage is well-anchored:

- ε framing (§1) confirmed and to be expanded in `cdd-iteration.md` Step 5.6b. Candidate `cdd-protocol-gap` findings: (a) path-coordination dependency on #101 (§1.1); (b) Σ-side issue-search discipline failure that produced #386 ahead of checking #100 (this is the receipt-stream pattern itself).
- Post-merge γ action: comment + close cnos#386 per §6.7.
- Tier 3 clarification (§1.2) — surface as a candidate `cdd-skill-gap` if it recurs across other cycles (γ-side observation: issue-body Tier 3 lists names a Go skill for an OCaml emitter; this is a content question on the issue-authoring side, possibly a `cdd-protocol-gap` if multiple issues show this pattern).
- ε artifact rule (`COHERENCE-CELL.md` §"ε Artifact Rule"): every receipt records `protocol_gap_count` + `protocol_gap_refs`; if the cycle surfaces any of the above as a real `cdd-*-gap`, `cdd-iteration.md` lands and INDEX.md picks up a row.

---

## 8. Mode rationale (per issue/SKILL.md mode decision)

| Mode candidate | Verdict | Reason |
|---|---|---|
| MCA | Rejected | No stable `DESIGN.md` path; no stable `PLAN.md` path; α will produce both design (skill body, runbook, contract field decisions) and the implementation in this cycle |
| explore | Rejected | The gap is bounded — #100 has 7 numbered ACs and a clear surface set. Investigation is not the cycle's primary work |
| docs-only | Rejected | New OCaml contract field + new Go check + new skill is code, not docs |
| **design-and-build** | **Chosen** | Design (skill body shape, freshness threshold, runbook surface ordering) converges in the issue body + this scaffold; implementation lands in the same cycle. Both halves are sized to fit one triadic cycle per operator's §5.1 multi-session decision |

The cycle scope sizing (7 ACs, typical band per `issue/SKILL.md`) supports `design-and-build` as one cycle. The five-factor split-decision heuristic:

| Factor | Reading | Splitting signal? |
|---|---|---|
| (a) New code surface | 1 new skill file + 1 new contract field; not a new module | No |
| (b) Cross-module breadth | OCaml contract + Go status/doctor + skill body + docs — 4 surfaces, but each is small in this cycle | Borderline; **No** because each surface has a tight diff |
| (c) Lifecycle span | One phase (design + code + docs ship together) | No |
| (d) MCA preconditions | Mis-labelled MCA ruled out above; `design-and-build` is the correct label | N/A |
| (e) Independent shippability of AC groups | AC1+AC6 (contract + projection) could ship without AC2 (skill); AC2 could ship without AC1+AC6. But the *runbook* (AC7) needs the *skill* (AC2) and the *projection* (AC6) to cite real surfaces — they're tightly coupled in practice | Borderline; **No** because splitting introduces release-ordering churn the cycle does not need |

Decision: **keep whole**.

---

## 9. δ external gates needed at scaffold time

- δ pushes nothing on γ's behalf — this scaffold's commit is pushed by γ directly under the worktree-local `gamma@cdd.cnos` identity.
- α and β dispatch is δ's gate (operator/SKILL.md §1 — δ executes `claude -p` for γ → α → β sequentially).
- δ also gates the release (tag + GitHub release + branch cleanup) at cycle close-out per `operator/SKILL.md §3.4`.
- **No external gate required at γ scaffold landing.** γ commits + pushes; α dispatch follows per operator's standard sequence.

---

## 10. Artifact pointers

- **Issue:** https://github.com/usurobor/cnos/issues/100
- **Sibling issue (AC5 design input):** https://github.com/usurobor/cnos/issues/386
- **Path-coordination dependency:** https://github.com/usurobor/cnos/issues/101
- **Kernel doctrine source:** `src/packages/cnos.core/doctrine/KERNEL.md §1.4 Memory`
- **Superseded design context:** `docs/alpha/agent-runtime/MEMORY.md` (v0.2.0)
- **Consolidation analysis source:** `docs/gamma/cdd/ISSUE-CONSOLIDATION-ANALYSIS.md §3 B9b`
- **Contract emitter authority (OCaml):** `src/ocaml/lib/cn_contract.ml` + `src/ocaml/cmd/cn_runtime_contract.ml`
- **`cn status` authority (Go):** `src/go/internal/hubstatus/hubstatus.go`
- **`cn doctor` authority (Go):** `src/go/internal/doctor/doctor.go`
- **α dispatch prompt:** `/root/dispatch-100/alpha-prompt.md`
- **β dispatch prompt:** `/root/dispatch-100/beta-prompt.md`

---

*γ scaffold complete. α may now be dispatched.*
