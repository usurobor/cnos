# M1 — Design Kata

**Class:** method
**Default level target:** L6
**Purpose:** Prove design artifacts are complete and traceable.

## Scenario

Given a bounded change request, produce a design under two modes (baseline / CDD) and compare artifact completeness and traceability.

## Required artifacts

- Named incoherence (what gap exists)
- Impact graph (what the change touches)
- Acceptance criteria (testable)
- CDD trace (observation → selection → mode → artifacts)

## Scoring

Scored by the judge against rubric.json. Level derivation:
- L5: ACs exist, change is locally correct
- L6: cross-surface impact named, sibling consistency checked
- L7: architecture boundary moved, class of future work eliminated
