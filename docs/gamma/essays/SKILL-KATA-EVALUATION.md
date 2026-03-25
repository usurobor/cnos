# Skill Kata Evaluation Framework

**Source:** Claude, post-PR #111 reflection on skill effectiveness measurement
**Date:** 2026-03-25
**Context:** After CDD §4.4 (skill selection as generation constraint), the question becomes: how do you know a skill actually works?

---

## Core Question

Does loading a skill change the shape of failure, or just patch one prompt?

---

## The Key Distinction

Not all agent failures are process gaps. A skill can only help if the gap is actually a method / constraint / decomposition gap. If it doesn't help, the gap is more likely:

- missing domain knowledge
- wrong skill selection
- skill too shallow
- context-cost too high

A kata program is the cleanest way to separate those.

---

## Experiment Design

### 1. Measure Three Things, Not One

**A. Repair**
Give the agent a kata, let it fail, then load the selected skill(s), and rerun the same kata. This tells you: can the skill repair the immediate failure?

**B. Transfer**
Then give it a different but isomorphic kata from the same family. This tells you: did the skill teach a pattern, or just repair one prompt?

**C. Cost**
Measure:
- tokens added
- latency added
- number of rounds needed
- whether the score gain was worth the added context burden

This is where process-economics matters.

### 2. Use Three Experimental Arms

**Arm 1 — Cold**
No special skills loaded.

**Arm 2 — All plausible skills**
Load everything that might help.

**Arm 3 — Selected governing skills**
Load only the 2–3 governing skills chosen explicitly before the attempt.

That directly tests the hypothesis: selected deep skills > skill soup.

If Arm 3 beats Arm 2, you've proven something important.

### 3. Score on Multiple Axes

**α Pattern**
- correctness
- internal consistency
- absence of obvious contradictions
- whether the output follows required structure

**β Relation**
- does it respect the surrounding architecture / docs / contracts?
- does it align with the real source of truth?
- does it preserve cross-surface parity?

**γ Exit**
- does it create a viable next state?
- does it leave behind useful artifacts?
- does it avoid future debt?
- does it choose the right next move?

**Efficiency**
- tokens
- latency
- number of review rounds
- number of corrective prompts
- amount of extra artifact overhead

A skill that improves correctness by 2% while doubling prompt size may not be worth it.

---

## The Most Important Methodological Refinement

Don't evaluate only on the same kata. If you only do fail → load skill → rerun same kata, you are mostly measuring repair under instruction, not real skill gain.

Use:

| Stage | Task | Measures |
|-------|------|----------|
| 1 | Cold task A | Baseline |
| 2 | Skill-loaded task A | Repair |
| 3 | Skill-loaded task B (same family, unseen) | Transfer |
| 4 | Skill-loaded task C (different family, negative control) | Overfitting check |

This gives you:
- A → A = repair
- A → B = transfer
- B → C = overfitting check

---

## Interpreting Results

| Observation | Interpretation |
|-------------|---------------|
| Score improves on A but not B | Skill is too prompt-local or example-bound |
| Score improves on A and B | Skill teaches a reusable pattern |
| Score improves on A and B but cost explodes | Skill is useful but too big / verbose / broad |
| No improvement even on A | Skill is weak, wrong skill selected, knowledge gap, or model can't use it |

Classify each result as:
- **knowledge-limited** — the model doesn't know something the skill can't teach
- **process-limited** — the skill addresses the right gap
- **selection-limited** — the wrong skill was chosen
- **context-limited** — the skill helps but costs too much context
- **architecture-limited** — the task needs a system change, not a skill

That classification is more useful than just pass/fail.

---

## Skill Selection as Part of the Experiment

For each kata, require the evaluator to write:

**Governing skills hypothesis:**
- which 2–3 skills should govern this kata
- why those and not others
- what failure class each one is supposed to prevent

Then compare selected skills vs all plausible skills vs no skills. Now you are evaluating not just the skill, but the skill-selection discipline. That is probably the real missing step.

---

## Kata Packet Format

Each kata should include:
- task statement
- hidden evaluation rubric
- failure family
- expected governing skills
- hidden tests / checks
- scoring rubric across α / β / γ / efficiency

## Run Record Format

Each run should record:
- model
- temperature
- skill set loaded
- token count
- latency
- number of attempts
- output artifacts
- score per axis
- failure notes

---

## Recommended First Three Kata Families

### 1. Local Coding Correctness

Good for: coding, testing, OCaml/language-specific skills.

Examples: type safety, exhaustive matching, functional purity, error handling.

### 2. Cross-Surface Coherence

Good for: review, documentation/system-contract parity, runtime contract / JSON↔markdown / issue AC checks.

Examples: authority-surface conflict detection, multi-format parity, stale cross-reference detection.

### 3. Architecture / Leverage

Good for: design, architecture-evolution, process-economics.

Examples: repeated pressure recognition, boundary-move generation, process overhead pricing.

---

## What You Should Expect

A good result looks like:
- coding/testing skills improve local correctness kata
- review skill improves detection / AC coverage / parity kata
- architecture-evolution improves leverage / abstraction-choice kata
- process-economics reduces over-ceremony and improves net efficiency

If one skill claims to help everything, that's usually a warning sign.

---

## Summary

This is not just benchmarking agents. It is: **measuring whether a skill changes the shape of failure.**

The real question is not "did the score go up?" It is: **"did the agent stop failing in the same way?"**

That is how you know a skill is real.
