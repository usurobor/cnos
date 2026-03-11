# Coherence-Driven Development (CDD)

**Version:** 1.1.0
**Status:** Draft
**Date:** 2026-03-11
**Placement:** Design document (`docs/design/`)
**Audience:** Contributors, reviewers, maintainers, release operators
**Scope:** Defines the development method used to evolve cnos coherently

---

## 0. Purpose

This document defines **Coherence-Driven Development (CDD)**:
a development method in which the primary objective is to reduce incoherence across:

- doctrine
- architecture
- implementation
- runtime behavior
- operator understanding
- release state

CDD applies CAP to development itself.

> **A change is good not merely when it is implemented, but when it reduces incoherence across the system as a whole.**

Formalization — writing explicit contracts (specs, schemas, invariants, acceptance criteria) — is how coherence becomes inspectable. The cnos system already practices formalization through doctrine, design documents, and schemas. CDD names the wider method that gives formalization its purpose.

---

## 1. Definition

CDD is a development method in which every meaningful change is treated as an intervention on incoherence.

A change is proposed, reviewed, implemented, tested, and released in terms of:

- what gap exists,
- whether the intervention is MCA or MCI (applied to development — see §2.1),
- how it affects:
  - **α PATTERN** — internal consistency
  - **β RELATION** — alignment with surrounding artifacts and contexts
  - **γ EXIT** — future evolution path

### 1.1 Formalization as core practice

Formalization is the practice of writing coherence down so it can be inspected:

- architecture docs
- schemas
- invariants
- migration rules
- examples
- acceptance criteria

Without formalization, coherence cannot be tested. Contradictions stay implicit, tests become local-only, reviews become taste-based, and runtime drift hides until late.

But formalization alone does not guarantee relational coherence across docs, operator readiness, doctrine/runtime alignment, release integrity, or evolution clarity. That is why CDD is broader than any single formal practice.

---

## 2. First Principle

CDD begins from the same first principle that governs the coherent agent (FOUNDATIONS.md):

> **There is a gap between model and reality.**

In development terms:

- the **model** is doctrine, architecture, design, operator understanding, and intended behavior
- **reality** is code, runtime behavior, logs, failures, and actual operator experience

That gap is development incoherence.

### 2.1 CAP applied to development

CDD applies CAP to the development process. The mechanism is the same — MCA or MCI, MCA first — but the scope shifts:

| CAP (agent runtime) | CDD (development process) |
|---------------------|--------------------------|
| MCA: act on the world | MCA: change the system (code, config, runtime) |
| MCI: update the model | MCI: change the design (docs, assumptions, specs) |
| Reality: external world | Reality: code, runtime behavior, operator experience |
| Model: agent beliefs | Model: doctrine, architecture, design docs |

The priority rule holds:

> **Prefer MCA when coherent action is possible.
> Use MCI when the model is wrong or action is blocked.**

Examples:
- Runtime behavior wrong, docs correct → MCA (fix the code)
- Docs wrong, runtime correct → MCI (fix the docs)
- Both wrong → MCA + MCI, smallest coherent intervention

### 2.2 Boundary with CAP

CDD governs how humans and agents develop the system.
CAP governs how the agent operates at runtime.

CDD uses CAP's vocabulary because the underlying dynamic is the same: detect a gap, close it through action or learning. But CDD is not CAP. CAP is doctrine. CDD is a design-level method that applies doctrine to the development process.

---

## 3. What CDD Optimizes For

CDD does not optimize primarily for speed, novelty, local elegance, or green CI alone.

CDD optimizes for:

### 3.1 α PATTERN — internal consistency

The change should not introduce contradiction, duplication, or conceptual drift.

- Are terms used consistently?
- Do examples match norms?
- Does the code reflect the spec?
- Does the spec reflect the actual system?

### 3.2 β RELATION — alignment across the system

The change should make surrounding artifacts reveal the same system.

- Do README, design docs, code, runtime behavior, and operator experience agree?
- Do setup, runtime, and security form one story?
- Does the agent-facing instruction surface match the runtime ABI?

### 3.3 γ EXIT — coherent evolution path

The change should improve the future, not just the present.

- Is migration clear?
- Are versioning and lockfiles stable?
- Can the system evolve without special-case accretion?
- Did we reduce future incoherence?

---

## 4. The CDD Review Loop

CDD uses CLP as its review structure. Two aspects of CLP apply:

### 4.1 CLP as dialogue structure (TERMS → POINTER → EXIT)

Every significant review, whether in a thread, a PR, or a design discussion, uses:

- **TERMS** — what is being discussed; shared vocabulary
- **POINTER** — where the tension is; what's incoherent
- **EXIT** — what changed; what's next

