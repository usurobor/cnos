## CDD Bootstrap — v3.36.0 (#174)

**Issue:** #174 — Orchestrator IR runtime: `cn` executes `cn.orchestrator.v1` workflows
**Parent:** #170 (orchestrator + command provider model)
**Branch:** claude/174-orchestrator-runtime
**Design:** `docs/alpha/agent-runtime/ORCHESTRATORS.md` §7–8 (627 lines)
**Plan:** `docs/alpha/agent-runtime/PLAN-174-orchestrator-runtime.md` (committed at 29eeb29)
**Mode:** MCA
**Level:** L7 — new execution surface, new content class, new runtime capability
**Active skills loaded (and read) before code:** cdd, eng/ocaml, eng/testing

### Gap

cnos has no execution engine for mechanical workflows. The runtime contract (#173) exposes an orchestrator registry, but nothing can load, validate, or execute the `cn.orchestrator.v1` IR. CDD pipeline, daily review, weekly reflection — all are prose instructions the agent interprets, not deterministic workflows the runtime executes.

### What fails if skipped

Mechanical workflows stay as prose. Every new deterministic procedure is another point where the agent needs to infer control flow from text instead of executing a compiled step graph. The determinism rule (control flow deterministic, non-determinism at `llm`/`op` boundaries only) cannot be enforced structurally without a runtime that actually executes steps.

### Acceptance Criteria

- **AC1** `orchestrators/` is a recognised package content class in the manifest schema and `cn build`
- **AC2** `cn.orchestrator.v1` JSON schema defined and validated by the runtime
- **AC3** Step execution: `op` dispatches to typed ops, `llm` calls the agent, `if`/`match` branches
- **AC4** Permission manifest enforced — if an op is not in `permissions.ops`, execution fails before dispatch
- **AC5** Execution trace (receipts) written for deterministic replay of control flow
- **AC6** `cn doctor` validates orchestrator manifests (missing steps, invalid refs, permission gaps)
- **AC7** At least one real orchestrator shipped (daily-review)

### Scope and deferrals (honest)

The handoff staging maps Stage A → AC1/2/6, Stage B → AC3/4/5, Stage C → AC7. Three deferrals this cycle, all explicit:

1. **`parallel` step kind** — deferred to v2 per plan §"Deferred to v2". cnos has no async model.
2. **`llm` step execution** — the plan §"Risk" flags: "Requires calling the agent from within an orchestrator. The mechanism for this (prompt + context injection) needs design during Stage B. May simplify to 'call cn with a prompt template' initially." This cycle parses and validates `llm` steps (AC2 satisfied) and the executor emits a "not yet implemented in v3.36.0" error at runtime when it hits one. That is honest and covered by a test. The daily-review orchestrator JSON is shipped (AC7) including its `llm` step; `cn doctor` validates it. End-to-end execution of daily-review is therefore **not** part of AC7 in this cycle. **AC3 is met for `op`/`if`/`match`/`return`/`fail`** — five of six step kinds — and **not met for `llm`**. The next cycle closes the `llm` gap once the prompt-injection mechanism is designed.
3. **`match` semantics** — v1 treats `match` as "exact equality on a bound scalar value against case patterns" (no structural patterns). Documented in the validator + renderer comments.

### Plan (stage index)

| Stage | ACs | Work | Commit |
|-------|-----|------|--------|
| A | AC1, AC2, AC6 | Content class in `cn_build`; IR types, parser, validator in new `cn_workflow.ml`; doctor validation wired into `cn_doctor.ml` | TBD |
| B | AC3, AC4, AC5 | Execution engine: op dispatch via `Cn_executor.execute_op`, `if`/`match`/`return`/`fail` flow control, binding environment, permission enforcement before dispatch, receipts via `Cn_trace.gemit` | TBD |
| C | AC7 | `src/agent/orchestrators/daily-review/orchestrator.json`; `packages/cnos.core/cn.package.json` declares it; `cn build` copies it | TBD |

Each stage gets: tests first → implementation → `dune build` gate → commit. Full plan in `docs/alpha/agent-runtime/PLAN-174-orchestrator-runtime.md`.

Naming note: the new module is `Cn_workflow`, not `Cn_orchestrator`. `Cn_orchestrator` already exists as the N-pass LLM bind-loop orchestrator — an unrelated runtime concern. Two different modules, documented in both `src/cmd/cn_workflow.ml`'s docstring and the self-coherence.

### Impact Graph

**New files:**
- `src/cmd/cn_workflow.ml` (types, parser, validator, discovery, executor)
- `test/cmd/cn_workflow_test.ml`
- `src/agent/orchestrators/daily-review/orchestrator.json` + mirrored into `packages/cnos.core/orchestrators/daily-review/`
- `docs/gamma/cdd/3.36.0/` (this dir)

**Touched modules:**
- `src/cmd/cn_build.ml` — add `orchestrators` to `source_decl`, copy logic, summary count, clean list; plus sibling audit (5 pre-existing bare catches cleaned)
- `src/cmd/cn_doctor.ml` — add `report_orchestrators` using `Cn_workflow.doctor_issues`
- `src/cmd/cn_runtime_contract.ml` — rewrite `build_orchestrator_registry` to consume `Cn_workflow.discover`, resolving the #173 dueling-schema problem; three obsolete orchestrator tests replaced in `test/cmd/cn_runtime_contract_test.ml`
- `src/cmd/dune` — register `cn_workflow`
- `test/cmd/dune` — register `cn_workflow_test`

**Touched docs:**
- `docs/alpha/package-system/PACKAGE-SYSTEM.md` — `orchestrators` as 8th content class

**Touched manifests:**
- `packages/cnos.core/cn.package.json` — declare `sources.orchestrators: ["daily-review"]`

**Untouched (verified by grep):**
- `cn_deps.ml`, `cn_command.ml`, `cn_activation.ml`, `cn_ext_host.ml`, `cn_extension.ml`, `cn_orchestrator.ml` — unrelated to the workflow surface
- `cn_executor.ml` — **reused** via `execute_op`, not modified. The orchestrator is a caller, not an extension of the executor.

### CDD Trace (filled during execution)

| Step | Artifact | Skills loaded | Decision |
|------|----------|---------------|----------|
| 0 Observe | #174, PLAN-174, ORCHESTRATORS.md §7–8 | cdd | No execution engine for mechanical workflows; plan already committed |
| 1 Select | #174 | cdd | L7, depends on #173 (shipped v3.35.0) |
| 2 Branch | claude/174-orchestrator-runtime | — | created from `main` at 29eeb29 |
| 3 Bootstrap | `docs/gamma/cdd/3.36.0/` | — | README + (link to) PLAN + SELF-COHERENCE later + GATE later |
| 4 Gap | this file §Gap | cdd | No runtime for cn.orchestrator.v1 |
| 5 Mode | this file | cdd, eng/ocaml, eng/testing | MCA, L7, work shape "new execution surface"; active skills **loaded and read before writing** |
| 6 Artifacts | tests → code → docs → self-coherence | cdd, eng/ocaml, eng/testing | Filled during Stages A/B/C |
| 7 Self-coherence | `SELF-COHERENCE.md` | cdd | Written after C |
| 8 Review | PR body | cdd/review | After gate |
| 9 Gate | `GATE.md` | cdd/release | Set after self-coherence |
| 10 Release | — | — | Next release train |
