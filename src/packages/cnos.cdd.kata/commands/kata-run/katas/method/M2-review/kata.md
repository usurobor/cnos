# M2 — Review Kata

**Class:** method
**Default level target:** L6
**Purpose:** Prove review is evidence-bound and architecture-aware.

## Scenario

Given a PR diff, produce a review under two modes (baseline / CDD) and compare finding quality, evidence grounding, and architecture coverage.

## Required artifacts

- Verdict (approve / request changes)
- Evidence for each finding (line, file, artifact)
- Architecture check (§2.2.14 — 7 questions)
- Active skill consistency check
- Finding taxonomy (mechanical vs judgment)

## Scoring

- L5: findings exist, locally correct
- L6: architecture check performed, cross-surface siblings checked, evidence depth matches claim strength
- L7: higher-leverage alternative identified, process improvement shipped
