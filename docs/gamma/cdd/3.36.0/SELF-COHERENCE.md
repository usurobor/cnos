## Self-Coherence Report — v3.36.0 (#174)

**Issue:** #174 — Orchestrator IR runtime: `cn` executes `cn.orchestrator.v1` workflows
**Branch:** claude/174-orchestrator-runtime
**Active skills loaded (and read) before code:** cdd, eng/ocaml, eng/testing

### Alpha (type-level clarity)

| Surface | Change | Type-level judgment |
|---------|--------|--------------------|
| `Cn_workflow.frontmatter`-style types (`trigger`, `permissions`, `step`, `orchestrator`) | new records + variant | Disambiguated fields (`trigger_kind/trigger_name`, `orch_source/orch_package`, etc.); variant tags (`Op_step`, `Llm_step`, `If_step`, `Match_step`, `Return_step`, `Fail_step`) are exhaustive and the compiler catches a new step kind landing without a dispatch arm. |
| `Cn_workflow.issue_kind` | new variant | Six distinct validator categories; compiler forces doctor dispatch (and tests) to handle each case. |
| `Cn_workflow.load_outcome` | new variant (`Loaded` / `Load_error`) | Discovery surfaces failure per-orchestrator without crashing the walk. |
| `Cn_workflow.outcome` | `Completed of Cn_json.t \| Failed of string` | Terminal states are explicit; `execute` never raises on the caller's behalf. |
| Execute step loop | polymorphic variant `` `Terminal \| `Continue \| `Jump `` | Local to `execute_step`; three clean states correspond to the three kinds of control flow (terminate, next-in-order, branch-by-id). |
| `Cn_build.source_decl` | gains `orchestrators : string list` | Parallel to `skills`: a list of declared ids. Directory-tree copy shape. |
| `Cn_runtime_contract.build_orchestrator_registry` | rewritten to consume `Cn_workflow.discover` | One source of truth for "what orchestrators exist" and "what are their trigger kinds". No dueling JSON schemas. |

Name collision with the pre-existing `Cn_orchestrator` (the N-pass LLM bind loop): explicitly documented in `cn_workflow.ml`'s module doc and in this cycle's README. The module is named `Cn_workflow` to keep distance from the existing `Cn_orchestrator`. Two different concerns, two different modules.

**Alpha score: A.** Every record field, every variant tag, every outcome case is consumed somewhere in the test suite. The parser is a pure function returning `(orchestrator, string) result`; exceptions never escape. Execution returns a bounded `outcome`; the stepper is tail-recursive over a polymorphic-variant pipe.

### Beta (authority surface agreement)

Every surface touched and its consumers:

| Surface | Authority | Consumers updated? |
|---------|-----------|--------------------|
| `cn.orchestrator.v1` IR JSON | `Cn_workflow.parse` | `Cn_workflow.discover` (reads), `Cn_workflow.execute` (consumes), `Cn_doctor.report_orchestrators` (validates), `build_orchestrator_registry` (projects to runtime contract). Single pipeline end-to-end. |
| `sources.orchestrators` string array | `Cn_workflow.manifest_orchestrator_ids` + `Cn_build.parse_sources` | Both functions read the same field with the same shape. ORCHESTRATORS.md §9 matches. `cn build` copies per id; discover walks per id. |
| Workflow record types | `cn_workflow.ml` | `cn_runtime_contract.ml` references via `Cn_workflow.installed` / `Loaded` variant. Single module boundary; no duplication. |
| Runtime contract `body.orchestrators` JSON shape | `to_json` in `cn_runtime_contract.ml` | Test in `cn_runtime_contract_test.ml` locks the field names and count. Doctor surface carries its own doctor-style output. |
| Trace / receipt events | `Cn_trace.gemit` via local `trace_event` wrapper | 9 call sites, each with matching label set. Receipts fire on start + complete (success), complete (blocked), and complete (error). No-op in tests without a trace session, full trace in production. |
| `PACKAGE-SYSTEM.md` content class table | `docs/alpha/package-system/PACKAGE-SYSTEM.md` §1.1 | Updated to list orchestrators as the 8th class with source location, declaration shape, and runtime role. |
| `daily-review` orchestrator manifest | `src/agent/orchestrators/daily-review/orchestrator.json` → `packages/cnos.core/orchestrators/daily-review/orchestrator.json` | Both source and built copies present; cnos.core manifest declares `"orchestrators": ["daily-review"]`. |

**Stale reference scan:**
- Zero bare `with _ ->` in any touched module (`cn_workflow.ml`, `cn_runtime_contract.ml`, `cn_doctor.ml`, `cn_build.ml`, `cn_command.ml`). The §2.2 sibling audit caught 5 pre-existing bare catches in `cn_build.ml` — all fixed in this diff with logged context.
- `Cn_workflow` exports — `parse`, `parse_file`, `validate`, `discover`, `doctor_issues`, `execute`, and the type aliases — each has at least one caller in src/ or test/.
- The former inline `[{name, trigger_kinds}]` schema for `sources.orchestrators` (from #173) is fully gone; the three tests that asserted it were replaced with new-schema equivalents that load from `Cn_workflow.discover`.

**Beta score: A.** Every downstream consumer of the touched authorities is updated in the same set of commits. The content-class table in PACKAGE-SYSTEM.md matches the ORCHESTRATORS.md §9 schema matches the parser matches the validator matches the doctor output matches the runtime contract JSON matches the installed `daily-review` manifest.

### Gamma (cycle economics)

**Test counts:**

| File | Tests | Covers |
|------|-------|--------|
| `cn_workflow_test.ml` (new) | 18 | F1–F5 parser, V1–V5 validator, D1–D3 discovery, X1–X5 executor |
| `cn_runtime_contract_test.ml` | 21 (rewrote 3 to match new schema, added 0) | contract shape including orchestrators from discovery |

**Line deltas (approximate):**

| File | Insertions | Deletions |
|------|------------|-----------|
| `src/cmd/cn_workflow.ml` (new) | ~640 | 0 |
| `src/cmd/cn_runtime_contract.ml` | ~20 | ~70 (rewrote build_orchestrator_registry, net shrink) |
| `src/cmd/cn_doctor.ml` | ~20 | ~2 |
| `src/cmd/cn_build.ml` | ~30 | ~10 (orchestrators class + sibling-catch fixes) |
| `src/cmd/dune`, `test/cmd/dune` | ~10 | ~2 |
| `test/cmd/cn_workflow_test.ml` (new) | ~450 | 0 |
| `test/cmd/cn_runtime_contract_test.ml` | ~80 | ~130 (replaced 3 obsolete tests) |
| `docs/alpha/package-system/PACKAGE-SYSTEM.md` | ~15 | 0 |
| `docs/gamma/cdd/3.36.0/` | ~400 | 0 |
| `packages/cnos.core/cn.package.json` | ~3 | 0 |
| `src/agent/orchestrators/daily-review/orchestrator.json` (new) | ~45 | 0 |
| `packages/cnos.core/orchestrators/daily-review/orchestrator.json` (new) | ~45 | 0 |

**§9.1 triggers:**

| Trigger | Fired | Note |
|---------|-------|------|
| Review rounds > 2 | TBD | PR not yet reviewed |
| Mechanical ratio > 20% | TBD | Depends on review findings |
| Avoidable tooling failure | **Yes (soft)** | No OCaml toolchain in the authoring sandbox. Same environment constraint as v3.34.0 and v3.35.0. Text-level review done; CI is the first compilation oracle. |
| Loaded skill failed to prevent a finding | TBD | Baseline: skills were loaded and read before writing (v3.34.0 / v3.35.0 corrective held). |

**Gamma score: A−.**
- Test-first discipline held. Every production function has at least one expect test. The 5 step kinds (op, return, fail, if, llm) are each exercised; the 6th (match) is covered by the validator test V2 for reference integrity but its happy-path execution case is **deferred** as known debt — the `Match_step` branch in `execute_step` is covered by the parser/validator but not by a direct X-series execution test. Worth calling out explicitly rather than quietly counting it covered.
- Sibling audit was performed properly this round: 5 pre-existing bare catches in `cn_build.ml` surfaced and fixed.
- The minus is again the tooling gap (no local OCaml) — same cause as the prior two cycles.

### Triadic Coherence Check

1. **Does every AC have corresponding code?**
   - **AC1** (orchestrators content class): `Cn_build.source_decl.orchestrators` + `parse_sources` + `build_one`/`check_one` loops + `clean_package_dir` list include `orchestrators`. `PACKAGE-SYSTEM.md` §1.1 table entry.
   - **AC2** (`cn.orchestrator.v1` schema validated): `Cn_workflow.parse` + `validate` cover all field parsing and structural checks. Tests F1–F5 + V1–V5.
   - **AC3** (step execution — `op`/`llm`/`if`/`match`/`return`/`fail`): `Cn_workflow.execute_step` has a branch per step kind. **`llm` is a deferred stub**: it's parsed, validated, permission-checked, and then emits a "not yet implemented in this release" failure at runtime. Honest about the deferral; the prompt + context injection mechanism is future design (PLAN §Risk). Five of six step kinds execute; the sixth is a guarded stub.
   - **AC4** (permission manifest enforced before dispatch): `execute_step` checks `List.mem s.op o.permissions.ops` before constructing the typed op. Defence-in-depth with the validator's `Permission_gap` issue.
   - **AC5** (execution trace for replay): `trace_event` wrapper emits `workflow.step.start` and `workflow.step.complete` at each step, with step id, branch target, reason (on failure), and op name. Writes to `Cn_trace` (existing ulog infrastructure). No-op under test when no session is initialised.
   - **AC6** (`cn doctor` validates orchestrator manifests): `Cn_doctor.report_orchestrators` invokes `Cn_workflow.doctor_issues`, which combines load failures + validator issues per installed orchestrator. Doctor exits 1 on any orchestrator issue (fail-stop).
   - **AC7** (real orchestrator shipped): `src/agent/orchestrators/daily-review/orchestrator.json` + built copy in `packages/cnos.core/orchestrators/daily-review/` + `"orchestrators": ["daily-review"]` in the cnos.core manifest. The orchestrator JSON **parses and validates** (AC6 covers this); it would **fail at runtime** today because step 2 is the `llm` stub. This is the honest state of AC7 under the AC3 deferral: shipped as code/data + schema-clean, not end-to-end runnable.

2. **Is the dueling-schema problem resolved?** Yes. The #173 `build_orchestrator_registry` read `sources.orchestrators` as an array of inline objects `[{name, trigger_kinds}]`. That's inconsistent with ORCHESTRATORS.md §9 which specifies `sources.orchestrators` as an array of id strings. This PR rewrites `build_orchestrator_registry` to consume `Cn_workflow.discover`, which reads the id-array shape and loads the per-orchestrator JSON. The three #173 tests that asserted the inline schema are replaced with ones that match the spec. One schema, one reader, one set of tests.

3. **Is the name collision with `Cn_orchestrator` benign?** Yes. `Cn_orchestrator` is the pre-existing N-pass LLM bind-loop orchestrator. `Cn_workflow` is the mechanical workflow engine. The domain concerns are different (LLM response resolution vs declarative step graph execution). The naming clarifies the difference. The CDD README and the `cn_workflow.ml` module docstring both call this out.

4. **Is the `llm` stub honest about its deferral?** Yes. The step kind is parsed (`Llm_step` variant exists). The validator flags `Llm_without_permission` when `permissions.llm=false`. The executor enters the Llm_step branch and produces `Failed "llm step not yet implemented in this release"` with a matching trace event. Test X5 locks that behaviour. AC3 is met for five of six step kinds; AC7's daily-review orchestrator parses and doctor-validates cleanly but its step 2 would terminate the run on execution. Next cycle closes the gap.

5. **Do the runtime extensions and the N-pass orchestrator remain untouched?** Yes. No edits to `cn_extension.ml`, `cn_ext_host.ml`, or `cn_orchestrator.ml`. grep confirms.

### Pointers

| What | Where |
|------|-------|
| Issue | https://github.com/usurobor/cnos/issues/174 |
| Handoff | Comment on #174 |
| Design | `docs/alpha/agent-runtime/ORCHESTRATORS.md` §7–8 |
| Plan | `docs/alpha/agent-runtime/PLAN-174-orchestrator-runtime.md` |
| Bootstrap | `docs/gamma/cdd/3.36.0/README.md` |
| Module | `src/cmd/cn_workflow.ml` |
| Runtime contract wiring | `src/cmd/cn_runtime_contract.ml::build_orchestrator_registry` |
| Doctor wiring | `src/cmd/cn_doctor.ml::report_orchestrators` |
| Build wiring | `src/cmd/cn_build.ml::{source_decl, parse_sources, build_one, check_one, clean_package_dir}` |
| Tests | `test/cmd/cn_workflow_test.ml`, `test/cmd/cn_runtime_contract_test.ml` |
| Shipped orchestrator | `src/agent/orchestrators/daily-review/orchestrator.json` |
| Content class docs | `docs/alpha/package-system/PACKAGE-SYSTEM.md` §1.1 |

### Exit Criteria

- [x] AC1: orchestrators content class in build + schema + docs
- [x] AC2: cn.orchestrator.v1 schema parsed and validated
- [x] AC3: op/return/fail/if/match executable; llm deferred with honest stub
- [x] AC4: permission manifest enforced before dispatch
- [x] AC5: trace events emitted via Cn_trace.gemit
- [x] AC6: cn doctor surfaces load failures + validator issues
- [x] AC7: daily-review orchestrator shipped, parses + validates; full execution deferred with AC3
- [x] Zero bare `with _ ->` in touched files; §2.2 sibling audit completed on `cn_build.ml`
- [x] Test-first discipline held
- [x] `scripts/check-version-consistency.sh` passes
- [ ] `dune build && dune runtest` — deferred to CI
- [ ] PR review round 1 — pending
- [ ] CI green on branch — pending
