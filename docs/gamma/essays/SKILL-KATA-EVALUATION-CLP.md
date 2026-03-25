# SKILL-KATA-EVALUATION — CLP v1.0.1

**Changelog:** v1.0.1 — tightened the scope, surfaced the decisive comparison, and made the next action explicit.

**Pattern:** A skill is real when it changes the shape of failure across related tasks, not when it rescues one prompt.

**Relation:** The evaluator is testing both the skill and the discipline of choosing the right governing skills, against both no-skill and skill-soup baselines.

**Exit:** Run cold / all-plausible / selected-governing arms across repair / transfer / negative-control tasks, score α/β/γ plus efficiency, then classify the limit and decide whether to keep, shrink, replace, or redesign the skill.

---

## TERMS

A **real skill** is one that changes failure shape, not merely score on a single repaired prompt.

**Repair** is rerunning the same task after loading the skill. **Transfer** is performance on a different but isomorphic task from the same family. A **negative control** is a task from a different family used to catch overfitting.

**Governing skills** are the 2–3 skills chosen in advance as the task's intended governors; **skill soup** is loading every plausible skill.

**Cost** means tokens, latency, rounds, and extra artifact overhead.

The essay's base claim is that many failures are not skill problems at all; they may instead be knowledge, selection, context, or architecture problems.

---

## POINTER

The central move is to evaluate on **two contrasts at once**.

First, compare arms: cold, all plausible skills, and selected governing skills.

Second, compare stages: task A for repair, task B for transfer, task C for negative control.

That turns the experiment from "did the model obey a better prompt?" into "did the model acquire a reusable method?"

The strongest positive signal is improvement on both A and B — especially when selected governing skills outperform skill soup without blowing up efficiency — because that shows a governing pattern rather than mere context stuffing.

---

## EXIT

Standardize the experiment. Each kata packet should carry the task, hidden rubric, failure family, expected governing skills, hidden checks, and α/β/γ/efficiency scoring. Each run record should capture model settings, loaded skills, token count, latency, attempts, artifacts, per-axis scores, and failure notes.

Start with the three families the essay recommends: local coding correctness, cross-surface coherence, and architecture / leverage.

Then classify each outcome as **knowledge-limited**, **process-limited**, **selection-limited**, **context-limited**, or **architecture-limited**.

That classification is the exit condition for action:

- **keep** the skill if it transfers cheaply
- **tighten** it if cost explodes
- **swap** the selected skills if selection was wrong
- **stop treating the problem as a skill problem** when the blockage is architectural
