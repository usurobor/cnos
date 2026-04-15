---
name: cdd
description: Coherence-Driven Development. Use for substantial changes that require explicit selection, artifact flow, review, release, and post-release closure.
artifact_class: skill
kata_surface: embedded
governing_question: How do we evolve a system through a substantial change without losing coherence across selection, implementation, review, release, and closure?
triggers: [review, PR, release, issue, design, plan, assess, post-release, ship, tag]
---

# CDD

## Load order

This skill is a loader entrypoint. When CDD applies:

1. Load `CDD.md` in this directory as the canonical algorithm
2. Load all required cdd/* sub-skills referenced by that algorithm
3. Load Tier 2 and Tier 3 skills as directed by the issue and work shape

## Rule

`CDD.md` is the only normative source for:

- roles (§1.4)
- lifecycle (§3)
- selection (§2)
- artifact contract (§5)
- skill loading tiers (§4.4)
- gates (§4)
- closeout (§10)
- cycle iteration (§9.1)
- dispatch prompt format (§1.4)

This file does not restate the method. It only tells the runtime and operator what to load.

## Sub-skills

- `design/` — design artifact production
- `issue/` — issue creation and structure
- `plan/` — implementation planning
- `review/` — code review protocol
- `release/` — merge, tag, deploy
- `post-release/` — assessment and closure

## Conflict rule

If this file and `CDD.md` appear to disagree, treat that as a packaging error: the source of truth is `CDD.md`.
