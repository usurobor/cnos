# RELEASE.md

## Outcome

Coherence delta: C_Σ A (`α A`, `β A`, `γ A-`) · **Level:** `L7`

cnos gains a mechanical workflow execution engine. The `cn.orchestrator.v1` IR — defined in ORCHESTRATORS.md §7–8 — is now parsed, validated, discovered, and executed by a dedicated runtime (`Cn_workflow`). Deterministic control flow (`if`/`match`/`return`/`fail`) and typed `op` dispatch are live; `llm` step execution is an honest guarded stub deferred to the next cycle. The orchestrator registry, previously a dueling inline-object schema from #173, is unified through `Cn_workflow.discover`.

## Why it matters

Mechanical workflows (CDD pipeline, daily review, weekly reflection) were prose instructions the agent interpreted — no structural guarantee of determinism, permission enforcement, or replay. This release makes `orchestrators/` the 8th package content class and provides the runtime to load and execute them. The determinism rule (control flow deterministic, non-determinism only at `llm`/`op` boundaries) is now structurally enforced, not just documented.

## Added

- **Orchestrator IR runtime** (#174): `Cn_workflow` module — IR types, parser, structural validator, package discovery, step-by-step executor with binding environment. 641 lines of new runtime code.
- **6 step kinds**: `op` (dispatches to typed ops via `Cn_executor.execute_op`), `llm` (guarded stub), `if`/`match` (deterministic branching on bound scalars), `return`/`fail` (terminal outcomes).
- **Permission enforcement**: defence-in-depth — validator flags `Permission_gap` / `Llm_without_permission`; executor checks before dispatch.
- **Execution trace**: `workflow.step.start` + `workflow.step.complete` events via `Cn_trace.gemit` at every step boundary, with step id, branch target, and reason on failure.
- **`orchestrators/` content class**: 8th content class in `cn_build` — source_decl, parse_sources, build/check/clean all extended. PACKAGE-SYSTEM.md §1.1 updated.
- **`cn doctor` orchestrator validation**: `report_orchestrators` surfaces load failures + validator issues per installed orchestrator. Fail-stop on any issue.
- **`daily-review` orchestrator**: first shipped orchestrator in `cnos.core`. Parses and validates cleanly; end-to-end execution deferred until `llm` step is wired.
- **21 new expect-tests** in `cn_workflow_test.ml`: parser (F1–F5), validator (V1–V5), discovery (D1–D3), executor (X1–X8).

## Changed

- **`build_orchestrator_registry` rewritten** (#174): now consumes `Cn_workflow.discover` instead of reading inline `[{name, trigger_kinds}]` objects from manifests. Eliminates the #173 dueling-schema — single reader, single schema.
- **`cn_runtime_contract_test.ml`**: 3 obsolete orchestrator tests replaced with new-schema equivalents.
- **`cn_build.ml`**: 5 pre-existing bare `with _ ->` catches replaced with logged `with exn ->` handlers (sibling audit).

## Validation

- CI green on merge commit (e1fe3f8): OCaml build + 42 expect-tests + package/source drift + protocol traceability.
- Deployed to [target], validated with `cn --version` + `cn deps restore` + `cn doctor`.

## Known Issues

- `llm` step execution deferred — parsed, validated, permission-checked, but emits "not yet implemented" at runtime. Next cycle's headline work.
- `parallel` step kind deferred — cnos has no async model.
- `match` step semantics are v1: exact equality on bound scalars only, no structural patterns.