This is the dialogue form from COHERENCE doctrine.

### 4.2 CLP as refinement loop (Seed → Reflect → Check → Patch → Repeat)

Every substantial artifact undergoes iterative refinement:

1. **Seed** — state the gap clearly. What is incoherent? At which layer? What is the smallest coherent intervention?

2. **Bohmian reflection** — dialog that seeks the real structure of the problem. Not brainstorming. Questions: What is the system trying to become? What are we implicitly assuming? Where are two truths coexisting? What would make this simpler and truer?

3. **Triadic check** — score the change across α PATTERN, β RELATION, γ EXIT.

4. **Patch weakest axis** — do not polish the strongest axis. Fix the weakest one.

5. **Repeat until threshold** — stop when the design is coherent enough to implement. Do not implement into unresolved conceptual fog.

These two aspects are compatible: the TERMS/POINTER/EXIT structure gives form to each step in the refinement loop.

---

## 5. The Development Pipeline

In cnos, the intended sequence is:

1. **Design** — a substantial change begins in design, not in code
2. **Coherence contract** — state the gap, mode, scope, expected effect (§7)
3. **Plan** — steps, dependencies, risk boundaries, compile-safe increments
4. **Tests** — pin invariants, schemas, corner cases, regressions
5. **Code** — realizes the design, does not invent architecture
6. **Docs** — updated to match implementation
7. **Release** — CI, binaries, notes, migration implications, known coherence debt
8. **Observe** — runtime telemetry confirms design/implementation alignment

### 5.1 Relationship to AGILE-PROCESS.md

The workflow states (Backlog → Claimed → In Progress → Review → Done) defined in `docs/design/AGILE-PROCESS.md` govern how work moves through the team. CDD governs what coherence means at each stage:

| Agile state | CDD concern |
|-------------|-------------|
| Backlog | Gap identified, prioritized by coherence impact |
| Claimed | Coherence contract drafted |
| In Progress | Design → plan → test → code pipeline |
| Review | Triadic check (α/β/γ), CLP dialogue |
| Done | Release criteria met (§10) |

CDD does not replace the agile workflow. It defines the quality function the workflow optimizes for.

---

## 6. The Coherence Contract

Every substantial change SHOULD carry a coherence contract.

A coherence contract answers:

### 6.1 Gap
What incoherence is being reduced?

### 6.2 Mode
Is this MCA or MCI? (In the development sense — see §2.1)

### 6.3 Scope
Which layer is affected?
- doctrine
- architecture
- runtime
- packaging
- operator surface
- release process

### 6.4 Expected triadic effect
- α: what internal contradiction is reduced?
- β: what relation is aligned?
- γ: what future path is clarified?

### 6.5 Failure if skipped
What incoherence persists if we do nothing?

---

## 7. Artifacts Used by CDD

CDD uses the standard cnos artifact set.

### 7.1 Doctrine artifacts
- `packages/cnos.core/doctrine/FOUNDATIONS.md`
- `packages/cnos.core/doctrine/CAP.md`
- `packages/cnos.core/doctrine/COHERENCE.md`
- `packages/cnos.core/doctrine/CBP.md`
- `packages/cnos.core/doctrine/CA-CONDUCT.md`
- `packages/cnos.core/doctrine/AGENT-OPS.md`

Role: define first principles and normative boundaries.

### 7.2 Design artifacts
- `docs/design/CAA.md`
- `docs/design/AGENT-RUNTIME.md`
- `docs/design/CAR.md`

Role: define the structural system.

### 7.3 Process artifacts
- `docs/design/AGILE-PROCESS.md`
- `RULES.md`
- `RELEASE.md`

Role: define workflow, governance, and release procedure.

### 7.4 Implementation plans
- `PLAN.md`
- Feature-specific plans (e.g., `docs/design/CAR-implementation-plan.md`)

Role: define build order and scope.

### 7.5 Tests
Role: pin invariants and executable truth.

### 7.6 Release notes
Role: explain the coherence delta to operators and contributors.

### 7.7 Runtime telemetry
Role: expose whether the actual running system matches the design.

---

## 8. Runtime and Operations Are Part of CDD

CDD does not stop at merge.

A system can be well-designed and still be incoherent in operation.

### 8.1 Structural coherence telemetry
The system should expose:
- doctrine loaded?
- packages installed?
- mindsets loaded?
- capabilities rendered?
- transport ready?
- state = ready / degraded / blocked?

### 8.2 Transition traceability
Operators must be able to answer:
- why did it go here?
- why did it not go there?
- what evidence was used?
- what was denied and why?

