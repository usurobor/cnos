# cnos Changelog

## Release Coherence Ledger

Each release is scored on two dimensions: **coherence quality** (TSC grades) and **architectural scope** (engineering level).

**TSC grades** use the [TSC](https://github.com/usurobor/tsc) triadic axes, applied as intuition-level letter grades (A+ to F) per the [CLP self-check](https://github.com/usurobor/tsc-practice/tree/main/clp):

- **C_Σ** — Aggregate coherence: `(s_α · s_β · s_γ)^(1/3)`. Do the three axes describe the same system?
- **α (PATTERN)** — Structural consistency and internal logic. Does repeated sampling yield stable structure?
- **β (RELATION)** — Alignment between pattern, relations, and process. Do the parts fit together?
- **γ (EXIT/PROCESS)** — Evolution stability and procedural explicitness. Does the system change consistently?

These are intuition-level ratings, not outputs from a running TSC engine (formal C_Σ ranges 0–1; ≥0.80 = PASS).

**Engineering level** per [ENGINEERING-LEVELS.md](docs/gamma/ENGINEERING-LEVELS.md), capped by CDD §9.1 cycle execution quality:

- **L4** — Pre-architecture: working prototype, no stable boundaries yet
- **L5** — Local correctness: fix works, follows patterns, no boundary change
- **L6** — System-safe: cross-surface coherence, failure modes handled
- **L7** — System-shaping: architecture boundary moved, class of future work eliminated

See [RELEASE-LEVEL-CLASSIFICATION.md](docs/gamma/essays/RELEASE-LEVEL-CLASSIFICATION.md) for the full historical analysis.

| Version | C_Σ | α | β | γ | Level | Coherence note |
|---------|-----|---|---|---|-------|----------------|
| 3.26.1 | A | A | A | A | L5 | Docs: OPERATOR.md (day-2 operations manual), post-release assessment v3.26.0, CLI/troubleshooting updated for cn logs, hub name sanitization across 19 files (strip deployment-specific agent names from public docs). |
| 3.26.0 | A- | A | A- | B+ | L7 | Unified log stream + cn logs CLI (#74 Phase 1): `cn_ulog.ml` append-only JSONL writer (schema cn.ulog.v1, 5 event kinds), `cn_logs.ml` CLI with --since/--msg/--errors/--json/--kind filters, correlation via msg_id across all entries. Runtime emits at 9 points (message lifecycle + silent drops + poll errors). Chunk-accumulation read path preserves chronological order across day boundaries. 21 tests (13 ulog + 8 logs). 6 review rounds across 2 reviewers — multi-day ordering bug (independent) and silent message drops (Σ) both found and fixed. §2.2.1a extended: new data surfaces require write AND read path verification. |
| 3.25.0 | A | A | A | A- | L7 | Structural self-knowledge interception (#64): `Contract_redirect` as first-class receipt status, `check_self_knowledge_path` interceptor in executor (after sandbox, before I/O), membrane covers all 5 observe surfaces — fs_read (redirect), fs_list child filtering, fs_glob result filtering, git_grep/git_observe exclusions. RC authority declaration references structural enforcement. 10 expect tests. 2 review rounds, 3 D-level membrane holes found R1 (fs_list children, fs_glob, git_grep), all closed R2. Last P0 (#64) closed. |
| 3.24.0 | A | A | A | A- | L7 | Template distribution via package system (#119): templates as 6th content class in package system, `read_template` with Result-typed 3-case resolution (Ok/not-installed/not-found), `run_init` reads from installed cnos.core after `setup_assets`, `run_setup` populates missing spec/ from templates without overwriting operator content. PACKAGE-SYSTEM.md architecture doc (content class taxonomy, pipeline, explicit-vs-generic rationale). 11 new tests (7 build + 4 e2e regression). Unicode hygiene added to review skill/checklist. 1 review round, 1 mechanical finding (stale cross-ref). All 5 ACs met. |
| 3.23.0 | A- | A- | A- | A | L7 | Pre-push gate (#117): `scripts/pre-push.sh` runs dune build, dune runtest, cn build --check, VERSION parity against origin/main. CDD §9.1 cycle iteration with structured template, triggers, cycle level (L5/L6/L7), closure gate, skill patching as immediate output. ENGINEERING-LEVELS.md cross-referenced. #64 P0 closed (all 3 root causes verified). SOUL §2.2 MCA-first on error correction. CDD §4.4 "load means read the file." ORIGIN.md genesis narrative. Squash merge enabled. |
| v3.22.0 | A- | A- | A | A- | L6 | Daemon version-drift detection (#110): `version_drift_check_once` as 8th maintenance primitive, `check_binary_version_drift` detects external binary replacement via `--version` comparison, triggers `re_exec` with shared `is_idle` drain guard. 1 review round, 0% mechanical ratio. All 4 #110 ACs met. |
| v3.20.0 | B+ | A- | A- | B | L6 | Runtime Extensions e2e (#73): host command resolution maps bare manifest names to installed paths, returns Result with existence/permission/traversal validation. Extension dispatch pipeline validated end-to-end with real cnos.net.http host binary. 3 review rounds, 0% mechanical ratio. All 7 #73 ACs met. MCI freeze lifted (8 releases). |
| v3.19.0 | A- | A | A- | B+ | L5 | Package System Substrate AC5-AC7 (#113): integrity hash (md5 tree hash) in lock generation + restore verification, doctor validates full desired→resolved→installed chain (metadata, integrity, stale installs), Runtime Contract package truth expanded with source/rev/integrity. 1 review round, 33% mechanical ratio. #113 AC3-AC7 shipped across v3.18.0+v3.19.0. |
| v3.18.0 | B+ | A- | B+ | B- | L5 | Package System Substrate AC3+AC4 (#113): path-consistent restore (copy_tree replaces 5-category hardcoded list), honest third-party rejection (lockfile_for_manifest returns Result), stale cnos.pm cleanup, package manifests synced with skill reorg. 3 review rounds, 57% mechanical ratio, 1 superseded PR. Partial: AC5-AC8 deferred. |
| v3.17.0 | B+ | A | B+ | C+ | L5 | Runtime Extensions Phase 1 (#73): open op registry replaces closed built-in vocabulary, subprocess host protocol, manifest-driven discovery, extension lifecycle (discovered→compatible→enabled/disabled/rejected), Runtime Contract integration (cognition + body), traceability (extension.* events), doctor health checks, first reference extension cnos.net.http. 5 review rounds, 53% mechanical ratio. Partial: build integration, policy intersection, host binary (Phase 2). TSC corrected by post-release assessment. |
| v3.16.2 | A | A | A | A- | L6 | Two-membrane projection integrity (#106): presentation membrane hardened (shared xml_prefixes, block-level + inline stripping, matched-tag close), self-knowledge membrane (anti-probe in Runtime Contract). 5 review rounds, 12 D-level findings resolved. Configuration mode spec + templates shipped. Review skill converged (§2.1.3 mechanical scan, §2.2.1a input enumeration). |
| v3.16.1 | A | A | A | A | L6 | Daemon retry limit + dead-letter (#28): 4xx fail-fast, exponential backoff (1s/2s/4s), offset advancement after dead-letter. Sustainability surface added. |
| v3.16.0 | A | A | A | A- | L5 | End-to-end self-update (#37): same-version patch detection, ARM release matrix, bare version tag trigger, target_commitish SHA validation. CDD OVERVIEW.md. AGILE-PROCESS.md deleted. 3 review rounds (target ≤2), 63% mechanical ratio — no build step before review. |
| v3.15.2 | A | A | A | A | L6 | Empty Telegram filter (#29), CDD v3.15.0 canonical rewrite (authority split resolved), review skill hardened (4 new checks from PR #103 comparison). |
| v3.15.1 | A | A | A | A- | L6 | Fix #22 review blockers: re-exec after binary update (no stale in-process version), stamp-versions.sh derives manifests from VERSION, cn build --check + cn release gate version consistency, unified truth read in update_runtime. Process: reviewed before merge, CI green. |
| v3.15.0 | A- | A | A- | B+ | L5 | Version coherence (#22): VERSION→dune→cn_version.ml chain is sound (α A). β regressed: I1 CI check failed at merge, claim/reality gap on AC3+AC10. γ regressed: 0 review rounds (self-merged ~26min), merged with red CI, 3 fix commits post-implementation — first release after §11.11 review metrics bypassed review entirely. Manifests not yet stamped from VERSION (validate-only, not derive). Update path uses stale in-process version. Core architecture correct; contract partially closed. |
| v3.14.7 | A | A | A | A | L7 | Reduce review round-trips (#97): branch pre-flight validation (§1.5), scope enumeration (§4.0), review quality metrics (§11.11), process debt integration (§11.12), encoding lag type column (§11.6), cross-ref validation in review skill (§2.2.5), finding taxonomy (§5.1). Post-release template updated with review quality section. |
| v3.14.6 | A | A | A | A | L7 | Retroactive epoch assessments (#85): v3.12.0–v3.12.2 and v3.13.0–v3.14.5. CDD §9.11 release gate: previous release must have assessment before tagging. |
| v3.14.5 | A | A | A | A | L5 | Organize gamma docs (#91): 6 gamma root files moved into 3 bundles (cdd, rules, essays). Bundle READMEs, frozen snapshots, 13+ cross-refs updated. Completes docs reorg trilogy: alpha→beta→gamma. |
| v3.14.4 | A | A | A | A | L5 | Organize beta docs (#89): 7 beta root files moved into 4 thematic bundles (architecture, governance, lineage, schema). Bundle READMEs, frozen snapshots, cross-refs updated. CDD §5.1 freeze semantics note. |
| v3.14.3 | A | A | A | A | L5 | Organize alpha docs (#86): all 18 root-level specs moved into 8 thematic bundles (doctrine, protocol, agent-runtime, runtime-extensions, cognitive-substrate, cli, security, ctb). Bundle READMEs created. Cross-references updated across 20+ files. Freeze policy updated: path-only corrections allowed. |
| v3.14.2 | A | A | A | A | L5 | Alpha bundle migration (#81): legacy design docs and plans moved into CDD bundle structure. Version snapshot dirs with manifests. Navigation surfaces updated. |
| v3.14.1 | A | A | A | A | L6 | CDD post-release tightening (#78): encoding lag table mandatory, concrete next-MCA commitment, MCI freeze triggers. First operator troubleshooting guide. LINEAGE.md taxonomy cleanup. |
| v3.14.0 | A | A | A- | A | L7 | Runtime Contract v2 (#62): vertical self-model (identity, cognition, body, medium). Zone classification for all paths. All architecture docs updated. Doctor structural validation. |
| v3.13.0 | A- | A- | A- | A- | L7 | Docs governance (#75): CDD pipeline with per-step artifacts, self-coherence report format, single cnos version lineage, feature bundles, frozen snapshots, bootstrap-first rule. CDD skill synced. |
| v3.12.1 | A+ | A+ | A+ | A+ | L6 | Daemon boot log declares config sources (#61): version, hub, profile, model, secrets provenance, peers. Type-safe secret_source. |
| v3.12.0 | A+ | A+ | A+ | A+ | L7 | Wake-up self-model contract (#56): Runtime Contract replaces overloaded capabilities block. CDD/review skill hardening (#57): issue AC gates, multi-format parity. |
| v3.11.0 | A+ | A+ | A+ | A | L6 | N-pass merge + misplaced ops correction (#51). Structured output reverted (needs rework). |
| v3.10.0 | A+ | A+ | A+ | A+ | L7 | N-pass bind loop (#50): effect pass no longer terminal, generic pass architecture, processing indicators. |
| v3.9.3 | A+ | A+ | A+ | A+ | L6 | Anti-confabulation (#49): explicit op result signals, denial reason surfacing, doctrine. |
| v3.9.2 | A+ | A+ | A+ | A+ | L6 | Block Pass A projection when Pass B fails (#47). CURIOSITY mindset. MIC/MICA/CDD verbs in glossary. |
| v3.9.1 | A+ | A+ | A+ | A+ | L5 | Fix Cn_shell.execute never called (#46), sync DUR skills to packages, add git_stage to protocol contract. |
| v3.9.0 | A+ | A+ | A+ | A+ | L7 | Two-pass wiring (#41), COGNITIVE-SUBSTRATE spec, DUR skill contract, reflect + adhoc-thread + review skills cohered. |
| v3.8.0 | A+ | A+ | A+ | A+ | L6 | Syscall surface coherence: fs_glob, git_stage, fs_read chunking, observe exclusion symmetry, CLI injection hardening. Review-driven. |
| v3.7.3 | A | A+ | A+ | A | L6 | Agent output discipline: ops-in-body detection, peer awareness, coordination op examples, conditional MCA review. |
| v3.7.2 | A | A+ | A+ | A- | L6 | Trace gap closure + boot drain fix + skill hardening. 5/7 trace gaps closed; peer-only heartbeat and outbox structure remain. |
| v3.7.0 | A | A+ | A+ | A- | L7 | Scheduler unification: one loop, two schedulers (oneshot/daemon), 7-primitive maintenance engine. Boot drain gap found post-merge. |
| v3.6.0 | A+ | A+ | A+ | A+ | L7 | Output Plane Separation: sink-safe rendering, typed op output, two-pass execution, CDD skill. |
| v3.5.1 | A+ | A+ | A+ | A+ | L7 | TRACEABILITY: structured event stream, state projections (ready/runtime/coherence), boot sequence telemetry, CDD design doc. |
| v3.5.0 | A+ | A+ | A+ | A+ | L7 | Unified package model + CAA + FOUNDATIONS. Everything cognitive is a package. Doctrinal capstone. Architecture spec. |
| v3.4.0 | A+ | A+ | A+ | A+ | L7 | CAR: three-layer cognitive asset resolver + package system. Fresh hubs wake with full substrate. Git-native deps, lockfile, hub-local overrides. |
| v3.3.1 | A+ | A+ | A+ | A+ | L6 | Agent instruction alignment: canonical ops examples in capabilities block, stale path fixes, output discipline. Prevents hallucinated tool syntaxes. |
| v3.3.0 | A+ | A+ | A+ | A+ | L7 | CN Shell: typed ops, two-pass execution, path sandbox, crash recovery. Pure-pipe preserved — ops are post-call, governed, receipted. Zero new runtime deps. |
| v3.2.0 | A+ | A+ | A+ | A+ | L7 | Structured LLM schema: system blocks with cache control + real multi-turn messages. Mindsets in context packer. Role-weighted skill scoring. Setup installer design. |
| v3.0.0 | A+ | A+ | A+ | A+ | L7 | Native agent runtime. OpenClaw removed. Pure-pipe: LLM = `string → string`, cn = all effects. Zero runtime deps. |
| v2.4.0 | A+ | A+ | A+ | A+ | L7 | Typed FSM protocol. All 4 state machines (sender, receiver, thread, actor) enforced at compile time. |
| v2.3.x | A+ | A+ | A+ | A | L7 | Native OCaml binary, 10-module refactor. No more Node.js dependency. |
| v2.2.0 | A+ | A+ | A+ | A+ | L7 | First hash consensus. Actor model complete: 5-min cron, input/output protocol, bidirectional messaging, verified sync. |
| v2.1.x | A+ | A+ | A+ | A | L6 | Actor model iterations: cn sync/process/queue, auto-commit, wake mechanism fixes. |
| v2.0.0 | A+ | A+ | A+ | A+ | L7 | Everything through cn. CLI v0.1, UX-CLI spec, SYSTEM.md, cn_actions library. Paradigm shift: agent purity enforced. |
| v1.8.0 | A+ | A+ | A | A+ | L7 | Agent purity (agent=brain, cn=body). CN Protocol, skills/eng/, ship/audit/adhoc-thread skills, AGILE-PROCESS, THREADS-UNIFIED. |
| v1.7.0 | A | A | A | A | L7 | Actor model + inbox tool. GTD triage, RCA process, docs/design/ reorg. Erlang-inspired: your repo = your mailbox. |
| v1.6.0 | A− | A− | A− | A− | L7 | Agent coordination: threads/, peer, peer-sync, HANDSHAKE.md, CA loops. First git-CN handshake. |
| v1.5.0 | B+ | A− | A− | B+ | L6 | Robust CLI: rerunnable setup, safe attach, better preflights. |
| v1.4.0 | B+ | A− | A− | B+ | L6 | Repo-quality hardening (CLI tests, input safety, docs aligned). |
| v1.3.2 | B+ | A− | B+ | B+ | L5 | CLI preflights git+gh; same hub/symlink design. |
| v1.3.1 | B+ | A− | B+ | B+ | L5 | Internal tweaks between tags. |
| v1.3.0 | B+ | A− | B+ | B+ | L6 | CLI creates hub + symlinks; self-cohere wires. |
| v1.2.1 | B+ | A− | B+ | B+ | L5 | CLI cue + onboarding tweaks. |
| v1.2.0 | B+ | A− | B+ | B+ | L5 | Audit + restructure; mindsets as dimensions. |
| v1.1.0 | B | B+ | B | B | L5 | Template layout; git-CN naming; CLI added. |
| v1.0.0 | B− | B− | C+ | B− | L5 | First public template; git-CN hub + self-cohere. |
| v0.1.0 | C− | C | C− | D+ | L4 | Moltbook-coupled prototype with SQLite. |

---

## v3.15.2 (2026-03-25)

**Empty Telegram filter (#29), CDD canonical rewrite, review skill hardening**

Three concerns addressed in one release: a runtime bugfix, the CDD authority split, and review skill improvements.

### Fixed

- **Empty Telegram messages filtered before enqueuing (#29)** — photos, stickers, edits have `text=""` and caused Claude API 400 → infinite retry loop (#28). `drain_tg` now checks `String.trim msg.text = ""`, advances offset, emits trace event (`reason_code: empty_content`). Mirrors existing `rejected_user` pattern.

### Changed

- **CDD.md rewritten as canonical algorithm spec (v3.15.0)** — absorbs §0 selection, 14-step lifecycle, cycle-close, operational debt override, and all sections previously carried only by the skill. 12 sections: purpose, scope, inputs, selection function, lifecycle, artifact contract, mechanical/judgment boundary, review, gate, assessment, closure, related docs.
- **CDD SKILL.md rewritten as executable summary** — clean DUR structure, canonical doc governs on disagreement, no authority exception blocks. Delegates to sub-skills.
- **RATIONALE.md created** — companion document: why CDD is closed-loop, artifact-driven, and not fully mechanical. Absorbs the "why" that doesn't belong in spec or skill.
- **README.md rewritten** — self-describing topic bundle with reading order and document map.
- **AGILE-PROCESS.md demoted to reference profile** — explicitly one valid implementation of CDD, not the method itself.
- **Review skill §2.0.5** — CDD artifact contract check: verify required CDD artifacts exist for the change class.
- **Review skill §2.2.8** — authority-surface conflict: when multiple surfaces define the same thing, verify they agree.
- **Review skill §2.3.6** — evidence depth: match evidence depth to claim strength (predicate ≠ integration).
- **Review skill §3.7** — CI/release-gate state: don't issue merge instruction when required checks haven't run.

### Process

- **CDD §0 selection** — #29 selected via §0.6 operational infrastructure debt override.
- **PR #103** — authored by usurobor via Claude Code session, reviewed by Sigma. Reset+cherry-pick after history rewrite (Test→usurobor authorship fix via git filter-repo).
- **Git authorship fixed** — all historical `Test <test@test.local>` commits rewritten to `usurobor <usurobor@gmail.com>` via git filter-repo. Force-pushed.

---

## v3.16.0 (2026-03-25)

**End-to-end self-update (#37), CDD OVERVIEW, AGILE-PROCESS deletion**

### Fixed

- **`cn update` end-to-end self-update (#37)** — three independent failures fixed:
  1. Same-version patch detection via commit hash comparison (`Update_patch` variant, `release_info` record, `get_latest_release()` with `Cn_json` parsing)
  2. ARM binary in CI release matrix (`ubuntu-24.04-arm` → `cn-linux-arm64`)
  3. Release workflow triggers on bare version tags (`[0-9]*.[0-9]*.[0-9]*`) in addition to `v*`
  4. `target_commitish` validated as hex SHA before patch comparison — branch names like "main" no longer cause false `Update_patch`
- **`cn --version` shows commit hash** — `cn 3.16.0 (abc1234)` for operator diagnostics
- **Cram tests use prefix match** — `version.t` and `cli.t` handle dynamic commit suffix

### Added

- **CDD OVERVIEW.md** — plain-language introduction: what CDD is, why it exists when agents can write code, what one cycle looks like, what stays mechanical vs judgment-bearing
- **CDD §12 retro-packaging rule** — substantial direct-to-main changes must be followed by retro-snapshot + self-coherence + version-history entry
- **Post-release §5 closure evidence** — template now requires explicit immediate/deferred output accounting

### Changed

- **AGILE-PROCESS.md deleted** — CDD §4.1 lifecycle table supersedes the workflow states. P0–P3 priority bands implied by §3 selection function. One less surface to maintain.
- **CDD bundle reading order** — OVERVIEW → CDD → RATIONALE → epoch assessments
- **Review skill output format** — now includes CI state, merge instruction, and finding type column (closes self-contradiction where rules required them but template omitted them)
- **Release skill §2.3** — VERSION-first flow: `echo X.Y.Z > VERSION` → `stamp-versions.sh` → `check-version-consistency.sh`. Old manual locations removed.
- **Live AGILE-PROCESS refs updated** — ARCHITECTURE.md diagram, AUDIT.md inventory

### Process

- **PR #104** — 4 review rounds (3 D-level blockers found and fixed: syntax error, FSM exhaustive match, bare tag trigger, `target_commitish` validation, `cli.t` prefix match). Authored by usurobor via Claude Code, reviewed by Sigma.
- **Git authorship fixed** — all historical `Test <test@test.local>` commits rewritten to `usurobor <usurobor@gmail.com>` via git filter-repo.
- **CDD retro-packaged** — frozen CDD snapshot in `3.15.2/`, self-coherence report for the canonical rewrite.

---

## v3.16.1 (2026-03-25)

**Daemon retry limit and dead-letter (#28)**

### Fixed

- **Daemon retry limit and dead-letter (#28)** — `drain_tg` no longer retries failed triggers forever. Three changes:
  1. Per-trigger retry counter with exponential backoff (1s, 2s, 4s... capped at 30s)
  2. Error classification: 4xx → dead-letter immediately, 5xx/network → retry with backoff
  3. Dead-letter path: advance Telegram offset, emit trace event, clean up stale state files, continue processing

### Added

- **Sustainability surface** — `.github/FUNDING.yml`, `docs/beta/SUSTAINABILITY.md`, README Support section

### Process

- **PR #105** — 2 review rounds. R1: `Fs.remove` → `Fs.unlink` build fix. AC4 (backoff) pushed from "met via poll interval" to real exponential backoff after review feedback.

---

## v3.13.0 (2026-03-24)

**Docs Governance: CDD Pipeline, Self-Coherence, Feature Bundles (#75)**

Development method and documentation governance made explicit and self-enforcing.

### Added

- **CDD §5.1 pipeline table** — 9 steps (0–8), each with explicit deliverable artifacts and locations. Bootstrap-first rule: first diff on a branch must create the version directory with stubs.
- **CDD §7.8 self-coherence report** — new artifact format (`SELF-COHERENCE.md`) in version directories. Records pipeline compliance, triadic assessment, checklist pass, known debt, and reviewer notes.
- **DOCUMENTATION-SYSTEM.md §3 single version lineage** — all docs use cnos release versions. No independent per-document version lineages. Frozen legacy snapshots explicitly allowed to retain historical versions.
- **Feature bundles** — `docs/alpha/agent-runtime/`, `docs/alpha/runtime-extensions/`, `docs/gamma/cdd/` with bundle READMEs, version directories, and frozen snapshots.
- **CDD skill §4.0 bootstrap** — executable skill now requires version-directory creation before any artifacts.
- **CDD skill §4.8 self-coherence** — executable skill now requires self-coherence report before review.

### Changed

- **CDD §7.3 process artifacts** — fixed stale references: `RULES.md` → `docs/gamma/RULES.md`, removed nonexistent `RELEASE.md`, `PLAN.md` → `docs/gamma/plans/`.
- **CDD §5.0 branch naming** — canonical format `{agent}/{issue}-{scope}-{version}`, tooling suffix rule.
- **Placeholder syntax** — governance docs now use `{placeholder}` instead of `<placeholder>` to prevent GitHub markdown stripping.

### Removed

- **CURIOSITY mindset** — removed `packages/cnos.core/mindsets/CURIOSITY.md`.

---

## v3.12.1 (2026-03-23)

**Daemon Boot Log: Configuration Sources (#61)**

Operators no longer have to probe files to understand what the daemon is running.

### Added

- **Boot banner** — daemon prints structured config declaration before "Daemon started" line: version, hub name, profile, model, secrets source, peers.
- **`secret_source` type** in `cn_dotenv.ml` — `Env | File | Missing` with no value payload. Makes secret leakage structurally impossible at the type level.
- **`probe_source`** function — checks where a secret key is configured without returning its value.
- 5 ppx_expect tests for probe_source (env precedence, file fallback, missing, type safety).

---

## v3.12.0 (2026-03-23)

**Wake-up Self-Model Contract (#56) + CDD/Review Skill Hardening (#57)**

The agent now receives a first-class Runtime Contract at every wake, replacing the overloaded capabilities-only block. Development skills hardened with issue AC reconciliation gates.

### Added

- **cn_runtime_contract.ml** — new module: gather/render_markdown/to_json/write. Structured Runtime Contract with three sub-blocks: self_model (version, hub, packages, overrides), workspace (directories, writable/protected), capabilities (observe/effect ABI, budgets, config).
- **RUNTIME-CONTRACT-v3.10.0.md** — design doc for wake-up self-model contract.
- **COGNITIVE-SUBSTRATE §6.1** — Runtime Contract as normative required runtime-generated block with invariant: agent answers self-knowledge from packed context alone.
- **cn doctor** validates runtime contract (self_model + workspace + capabilities + agent/ existence).
- **cn setup/init** creates `agent/` override directory.
- **CDD skill §2.4** — reconcile coherence contract with issue ACs.
- **CDD skill §4.5.1-3** — AC self-check at commit, multi-format parity rule, build-sync rule.
- **CDD skill §8.5** — author pre-flight AC walk before requesting review.
- **CDD skill §9.1** — issue AC verification as outermost release gate.
- **Review skill §2.0** — walk issue ACs before reading the diff.
- **Review skill §2.2.3** — multi-format parity check for dual-serialization modules.
- 10 new ppx_expect tests for runtime contract.

### Changed

- **cn_capabilities.ml** — `max_passes` now reads from `shell_config.max_passes` instead of hardcoded 2.
- **cn_context.ml** — emits `## Runtime Contract` with three sub-blocks instead of bare `Cn_capabilities.render`.
- **state/runtime-contract.json** — persisted at pack time for operator inspection; JSON now at full parity with markdown (observe/effect/apply_mode/exec_enabled/max_passes/budgets).
- Protected paths derived from `Cn_sandbox.default_denylist` + `protected_files` (single source of truth).

### Fixed

- Package/source sync for agent-ops (N-pass vocabulary) and release skill.

---

## v3.11.0 (2026-03-22)

**N-pass Merge + Misplaced Ops Correction (#51)**

### Added

- **Misplaced ops detection** — detect ops in body text and retry via correction pass (#51).
- **N-pass bind loop merged** to main with review fixes.

### Changed

- Structured output contract (#52) reverted — needs rework for tool_use integration.

---

## v3.10.0 (2026-03-22)

**N-pass Bind Loop (#50)**

### Added

- **Generic N-pass bind loop** — effect pass no longer terminal; loop continues up to `max_passes` as long as there are typed ops.
- **Processing indicators** — agent sees pass labels in context.
- Renamed `two_pass` → `n_pass` across codebase.
- Renamed `run_observe_pass` → `run_pass`.
- Removed observe-centered vocabulary residue.
- Aligned stop reasons and trace reason codes.

---

## v3.9.3 (2026-03-21)

**Anti-Confabulation: Op Result Integrity (#49)**

(Previously: v3.9.1 entry below was mislabeled)

---

## v3.9.1 (2026-03-21)

**Anti-Confabulation: Op Result Integrity (#49)**

Agent no longer confabulates when ops fail or are denied. Explicit result signals in Pass B repack, anti-fabrication instructions in capabilities block and doctrine.

### Added

- **Receipt result signals** — `receipts_summary` now tags each receipt with `[EMPTY_RESULT]`, `[NOT_EXECUTED]`, or `[FAILED]` to distinguish "op succeeded with empty data" from "op was not executed." Pass B context carries these signals so the agent knows what actually happened.
- **Failure WARNING banner** — When any Pass A receipt has status denied or error, the repack includes a `WARNING` block instructing the agent not to fabricate results.
- **Anti-confabulation CRITICAL** in capabilities block — New runtime-generated instruction: "When an op returns status=denied, status=error, or status=ok with zero artifacts, you MUST report the actual result to the user."
- **Op Result Integrity doctrine** — New section in AGENT-OPS.md (both `packages/cnos.core/doctrine/` and `src/agent/doctrine/`) with non-negotiable anti-confabulation rules.
- **6 new orchestrator tests** — `receipts_summary` signal tags for ok/empty/denied/error/skipped/mixed scenarios.

### Changed

- **`receipts_summary` format** — Denial reasons now prefixed with `reason:` for clarity. Each receipt line includes an explicit result signal tag.
- **Capabilities block** — All configs now emit the anti-confabulation CRITICAL line after the ops-in-frontmatter CRITICAL line.

---

## v3.9.0 (2026-03-20)

**Two-Pass Wiring + Cognitive Substrate + DUR Skill Contract**

Runtime two-pass execution wired end-to-end. COGNITIVE-SUBSTRATE spec published. Three skills cohered to DUR contract. Glossary updated.

### Added

- **Two-pass execution wired** (#41) — `Cn_orchestrator.run_two_pass` coordinates Pass A → repack → LLM call → parse → Pass B → coordination gating. `finalize` accepts `?packed` for Pass B LLM re-call. 7 integration tests with mock LLM.
- **COGNITIVE-SUBSTRATE.md** v1.0.0 — canonical classes (Identity, Doctrine, Mindset, Skill, Reflection), distinction rule, placement algorithm, file contracts, promotion/splitting rules, validation checks.
- **DUR glossary entry** — Define/Unfold/Rules documented as canonical skill contract in GLOSSARY.md.
- **`cn_runtime_integration_test.ml`** — new integration test file for two-pass orchestration.
- **`issue-41-pass-b-wiring.md`** — design doc for two-pass wiring.

### Changed

- **Reflect skill** — cohered to DUR contract. Evidence/Interpretation/Conclusion remapped to Define/Unfold/Rules. Axes (α/β/γ) moved under Unfold. Cadence table under Rules.
- **Adhoc-thread skill** — cohered to DUR contract. Added trigger recognition, type-matching judgment, bias-toward-capture rule.
- **Review skill** — cohered to DUR contract with MCI from PR #32 review process.
- **§7.2 mindset contract** — relaxed to structurally flexible, semantically constrained.

### Fixed

- Integration test pattern match updated for `pass_b_output` field.

---

## v3.8.0 (2026-03-20)

**Syscall Surface Coherence Amendment**

The CN Shell ABI is now honest, orthogonal, and hardened. Four incoherences closed: advertised-but-stub ops, implicit compound behavior, lossy observation, and hidden external dependencies. Multi-round review-driven development (PR #32).

### Added

- **fs_glob** — real implementation replacing stub. Pure OCaml glob matching (*, **, ?), sandbox-validated, symlink cycle detection via realpath, bounded output.
- **git_stage** — explicit staging op. Two modes: named files (sandbox-validated per file, directory rejection, `--literal-pathspecs`) or stage-all (NUL-delimited porcelain parser, per-candidate `validate_path`). Separates staging from commit.
- **fs_read chunking** — `offset` and `limit` fields for bounded reads of large files. Budget-capped.
- **cn doctor** — now checks for `patch(1)` (required by fs_patch).
- **Observe exclusion symmetry** — all four git observe ops (status, diff, log, grep) now use shared `git_observe_exclusions` (`-- . :!.cn :!state :!logs`). Runtime-owned paths hidden from agent.
- **SYSCALL-SURFACE-v3.8.0.md** — design doc specifying all four fixes.
- **PLAN-v3.8.0-syscall-surface.md** — implementation plan.

### Changed

- **git_commit** — no longer does implicit `git add -A`. Commits current index only. Returns `Skipped/nothing_staged` when index is empty. Use `git_stage` before `git_commit`.
- **git_grep** — uses `:(literal)` per-path instead of global `GIT_LITERAL_PATHSPECS`, appends observe exclusion pathspecs. Uses `-e` to force query as pattern.
- **git_diff / git_log** — `validate_rev` rejects leading-dash revisions (prevents CLI injection).
- **Observe vs write exclusions split** — protected files (SOUL.md, USER.md, etc.) are readable by git observe ops but not stageable by git_stage.

### Security

- `--literal-pathspecs` on git_stage prevents glob/pathspec magic interpretation
- `validate_rev` blocks `--output=<file>` style injection via leading-dash revisions
- `fs_glob` validates paths before descending, prevents symlink attacks
- `git_stage` stage-all rejects directories and symlinks to protected files

### Tests

- 32 → 69+ ppx_expect tests in cn_executor_test.ml
- Regression pairs for each hardening: positive case (feature works) + negative case (incoherence blocked)
- Capstone: git_status shows src/ changes while hiding .cn/, state/, logs/; prior observe op artifacts don't pollute subsequent git_status

### Coherence Delta

- **Gap:** Four ABI incoherences — stub op, compound behavior, lossy reads, hidden dependency
- **Mode:** MCA — change the runtime surface
- **α:** Syscall ABI now honest and orthogonal — no advertised-but-unimplemented ops
- **β:** All git observe ops use same exclusion boundary; capabilities block matches executor behavior
- **γ:** git_stage/git_commit separation enables future fine-grained staging without special cases

---

## v3.7.1 (unreleased)

**Trace Gap Closure: Full Behavioral Reconstruction**

The trace system now captures everything needed to reconstruct agent behavior without external assumptions.

### Fixed

- **LLM call latency + model** — `llm.call.ok` and `llm.call.error` now include `model`, `latency_ms`. Success events already had `input_tokens`/`output_tokens`/`stop_reason`; error events now get `model` and timing too.
- **Drain trigger_ids** — `drain.complete`/`drain.stopped` include `trigger_ids` array showing exactly which items were processed, plus `duration_ms`.
- **Sync duration** — `sync.ok` and `sync.error` include `duration_ms`. Error events include structured `step` and `exit_code` fields.
- **Config snapshot at boot** — `config.loaded` expanded with `max_tokens`, `sync_interval_sec`, `review_interval_sec`, `oneshot_drain_limit`, `daemon_drain_limit`, `telegram_configured`, `allowed_users` count.
- **Poll heartbeat** — `daemon.heartbeat` (Debug) emits every 60s with `polls_since_last` and `uptime_sec`. Hours of silence now distinguishable from dead daemon.
- **Cleanup trace** — `cleanup_once` emits `cleanup.complete` with status=Ok_ (removed count), Skipped (nothing_to_clean), or Degraded (cleanup_failed). No more silent success.

---

## v3.6.0 (unreleased)

### Fixed

- **Two-pass execution wired in cn_runtime (Issue #41)** — `finalize` now invokes Pass B when `needs_pass_b=true`. Previously, observe ops executed but the LLM was never re-called with evidence, making the sense→act loop dead. New `Cn_orchestrator.run_two_pass` coordinates: Pass A → repack with artifacts/receipts → LLM re-call → Parse → Pass B → coordination gating. Pass-A-safe coordination ops (ack, surface, reply) execute during Pass A; terminal ops (done, fail, send, delegate) defer to Pass B and are gated on effect success. Projection and conversation history use the final (Pass B) output. 7 integration tests added.

- **`cn update` binary-only (Issue #27)** — `cn update` now exclusively downloads pre-built binaries from GitHub Releases, mirroring `install.sh`. Removed the git-based update path entirely: no more `/usr/local/lib/cnos` assumption, no `opam exec -- dune build`, no `has_git_install()` detection. One install method, one update method. `Update_git` variant removed from `update_info` type; replaced by `Update_available`. Self-update check at CLI startup uses the same binary-download path.

---

## v3.5.1 (2026-03-11)

**TRACEABILITY: Structured Observability + CDD**

Operators can now answer "did it boot? what did it load? why did it transition?" from files alone.

### Added

- **`cn_trace.ml`** — Append-only JSONL event stream (`logs/events/YYYYMMDD.jsonl`). Schema `cn.events.v1` with boot_id, monotonic seq, severity, layer (sensor/body/mind/governance/world), reason_code on every transition.
- **`cn_trace_state.ml`** — State projections: `state/ready.json` (mind/body/sensors), `state/runtime.json` (cycle/lock/pass), `state/coherence.json` (structural checks).
- **Boot telemetry** — Mandatory 9-event boot sequence: `boot.start` → `config.loaded` → `deps.lock.loaded` → `assets.validated` → `doctrine.loaded` → `mindsets.loaded` → `skills.indexed` → `capabilities.rendered` → `boot.ready`. Per-package skill counts and hub-override detection.
- **Cycle telemetry** — `cycle.start`/`cycle.recover` → `pack.start`/`pack.complete` → `llm.call.start`/`llm.call.ok` → `effects.execute.start`/`effects.execute.complete` → `projection.*` → `finalize.complete`.
- **Sensor telemetry** — `daemon.poll.*`, `daemon.offset.advanced`/`daemon.offset.blocked` with reason codes (`rejected_user`, `still_queued`, `still_in_flight`, `processing_failed`).
- **Governance events** — `pass.selected`, `ops.classified`, `policy.denied` from orchestrator with reason codes.
- **`Cn_hub.log_action` shim** — Resurrected as compatibility bridge to `Cn_trace.gemit`.
- **`Cn_agent.queue_depth`** — Real queue count in projections.
- **`docs/alpha/security/TRACEABILITY.md`** — Full observability spec (721 lines).
- **`docs/gamma/plans/TRACEABILITY-implementation-plan.md`** — 12-step implementation plan.
- **`docs/gamma/CDD.md`** — Coherence-Driven Development v1.1.0: development method applying CAP to the development process.
- **Doc graph updates** — TRACEABILITY wired into README.md, AGENT-RUNTIME.md updated to v3.3.7.

### Fixed

- **Trace test isolation** — `open Cn_cmd` invalid with `wrapped false`; tmp dir collisions from unseeded `Random.int`.
- **Lockfile `ls-remote` parse** — Stricter: `None -> ""` on malformed output.

---

## v3.5.0 (2026-03-10)

**Unified Package Model + Coherent Agent Architecture + FOUNDATIONS**

Everything cognitive is now a package. Three packages ship: `cnos.core` (doctrine + mindsets + agent skills), `cnos.eng` (engineering skills), `cnos.pm` (PM skills). Role profiles select which packages an agent loads.

### Added

- **Unified package model** — `packages/` directory with `cn.package.json` manifests; two-layer resolution (installed packages → hub-local overrides); replaces the three-layer core/packages/hub-local split from v3.4.0
- **`cnos.core` package** — doctrine (FOUNDATIONS, CAP, CBP, CA-Conduct, COHERENCE, AGENT-OPS) + all mindsets + agent/ops/documenting/testing/release/skill skills
- **`cnos.eng` package** — engineering skills (coding, design, functional, OCaml, RCA, review, ship, testing, tool-writing, UX-CLI)
- **`cnos.pm` package** — PM skills (follow-up, issue, ship)
- **Role profiles** — `profiles/engineer.json`, `profiles/pm.json` — select packages per role
- **CAA v1.0.0** (`docs/alpha/agent-runtime/CAA.md`) — Coherent Agent Architecture spec: structural definition of a coherent agent, 7 invariants, failure mode table, wake-up strata
- **FOUNDATIONS.md** (`docs/explanation/`, `packages/cnos.core/doctrine/`) — doctrinal capstone: first principle through runtime, four doctrinal layers, cognitive loop, hierarchy of guidance
- **Doc graph cleanup** — version numbers removed from design doc filenames (AGENT-RUNTIME-v3.md → AGENT-RUNTIME.md, CAR-v3.4.md → CAR.md, PLAN-v3.3.md → PLAN.md)

### Changed

- **`cn_assets.ml`** — rewritten for unified two-layer resolution (was three-layer)
- **`cn_deps.ml`** — updated for package-based materialization
- **`cn_context.ml`** — delegates to `Cn_assets` for doctrine/mindset/skill loading
- **`cn_system.ml`** — updated for package-aware `cn setup` and `cn init`
- **`AGENTS.md`** — removed template-repo assumption; updated for package model
- **`README.md`** — corrected env var names, removed template-repo references

### Removed

- **`docs/design/CAR-v3.4.md`** — superseded by `docs/alpha/cognitive-substrate/CAR.md` (unified model)
- Template-repo assumption throughout docs

---

## v3.4.0 (2026-03-09)

**Cognitive Asset Resolver & Package System**

Fresh hubs now wake with the full cognitive substrate — mindsets, skills, and agent-ops guidance — without needing a separate template repo checkout.

### Added

- **`cn_assets.ml`** — Three-layer asset resolver (core → packages → hub-local overrides). Deterministic loading order, keyword-matched skill scoring delegates here
- **`cn_deps.ml`** — Dependency manifest (`.cn/deps.json`), lockfile (`.cn/deps.lock.json`), materialize/restore pipeline. Git-native package distribution
- **`cn deps` CLI commands** — `list`, `restore`, `doctor`, `add`, `remove`, `update`, `vendor`
- **Cognitive Assets block** in capabilities — agent sees asset summary (core count, packages, overrides) on every wake-up
- **`cn doctor`** checks for `.cn/vendor/core/`, deps manifest, and lockfile
- **`cn setup`** and `cn init` now materialize cognitive assets automatically — hub is wake-ready out of the box
- **CAR design doc** (`docs/design/CAR-v3.4.md`) — problem statement, three-layer model, package format, resolution spec
- **Implementation plan** (`docs/gamma/plans/CAR-implementation-plan.md`) — 8 ordered steps

### Changed

- **`cn_context.ml`** — delegates mindset/skill loading to `Cn_assets`; fails fast if core assets missing
- **`cn_capabilities.ml`** — `render` accepts optional `~assets` summary
- **`cn setup`** no longer requires root — focuses on hub asset materialization (system-level setup moves to `--system`)

### Removed

- Inline `load_mindsets` and skill-walking code from `cn_context.ml` (moved to `cn_assets.ml`)

---

## v3.3.1 (2026-03-07)

**Agent Instruction Alignment**

Fixes Pi hallucinating XML-style tool syntax (`<observe><fs_read>...`) by ensuring the agent sees the correct `ops:` JSON format on every call.

### Added

- **Canonical ops examples in capabilities block** — `cn_capabilities.ml` now injects `syntax:`, `example_observe:`, and `example_effect:` lines so the model sees the exact frontmatter JSON format on every wake-up
- **Output Discipline section** in `AGENTS.md` — explicit ban on XML pseudo-tools, markdown tool-call blocks, and ad-hoc shell snippets
- **Typed Capability Ops section** in `agent-ops/SKILL.md` — full JSON examples for observe, effect, and two-pass patterns with "do not" list

### Fixed

- **Stale paths** in `AGENTS.md` — `skills/` → `src/agent/skills/`, `mindsets/` → `src/agent/mindsets/`, `mindsets/OPERATIONS.md` → `src/agent/mindsets/OPERATIONS.md`
- **Session contract** in `AGENTS.md` — split into runtime mode (context pre-packed, don't re-read) vs manual/debugging mode

### Changed

- **Capabilities block** conditionally omits `example_effect:` when `apply_mode=off` (observe-only)
- All capabilities tests updated for new example lines

---

## v3.3.0 (2026-03-06)

**CN Shell — Typed Ops, Two-Pass Execution, Path Sandbox**

The agent can now read files, inspect git state, write patches, and run allowlisted commands — all as governed, post-call typed ops with receipts and artifact hashing. The pure-pipe boundary is preserved: no in-call tools, no tool loop. Ops are proposed in output.md, validated by cn, and executed with full audit trail.

### Added

- **cn_shell.ml** — Typed op vocabulary (7 observe + 5 effect kinds) + manifest parser with phase validation, auto-assigned op_ids, and duplicate detection
- **cn_sandbox.ml** — Path sandbox: normalization, `..` collapse, symlink resolution via `realpath`, denylist on resolved canonical paths, protected file enforcement. Catches symlinked-parent bypass attacks
- **cn_executor.ml** — Op dispatcher for fs_read/list, git_status/diff/log/grep, fs_write/patch, git_branch/commit, exec (allowlisted + env-scrubbed). Produces receipts and SHA-256-hashed artifacts
- **cn_orchestrator.ml** — Two-pass execution engine: Pass A executes observe ops and defers effects; Pass B executes effects and denies new observe ops. Coordination op gating (terminal ops blocked on effect failure). Context repack with bounded receipts + artifact excerpts for Pass B
- **cn_projection.ml** — Idempotent projection markers using `O_CREAT|O_EXCL` for crash-recovery deduplication of outbound messages
- **cn_capabilities.ml** — Runtime capability discovery block injected into packed context so the agent knows what ops are available before proposing them
- **cn_dotenv.ml** — `.cn/secrets.env` loader with env-var-first resolution and `0600` permission enforcement
- **cn_sha256.ml** — Pure OCaml SHA-256 (FIPS 180-4), zero external dependencies
- **Telegram UX** — 🤔 reaction on inbound message + typing indicator; reaction cleared on success. Uses `request_once` (no retry, 3s cap) for cosmetic calls
- **Crash recovery** — `ops_done` checkpoint prevents duplicate side effects on retry; projection markers prevent duplicate Telegram sends; conversation dedup by trigger_id; ordered cleanup (state files before markers) for crash safety
- **175+ new tests** — ppx_expect tests across all new modules: dotenv (18), shell (28), sandbox (30), executor (28), orchestrator (29), projection (16), capabilities (12), SHA-256 (10)

### Changed

- **cn_config.ml** — Loads CN Shell settings from `.cn/config.json` runtime section: `two_pass`, `apply_mode`, `exec_enabled`, `exec_allowlist`, budgets
- **cn_context.ml** — Optional `~shell_config` parameter injects capabilities block into packed context
- **cn_runtime.ml** — Passes `shell_config` through pack and recovery paths; stale `ops_done` GC on idle State 3 entry

### Docs

- **AGENT-RUNTIME.md** — Appendix C with 6 normative worked examples (v3.3.6)
- **PLAN.md** — 7-step implementation plan (all steps complete)
- **README, ARCHITECTURE, CLI, AUTOMATION** — Updated for new modules and hub structure
- **BUILD-RELEASE.md** — Accurate 7-step release process with RELEASE.md support

### CI

- **ci.yml** — `TMPDIR` isolation + `-j 1` for ppx_expect temp file race
- **release.yml** — Same TMPDIR fix + conditional `RELEASE.md` body for GitHub Releases

---

## v3.2.0 (2026-03-04)

**Structured LLM Request Schema**

The LLM now receives a structured prompt instead of a flat string. This unlocks prompt caching, proper system prompts, and real multi-turn conversation.

### The Big Picture

```
Before (v3.0):  { messages: [{ role: "user", content: "<everything>" }] }
After  (v3.2):  { system: [stable_block, dynamic_block], messages: [turn, turn, ...] }
```

### Added

- **Structured system prompt** — Two system blocks: (1) stable identity/user/mindsets with `cache_control` for Anthropic prompt caching (~90% cache hits on repeat calls), (2) dynamic reflections/skills (refreshed each call)
- **Real multi-turn messages** — Conversation history as actual `user`/`assistant` turns instead of markdown rendered inside a single user message
- **`system_block` / `message_turn` types** in `cn_llm.ml` with manual `to_json` helpers (zero-dep, no ppx)
- **`packed` type** in `cn_context.ml` — returns structured data + `audit_text` for backward-compatible `input.md` logging
- **Design doc** — `docs/DESIGN-LLM-SCHEMA.md` covers problem, schema, OCaml serialization decision, and all tradeoffs
- **Mindsets in context packer** (v3.1.x) — `src/agent/mindsets/` loaded in deterministic order between USER and reflections
- **Role-weighted skill scoring** (v3.1.x) — `runtime.role` from `.cn/config.json` applies +2 bonus to matching skill paths
- **Setup installer design doc** — `docs/alpha/cli/SETUP-INSTALLER.md`: guided `cn setup` flow with Telegram auto-detection, persona picker, secrets management
- **UX-CLI terminal conventions** — Color-to-semantics map, `NO_COLOR` support, actionable error messages
- **New skills** — `agent/coherent`, `eng/coding`, `eng/functional`, `eng/testing`

### Changed

- `Cn_llm.call` signature: `~content:string` → `~system:system_block list ~messages:message_turn list`
- `Cn_context.pack` returns `packed` record (system blocks + messages + audit_text) instead of flat `content` string
- `Cn_runtime.ml` passes structured data to LLM; recovery path (State 2) re-packs from extracted inbound message
- Tests updated to use `packed.audit_text` instead of `packed.content`

### Fixed

- `Filename.temp_dir` replaced with OCaml 4.14-compatible helper
- `runtime.role` normalized to lowercase (tolerates "Engineer", "PM", etc.)
- Expect test promotion: tokenize order + JSON error messages

---

## v3.0.0 (2026-02-22)

**Native Agent Runtime**

cnos agents now run natively — no external orchestrator required. The runtime implements a pure-pipe architecture: the LLM is a stateless `string → string` function, `cn` handles all I/O, effects, and coordination. OpenClaw is fully removed.

### The Big Picture

```
Before (v2.x):  Telegram → OpenClaw → cn → agent ops
After  (v3.0):  Telegram → cn agent → Claude API → cn → agent ops
                           ^^^^^^^^^^^^^^^^^^^^^^^^
                           All native OCaml, ~1,500 lines
```

The agent runtime replaces OpenClaw's:
- Telegram bot infrastructure → `cn_telegram.ml`
- LLM orchestration → `cn_llm.ml` (single call, no tool loop)
- Context management → `cn_context.ml` (pack everything upfront)
- Session handling → `cn_runtime.ml` (orchestrator)

### Added

**6 new modules (~1,500 lines total):**

| Module | Lines | Purpose |
|--------|-------|---------|
| `cn_runtime.ml` | 557 | Orchestrator: pack → call LLM → write → archive → execute → project |
| `cn_json.ml` | 310 | Zero-dependency JSON parser/emitter |
| `cn_context.ml` | 177 | Context packer (SOUL, USER, skills, conversation, message) |
| `cn_telegram.ml` | 170 | Telegram Bot API client (long-poll + send) |
| `cn_llm.ml` | 154 | Claude Messages API client (single request/response) |
| `cn_config.ml` | 88 | Environment + config.json loader |

**CLI interface:**
- `cn agent` — Cron entry point (dequeue, pack, call LLM, execute ops)
- `cn agent --daemon` — Long-running Telegram polling loop
- `cn agent --stdio` — Interactive testing mode
- `cn agent --process` — Process one queued item directly

**Documentation:**
- `AGENT-RUNTIME.md` — Full design doc with rationale, architecture, migration plan
- Updated `ARCHITECTURE.md`, `CLI.md`, `AUTOMATION.md`

### Architecture: Pure Pipe

The core insight: LLMs don't need tools if you pack context upfront.

```
cn packs context → LLM plans → cn executes ops
```

**Context stuffing vs. tool loops:**

| Approach | Token cost | API calls | Latency |
|----------|------------|-----------|---------|
| Tool loop (3 retrievals) | ~15K+ | 3-5 | 3-10s |
| Context stuffing | ~6.5K | **1** | **1-3s** |

For cnos's bounded, predictable context (~20-30 hub files), stuffing wins.

**What gets packed into `state/input.md`:**
- `spec/SOUL.md` — Agent identity (~500 tokens)
- `spec/USER.md` — User context (~300 tokens)
- Last 3 daily reflections (~1,500 tokens)
- Matched skills, top 3 (~1,500 tokens)
- Conversation history, last 10 (~2,000 tokens)
- Inbound message (~200 tokens)

### Changed

- **Removed OpenClaw dependency** — No external orchestrator
- **System deps only** — Requires `git` + `curl`, no opam runtime deps
- **Config location** — `.cn/config.json` (reuses existing hub discovery)
- **Secrets via env vars** — `TELEGRAM_TOKEN`, `ANTHROPIC_KEY`, `CN_MODEL`

### Security Model (Preserved)

The CN security invariant is enforced:

> Agent interface: `state/input.md → state/output.md`  
> LLM reality: sees text in, produces text out. cn does all effects.

- LLM never touches files, commands, or network
- Ops parsed from output.md frontmatter, validated before execution
- Raw IO pairs archived before effects (crash-safe audit trail)
- API keys via env vars, never logged

### Breaking Changes

- **OpenClaw no longer required** — Remove OC config after migration
- **`cn agent` is the new entry point** — Replaces OC heartbeat/cron
- **Telegram handled natively** — OC bot infrastructure bypassed

### Migration

1. Set env vars: `TELEGRAM_TOKEN`, `ANTHROPIC_KEY`
2. Create `.cn/config.json` with `allowed_users`
3. Start daemon: `cn agent --daemon` (or systemd unit)
4. Add cron: `* * * * * cn agent` (processes queue)
5. Disable OpenClaw after verification

Rollback: `systemctl stop cn-<name> && systemctl start <previous-service>`

### Technical Highlights

- **Zero opam runtime deps** — stdlib + Unix only
- **curl-backed HTTP** — No OCaml HTTP stack complexity
- **Body consumption rules** — Markdown body = full response, frontmatter = notification
- **FSM integration** — Reuses existing `cn_protocol.ml` actor FSM
- **617 lines of new tests** — `cn_cmd_test.ml` + `cn_json_test.ml`

---

## v2.4.0 (2026-02-11)

**Typed FSM Protocol**

The cn protocol is now modeled as four typed finite state machines with compile-time safety.

### Added
- **4 typed FSMs** — Transport Sender, Transport Receiver, Thread Lifecycle, Actor Loop
- **cn_protocol.ml** — unified protocol implementation replacing scattered logic
- **385 lines of protocol tests** — ppx_expect exhaustive transition testing
- **ARCHITECTURE.md** — system overview documentation
- **PROTOCOL.md** — FSM specifications with ASCII diagrams
- **AUDIT.md** — design audit methodology

### Changed
- Archived 7 superseded design docs to `docs/design/_archive/`
- Unified `cn_io.ml` + `cn_mail.ml` transport logic into single FSM

### Fixed
- Invalid state transitions now caught at compile time, not runtime

---

## v2.3.1 (2026-02-11)

**Branch Cleanup Fix**

### Fixed
- Delete local branches after inbox sync (MCA cleanup)
- Skip self-update check if install dir missing
- CI: add ppx_expect to opam deps

---

## v2.3.0 (2026-02-11)

**Native OCaml Binary**

cn is now a native binary — no Node.js required.

### Added
- **Native OCaml build** — `dune build` produces standalone binary
- **Release workflow** — pre-built binaries for Linux/macOS
- **10-module refactor** — cn.ml split into focused modules:
  - `cn_agent.ml`, `cn_commands.ml`, `cn_ffi.ml`, `cn_fmt.ml`
  - `cn_gtd.ml`, `cn_hub.ml`, `cn_mail.ml`, `cn_mca.ml`
  - `cn_protocol.ml`, `cn_system.ml`

### Changed
- `cn update` now copies `bin/*` to `/usr/local/bin/` (2.2.28 backport)
- `cn-cron` now runs `cn in` after sync to wake agent (2.2.27 backport)

### Fixed
- Filter inbound to `threads/in/` only (2.2.26 backport)
- Native argv handling (drops 1, not 2 like Node.js)

---

## v2.2.0 (2026-02-07)

**First Hash Consensus**

Two AI agents achieved verified hash consensus via git-CN protocol — the actor model is complete.

### Milestone
- **Hash consensus** — Pi and Sigma independently converged on cnos `d1cb82c`
- **Verified via git** — runtime.md pushed to GitHub, human-verified
- **No central coordinator** — pure git-based decentralized coordination

### Added
- **cn update auto-commit** — runtime.md auto-commits and pushes (P1)
- **Output auto-reply** — output.md responses auto-flow to sender (CLP accepted)
- **MCA injection** — coherence check every 5th cycle
- **Sync dedup** — checks `_archived/` before materializing
- **agent-ops skill** — operational procedures for CN agents
- **CREDITS.md** — lineage acknowledgment

### Fixed
- Wake mechanism: `openclaw system event` instead of curl
- Version string sync between package.json and cn_lib.ml
- Stale branch cleanup procedures

### Protocol
- 5-minute cron interval standardized
- input.md/output.md protocol documented in SYSTEM.md
- Queue system (state/queue/) for ordered processing

---

## v2.0.0 (2026-02-05)

**Everything Through cn**

Paradigm shift: agents no longer run git directly. Everything goes through the `cn` CLI.

### Added
- **CN CLI v0.1** — `tools/src/cn/`: modular OCaml implementation
  - `cn init`, `cn status`, `cn inbox`, `cn peer`, `cn doctor`
  - Best-in-class patterns from npm, git, gh, cargo
- **UX-CLI spec** — `skills/ux-cli/SKILL.md`: terminal UX standard
  - Semantic color channels
  - Failure-first design
  - "No blame, no vibes"
- **SYSTEM.md** — `spec/SYSTEM.md`: definitive system specification
- **cn_actions library** — Unix-style atomic primitives
- **Coordination First** principle — unblock others before your own loop
- **Erlang model** — fire-and-forget, sender tracks

### Architecture
- Agent = brain (decisions only)
- cn = body (all execution)
- Agent purity enforced by design

### Breaking Changes
- Agents should use `cn` commands, not raw git
- Direct git execution deprecated (will be blocked in future)

---

## v1.8.0 (2026-02-05)

**Agent Purity + Process Maturity**

Core architectural principle established: Agent = brain (decisions only), cn = body (all execution).

### Added
- **CN Protocol** — `docs/design/CN-PROTOCOL.md`: action vocabulary, protocol enforcement rules
- **Inbox Architecture** — `docs/design/INBOX-ARCHITECTURE.md`: agent purity constraint, thread-as-interface
- **Engineering skills** — `skills/eng/` with coding, ocaml, design, review, rca
- **Ship skill** — `skills/ship/`: branch → review → merge → delete workflow
- **Audit skill** — `skills/audit/`: periodic health checks
- **Adhoc-thread skill** — `skills/adhoc-thread/`: when/how to create threads (β test)
- **THINKING mindset** — evidence-based reasoning, know vs guess
- **AGILE-PROCESS** — `docs/gamma/AGILE-PROCESS.md`: backlog to done workflow
- **THREADS-UNIFIED** — `docs/design/THREADS-UNIFIED.md`: backlog as threads, GTD everywhere

### Changed
- **PM.md** — "Only creator deletes branch" rule added
- **ENGINEERING.md** — "Always rebase before review" principle

### Fixed
- Branch deletion violation documented in RCA

### Process
- No self-merge enforced
- Rebase before review required
- Author deletes own branches after merge

---

## v1.7.0 (2026-02-05)

**Actor Model + GTD Inbox**

Major coordination upgrade. Agents now use Erlang-inspired actor model: your repo is your mailbox.

### Added
- **inbox tool** — replaces peer-sync. GTD triage with Do/Defer/Delegate/Delete
- **Actor model design** — `docs/design/ACTOR-MODEL-DESIGN.md`
- **RCA process** — `docs/beta/evidence/rca/` with template and first incident
- **FUNCTIONAL.md** — mindset for OCaml/FP patterns
- **PM.md** — product management mindset with user stories, no self-merge
- **FOUNDATIONS.md** — the coherence stack explained (C≡ → TSC → CTB → cnos)
- **APHORISMS.md** — collected wisdom ("Tokens for thinking. Electrons for clockwork.")
- **ROADMAP.md** — official project roadmap
- **GitHub Actions CI** — OCaml tests + native build

### Changed
- **docs/ reorganized** — whitepapers/design docs moved to `docs/design/`
- **Governance** — no self-merge rule: engineer writes → PM merges

### Deprecated
- **peer-sync** — use `inbox` instead

### Fixed
- 4-hour coordination failure (RCA documented, protocol fixed)
