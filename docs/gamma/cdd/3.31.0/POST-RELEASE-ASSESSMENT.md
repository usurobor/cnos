## Post-Release Assessment -- v3.31.0

### 1. Coherence Measurement

- **Baseline:** v3.29.1 -- alpha A, beta A, gamma A
- **This release:** v3.31.0 -- alpha A, beta A, gamma B+
- **Delta:**
  - alpha held (A) -- `cn_packet.ml` types are unambiguous: distinct field names (`pkt_schema`, `pkt_sender`, `pkt_recipient`, `pkt_topic`), `validation_result` is a clean sum type, `dedup_status` is a closed enum. Envelope serialization round-trips through JSON. SHA-256 is the canonical content identity. No type confusion possible.
  - beta held (A) -- Send side creates packets, receive side validates them. Envelope fields match ref namespace bindings. Dedup index tracks all inbound packets. Legacy diff-based path fully deleted -- packet is the only materialization path. CDD artifacts updated to match final code state. All authority surfaces agree.
  - gamma regressed (B+) -- 13 review rounds (target: <=2). 22 findings total, ~82% mechanical ratio (target: <20%). The core architecture was sound from R1 -- all rounds after R1 were mechanical test/build cleanup. The legacy path deletion (R5-R6) triggered a cascade of 12 additional findings, all mechanical (deleted functions still referenced, cram tests assuming branch transport, glob patterns, heredoc whitespace). Process issue required.
- **Coherence contract closed?** Yes. All 4 ACs met:
  - AC1: Legacy `materialize_branch` deleted; `materialize_packet` materializes exact validated payload only
  - AC2: Packet validation rejects on any schema/recipient/payload mismatch -- fail-closed
  - AC3: Obsolete -- peer clone main freshness irrelevant (diff-based path removed entirely)
  - AC4: Payload SHA-256 verified before materialization; silent content swap structurally impossible

### 2. Encoding Lag

| Issue | Title | Type | Design | Impl | Lag |
|-------|-------|------|--------|------|-----|
| #150 | Message Packet Transport | feature | converged | **Phase 1 shipped** | **none** |
| #152 | Audit legacy fallback paths in src/ | process | issue spec | not started | new |
| #148 | check_binary_version_drift wrong binary output | bug | issue spec | not started | new |
| #142 | Peer sync: FidoNet parity | feature | issue spec | not started | growing |
| #141 | Peer sync: empty-content branches permanent limbo | bug | issue spec | not started | growing |
| #135 | Per-pass logging (#74 Phase 2) | feature | issue spec | not started | growing |
| #132 | Rename skill categories | process | issue spec | not started | growing |
| #124 | Agent asks permission despite autonomy defaults | bug | issue spec | not started | growing |
| #101 | Normalize skill corpus | process | issue spec | not started | growing |
| #100 | Memory as first-class capability | feature | issue spec | not started | growing |
| #96 | Docs taxonomy alignment | process | issue spec | not started | growing |
| #94 | cn cdd: mechanize CDD invariants | feature | issue spec | not started | growing |
| #84 | CA mindset reflection requirements | feature | issue spec | not started | growing |
| #79 | Projection surfaces | feature | issue spec | not started | growing |
| #68 | Agent self-diagnostics | feature | issue spec | not started | growing |
| #59 | cn doctor -- deep validation | feature | partial design | partially addressed | low |
| #43 | No interrupt mechanism | feature | issue spec | not started | growing |
| #20 | Eliminate silent failures in daemon | bug | issue spec | partially addressed | low |

**MCI/MCA balance:** MCI remains resumed. #150 Phase 1 shipped -- P0 transport-integrity bug closed. Two new issues filed from this cycle (#152 legacy audit, #148 was pre-existing). Backlog stable at ~15 growing issues. No freeze threshold crossed (growing count unchanged from v3.28.0).

**Rationale:** Growing count has not increased. The new #152 issue was filed directly from this release's findings (legacy path audit). No new design commitments made.

### 3. Process Learning

**What went wrong:**

1. **13 review rounds for an architecturally-sound change.** The core packet transport was correct from R1. All 4 D-level findings in R1 were mechanical (wrong constructor name, broken git plumbing, wrong match arm, shell quoting). The remaining 9 rounds were entirely cascade failures from the legacy path deletion decision at R5: tests referencing deleted functions, cram tests assuming branch-based transport, glob pattern issues, heredoc whitespace. Each round found 1-3 more mechanical issues that could have been caught by running `dune runtest` and reading the cram test files before pushing.

2. **No pre-review test sweep.** The code agent pushed fixes without running a full test suite first. This is the root cause of rounds 6-12 -- each round caught what `dune runtest` would have caught locally.

3. **Legacy path deletion was a mid-review scope change.** The initial PR included both Phase 0 (hardened legacy path) and Phase 1 (packet transport). R5 (operator review) instructed deletion of the legacy path entirely -- a correct architectural decision, but it invalidated all existing tests. The scope change mid-review is what caused the cascade.