### 8.3 Release gates
A release is not coherent if:
- docs disagree with code
- runtime cannot explain itself
- setup story differs from security story
- an operator cannot determine readiness

---

## 9. Release Criteria Under CDD

A change is releasable when:

### 9.1 α is acceptable
- no major internal contradictions remain
- examples and norms align
- naming is stable

### 9.2 β is acceptable
- docs, runtime, code, and operator story agree
- no stale worldview remains in agent-facing instructions

### 9.3 γ is acceptable
- migration path is clear
- versioning is explicit
- future evolution is not cornered by the current fix

### 9.4 Operational visibility exists
- boot/readiness can be determined
- failure modes are visible
- major transitions have reason codes

---

## 10. Failure Modes of Development

CDD defends against these failures:

### 10.1 Spec-free implementation
Coding before the design has stabilized.

### 10.2 Design drift
Docs and runtime telling different stories.

### 10.3 Local optimization
Fixing α while worsening β or γ.

### 10.4 Green-build illusion
Treating CI success as sufficient release justification.

### 10.5 Hidden incoherence
Accepting silent fallback or degraded behavior without explicit visibility.

### 10.6 Runtime/documentation split
The system works one way, but teaches another.

---

## 11. The Place of Human Judgment

CDD is rigorous, but not mechanical.

It requires judgment:

- when to stop iterating
- what counts as the real gap
- whether a contradiction is superficial or structural
- whether a release is coherent enough

CLP exists because coherence cannot always be inferred from checklists alone. But checklists still matter.

This also means CDD must not become a gate that blocks shipping. CA-CONDUCT says: "Done beats perfect. Bias for action." CDD's role is to ensure that action is coherent, not to replace action with ceremony.

---

## 12. Practical Workflow Summary

### For a substantial change:

1. State the gap (coherence contract)
2. Run Bohmian reflection if needed
3. Score α / β / γ
4. Patch the weakest axis
5. Write or update the design
6. Write the plan
7. Write tests
8. Implement
9. Update docs
10. Release with notes
11. Observe the running system

For a small change, the coherence contract can be a single sentence in the commit message or PR description. The method scales down.

---

## 13. Governance

### 13.1 Merge governance
Per RULES.md: no self-merge. Engineer writes → PM merges. PM writes → Engineer/Owner merges.

### 13.2 Review discipline
Reviews use CLP dialogue structure (TERMS → POINTER → EXIT) and check triadic coherence. This is not additional ceremony — it is what review already means in cnos.

---

## 14. Relationship to Other Documents

| Document | Scope | Relationship to CDD |
|----------|-------|---------------------|
| FOUNDATIONS.md | Doctrine / why | CDD derives its first principle from here |
| CAP.md | Doctrine / dynamic | CDD applies CAP to development |
| COHERENCE.md | Doctrine / review | CDD uses TSC axes and CLP structure |
| CA-CONDUCT.md | Doctrine / behavior | CDD inherits "ship" and "own" |
| RULES.md | Process / governance | CDD operates within these rules |
| AGILE-PROCESS.md | Process / workflow | CDD defines the quality function |
| CAA.md | Architecture / what | CDD ensures architecture stays coherent |
| AGENT-RUNTIME.md | Runtime / how | CDD ensures runtime matches design |
| CAR.md | Distribution / how | CDD ensures packages stay coherent |

CDD is a design document. It is not doctrine — it does not define first principles. It defines how the development process applies doctrine to produce coherent systems.

---

## 15. Summary

Coherence-Driven Development means:

- starting from the real gap
- applying CAP to the development process (not just to agent runtime)
- using CLP as the review loop and dialogue structure
- formalizing coherence so it can be inspected and tested
- implementing only after coherence is good enough
- testing the invariants
- releasing only when runtime, docs, and operator story align
- observing the live system as part of the same method
- scaling down for small changes, scaling up for substantial ones

> **Development organized around reducing incoherence across thought, design, implementation, operation, and evolution.**

---

## Coherence Contract for This Document

**Gap:** cnos has doctrine (CAP, COHERENCE, CBP, CA-CONDUCT) and process (AGILE-PROCESS, RULES) but no explicit development-method document connecting them. Development coherence was implicit.

**Mode:** MCA — create the document that makes the method explicit.

**Scope:** Design layer.

**Expected effect:**
- α: development vocabulary stabilized (gap, mode, scope, triadic effect)
- β: doctrine, process, and design docs now relate through a named method
- γ: future changes can reference CDD for development coherence criteria

**Failure if skipped:** Development coherence remains implicit and taste-based. Reviews lack shared criteria. The gap between doctrine and practice widens.
