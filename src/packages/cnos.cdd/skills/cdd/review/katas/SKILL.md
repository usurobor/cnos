---
name: review/katas
description: Review practice scenarios — contract integrity, implementation review, and checker PR review.
artifact_class: reference
kata_surface: embedded
governing_question: What review practice scenarios train β to catch contract and implementation incoherence?
visibility: internal
parent: review
triggers:
  - review kata
scope: task-local
inputs: []
outputs: []
requires: []
calls: []
---

# Review Katas

## 8.1 Kata — First-round review

**Scenario:** An LLM branch adds a new CLI provider.

Perform:
1. §2.0.0 Contract integrity preflight.
2. §2.0 Issue contract tables (ACs, named docs, CDD artifacts).
3. §2.1 Diff inspection.
4. §2.2 Architecture check (if touched).
5. State verdict.

**Verify:** Did you complete §2.0.0 before the diff? Did you enumerate input sources at security-level rigor for the closure claim? Does every finding trace to a line, file, or artifact?

---

## 8.2 Kata — Review a checker PR

**Scenario:** A branch adds a CUE validation gate with a CI job. The issue says `scope` is a hard-gate field, but the exception file allows `"allowed_missing": ["scope"]`. The CI job is added but notification aggregation is not updated. The PR body says "the runtime now enforces frontmatter compliance."

Review it using §2.0.0 Contract Integrity Preflight.

1. **Status truth:** PR body says "runtime enforces" — is that shipped or planned? → D finding (contract): false runtime claim.
2. **Constraint strata:** Hard gate `scope` appears in exception `allowed_missing` — contradiction. → D finding (contract): exception exempts hard gate.
3. **Cross-surface projections:** CI job I5 added but notify job aggregation unchanged. → C finding (mechanical): operator-visible projection missing.
4. **Proof shape:** Are there negative fixtures? Does the checker reject a file missing `scope`? If not, → C finding (contract): proof plan incomplete.
5. **Scope/non-goal consistency:** Issue says "non-goal: runtime enforcement." PR body says "runtime now enforces." → D finding (contract): non-goal violated in PR body.

**Verify:** Did you complete §2.0.0 before reading the diff? Did you catch all five contract violations? Would approving this branch ship a false runtime claim?

---

## 8.3 Kata — Review a docs alignment PR

**Scenario:** A branch updates the root README and docs README to reflect a new project framing. The PR changes link paths from `doctrine/MANIFESTO.md` to `essays/MANIFESTO.md`. The PR body says the layer diagram uses sibling `├─` architecture, but the diff still shows nested `└─`.

1. **Source-of-truth map:** Do both READMEs point to the same canonical `essays/` path? Grep for the old `doctrine/MANIFESTO.md` path across all live docs.
2. **PR body / branch consistency:** PR body describes sibling diagram but files still show nested. → C finding (contract): PR body does not match branch files.
3. **Cross-surface projections:** Link checker CI job — does it cover the new paths?
4. **Status truth:** Does the README correctly label draft, current, and shipped surfaces?

**Verify:** Did you check both README files, not just the root? Did you verify the link checker covers the changed paths?