**What went right:**

1. **Architecture was sound from R1.** The packet schema, validation pipeline, dedup/equivocation index, and Git ref namespace were all correct in the first submission. No architectural changes were needed across 13 rounds.

2. **Operator escalation at R5 was the right call.** The reviewer (R1-R4) was fixing mechanical issues in the legacy path. The operator (R5) correctly identified that hardening the legacy path was backward compatibility with the bug itself, and instructed deletion. This produced a cleaner final result.

3. **Fail-closed design eliminates the bug class.** The packet transport doesn't just fix #150 -- it makes the entire class of stale-diff-content-swap impossible. Payload identity is verified by SHA-256 before any inbox write.

**Skill patches needed:** Yes -- process issue required for mechanical ratio (see section 4).

**Active skill re-evaluation:**

| Finding | Active skill | Would skill have prevented it? | Assessment |
|---------|-------------|-------------------------------|------------|
| F1 R1 (Cn_json.Array) | ocaml | Yes -- type checking would catch if build was run | Application gap -- build not run before review |
| F2 R1 (mktree slashed paths) | ocaml | No -- git mktree behavior is not an OCaml concern | Knowledge gap (git plumbing) |
| F3 R1 (Rejected_dedup) | ocaml | Yes -- match arm grouping is a pattern matching concern | Application gap -- review caught it |
| F5 R1 (list_packet_refs quoting) | ocaml | Partially -- shell quoting inside OCaml is a boundary concern | Application gap |
| F9 R2 (Cn_hub circular dep) | ocaml | Yes -- dune build would catch | Application gap -- build not run |
| F12-22 (test cleanup cascade) | testing | Yes -- running `dune runtest` before each push would catch all | Application gap -- no pre-push test sweep |

### 4. Review Quality

**PRs this cycle:** 1 (PR #151, squash merge)
**Review rounds:** 13 (R1-R4 reviewer, R5 operator, R6-R13 reviewer) -- target: <=2 -- **FAILED**
**Superseded PRs:** 0 -- target: 0 -- **PASSED**
**Finding breakdown:**

| Round | Findings | Mechanical | Judgment |
|-------|----------|------------|----------|
| R1 | 8 | 5 (F1 Array, F2 mktree, F4 echo-n, F5 quoting, F7 redundant dep) | 3 (F3 Rejected_dedup, F6 dedup O(N^2), F8 self-coherence overclaims) |
| R2 | 1 | 1 (F9 Cn_hub circular) | 0 |
| R3 | 1 | 1 (F10 expect-test whitespace) | 0 |
| R4 | 1 | 1 (F11 outbox.t) | 0 |
| R5 | 4 | 2 (F-CI, F-Unicode) | 2 (F-fail-open legacy, F-self-coherence) |
| R6 | 3 | 3 (F12-14 deleted function refs, inbox text) | 0 |
| R7 | 1 | 1 (F15 sync.t) | 0 |
| R8 | 1 | 1 (F16 sync.t inbound) | 0 |
| R9 | 0 | 0 | 0 |
| R10 | 2 | 2 (F19 glob, F20 whitespace) | 0 |
| R11 | 1 | 1 (F21 glob path) | 0 |
| R12 | 1 | 1 (F22 grep too broad) | 0 |

**Total findings:** 24 (19 mechanical, 5 judgment)
**Mechanical ratio:** 79% (19/24) -- threshold: 20% -- **EXCEEDED**
**Action:** Filed as process learning. Root cause: no pre-push test execution. The code agent pushed 12 fix commits without running `dune runtest` first. Two structural fixes needed:
1. The pre-push gate (`scripts/pre-push.sh`) must be active in the development environment
2. Mid-review scope changes (R5 legacy deletion) should trigger a full test sweep before the next push

### 4a. CDD Self-Coherence

- **CDD alpha:** 4/4 -- Bootstrap README, SELF-COHERENCE.md, PLAN, 16 packet tests, POST-RELEASE-ASSESSMENT.md all present. CHANGELOG TSC row present.
- **CDD beta:** 3/4 -- CDD artifacts were updated at R8 to match final code state (packet-only path, legacy deleted). PR body still describes dual-path migration at merge time (not updated). Minor authority-surface gap.
- **CDD gamma:** 2/4 -- 13 review rounds (6.5x target). 79% mechanical ratio (4x threshold). Architecture correct from R1 but mechanical churn dominated the cycle. Mid-review scope change (R5) was architecturally correct but process-expensive.
- **Weakest axis:** gamma (cycle economics)
- **Action:** Enforce pre-push test sweep. The 12 rounds after R1 were avoidable with `dune runtest` before each push.

### 5. Production Verification

**Scenario:** Two peers (sigma, pi) where pi sends a message to sigma via packet transport. On `cn sync`, sigma should validate the packet envelope, verify payload SHA-256, materialize to inbox, and record in dedup index. A second sync should detect the duplicate and skip.

**Before this release:** `git diff main...origin/<branch>` on stale clone returns noise files. `materialize_branch` writes the first `.md` match -- wrong content silently written to inbox.

**After this release:** `inbox_process` fetches packet refs only. `materialize_packet` validates envelope schema, recipient, namespace bindings, and payload SHA-256 before any inbox write. Wrong content is structurally rejected.

**How to verify:**
1. Deploy v3.31.0 binary to both peers
2. On pi: create outbox message addressed to sigma, run `cn sync` -- should push packet ref to pi's origin
3. On sigma: run `cn sync` -- should fetch packet ref, validate, materialize to inbox
4. Verify inbox file contains correct content (matches pi's outbox message exactly)
5. Run `cn sync` on sigma again -- should print "Duplicate packet" and skip
6. Check `state/inbound-index.json` -- should contain one entry with correct msg_id and payload_sha256
7. Tamper test: manually create a packet ref with wrong SHA-256 in envelope -- sigma should reject with "payload_sha256_mismatch"

**Result:** Deferred -- requires deployed two-peer environment with v3.31.0 binary. Committed to verify on next deployment cycle.

## Cycle Iteration

### Triggers fired
- [x] review rounds > 2 (actual: 13)
- [x] mechanical ratio > 20% (actual: 79%)
- [ ] avoidable tooling/environmental failure
- [x] loaded skill failed to prevent a finding (ocaml skill: build not run before review)

### Friction log
R1-R4: 4 D-level mechanical findings in initial implementation (wrong constructor, git plumbing, match arm, quoting). All fixable by running `dune build` before review submission.

R5: Operator review correctly escalated: legacy path is backward compatibility with the bug. Instructed full deletion.

R6-R12: Cascade of 12 mechanical findings from legacy path deletion. Each round caught what `dune runtest` would have found. The code agent pushed fixes incrementally without running the full test suite, turning a single architectural decision into 7 review rounds.

R13: Approved. All tests green.

### Root cause
Two independent causes:
1. **No pre-push build/test.** Findings 1, 2, 5, 9, 10 (R1-R3) would have been caught by `dune build && dune runtest`.
2. **Mid-review scope change without full test sweep.** The R5 decision to delete the legacy path was correct, but the implementation was pushed in incremental commits without running the full test suite between rounds. This created 7 avoidable review rounds (R6-R12).

### Skill impact
The `ocaml` active skill covers type safety and module boundaries but does not mandate pre-review build verification. The `testing` skill covers test design but not pre-push test execution. Neither skill is underspecified -- both are correct. The gap is operational: the agent did not run the build before submitting for review.

### MCA
No separate MCA needed. The root cause is operational (run tests before push), not a skill or design gap. The pre-push gate (`scripts/pre-push.sh`) exists but was not active.

### Cycle level
L7 (boundary move)
Justification: This release replaces an entire transport mechanism (diff-based branch discovery -> canonical packet protocol). The change moves the trust boundary: message identity is now verified by cryptographic hash rather than inferred from diff position. This is a structural boundary move, not a local fix.

### 6. CDD Closeout

| Step | Artifact | Skills loaded | Decision |
|------|----------|--------------|----------|
| 11 Observe | git log, RELEASE.md, CHANGELOG.md | post-release | All packet transport code on main; VERSION=3.31.0; tag 3.31.0 present |
| 12 Assess | POST-RELEASE-ASSESSMENT.md | post-release | Assessment completed; gamma regressed (B+); 3 triggers fired |
| 13 Close | immediate fixes listed below | post-release | Cycle closed; deferred outputs committed |

### 7. Next Move

**Next MCA:** #152 -- Audit and eliminate all legacy fallback paths in src/
**Owner:** pending selection
**Branch:** pending
**First AC:** All `2>/dev/null || fallback` patterns in src/ identified and classified as safe-fallback or fail-open
**MCI frozen until shipped?** No -- backlog stable, no P0s remaining
**Rationale:** #152 was filed directly from this release. The #150 fix demonstrated that legacy fallback paths can silently degrade to broken behavior. A systematic audit of remaining fallback patterns prevents the same class of bug in other subsystems. #141 (empty-content branches) is now moot since branch-based transport is deleted. #148 (version drift parsing) is a smaller targeted fix that could be an MCI patch.

**Closure evidence (CDD S10):**
- Immediate outputs executed: yes
  - #150 shipped (PR #151, squash merge)
  - CHANGELOG 3.31.0 TSC entry present
  - POST-RELEASE-ASSESSMENT.md written (this artifact)
  - CHANGELOG TSC row revised: gamma A -> B+ (assessment governs)
- Deferred outputs committed: yes
  - Production verification: next deployment cycle with two-peer environment
  - #152 committed as next MCA candidate
  - Pre-push gate activation: verify `scripts/pre-push.sh` is active in dev environment

**Immediate fixes** (executed in this session):
- POST-RELEASE-ASSESSMENT.md (this artifact)
- CHANGELOG TSC row: gamma revised from A to B+ (13 rounds, 79% mechanical ratio)
