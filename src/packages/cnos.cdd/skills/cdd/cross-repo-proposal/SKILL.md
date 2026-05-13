---
name: cross-repo-proposal
description: Cross-repo proposal lifecycle protocol for satellite repo coordination with STATUS file tracking and bidirectional feedback
artifact_class: skill
kata_surface: external
governing_question: How do source repos submit executable proposals to target repos with systematic lifecycle tracking and reliable feedback flow?
visibility: internal
parent: cdd
triggers:
  - cross-repo
  - proposal
  - STATUS
scope: task-local
inputs:
  - source proposal (ISSUE.md)
  - optional patch (PATCH.diff)
  - target repo state
outputs:
  - STATUS event log
  - target issue or disposition
  - feedback to source
requires:
  - active gamma role for target-side intake
  - git transport between repos
calls:
  - issue/SKILL.md
---

# Cross-Repo Proposal Lifecycle

## Core Principle

An accepted cross-repo proposal has three durable artifacts:

1. A source proposal issue pack (`ISSUE.md`)
2. A source `STATUS` event log (append-only lifecycle tracking)
3. A target issue, commit, release artifact, rejection note, or feedback patch that points back to the source

If those three can reconstruct what happened without chat history, the lifecycle is coherent.

## Source-Side Layout

For current tsc proposals, keep the existing path:

```text
.cdd/iterations/proposals/{slug}/
  ISSUE.md
  STATUS
  PATCH.diff        # optional
```

For new repos or future cleanup, this path is also valid:

```text
.cdd/proposals/{target}/{slug}/
  ISSUE.md
  STATUS
  PATCH.diff        # optional
```

Both paths are first-class. Do not force migration just to adopt the lifecycle.

- `ISSUE.md` remains the proposal payload, compatible with CDD issue-pack shape
- `PATCH.diff` indicates a change request; without it, the proposal is an issue suggestion
- No separate type field required

## STATUS Format

`STATUS` is a small append-only event log. The current lifecycle state is the last non-comment event.

### Format

```text
# optional comments allowed
<event> <date> <refs...> [; <short note>]
```

Dates use `YYYY-MM-DD` format.

### Required Events

```text
drafted 2026-05-12
submitted 2026-05-13 source=abc1234
accepted 2026-05-13 cnos#352
modified 2026-05-13 cnos#349 ; accepted gap, changed target issue shape
landed 2026-05-15 cnos#352 commit=dc65c7e5 artifact=.cdd/unreleased/352/
rejected 2026-05-13 reason=duplicate evidence=cnos#343
withdrawn 2026-05-13 ; source no longer requests target action
```

Only `submitted` is required for target intake. Others added as target acts.

Do not rewrite old events except to fix typos in the same commit before sharing. Append corrections instead:

```text
corrected 2026-05-15 previous=landed commit=dc65c7e5 ; artifact moved to .cdd/releases/docs/2026-05-15/352/
```

### State Vocabulary

- `drafted` - source has written proposal but not requested target action
- `submitted` - source requests target intake
- `accepted` - target will act substantially as proposed and has target reference
- `modified` - target accepts gap but changes scope/split/wording/implementation/proof
- `landed` - target shipped or merged the work
- `rejected` - target declines proposal as target work
- `withdrawn` - source retracts the request

No intermediate states (`under review`, `needs author reply`, `stale`, `superseded`). If proposal no longer valid, use `rejected reason=obsolete` or submit new revision.

### Rejection Reasons

Keep small but specific:
- `duplicate`
- `already-landed`
- `not-target-owned`
- `out-of-scope`
- `insufficient-evidence`
- `obsolete`
- `too-large`

Sufficient to guide source's next action without complex taxonomy.

## Target-Side Requirements

### Accepted or Modified Proposals

When target accepts or modifies a proposal, the target issue must include:

```markdown
## Source Proposal

- Source: `tsc:.cdd/iterations/proposals/cdd-ci-green-gate/`
- Source commit: `abc1234`
- Disposition: `accepted`
```

For modified proposals:

```markdown
## Source Proposal

- Source: `tsc:.cdd/iterations/proposals/operator-access-flow/`
- Source commit: `abc1234`
- Disposition: `modified`
- Delta: accepted the gap, changed subsection placement and proof plan.
```

Target issue becomes target-system authority after acceptance. Source proposal remains lineage and intent, not binding implementation contract.

### Rejected Proposals

If target rejects proposal and can write to source repo, append `rejected` line to source `STATUS`.

If target cannot write to source repo, emit patch that updates source `STATUS`.

If rejection needs explanation beyond one line, target may create:

```text
.cdd/proposals/inbound/{source}/{slug}/DISPOSITION.md
```

Optional directory, not required for normal accepted proposals.

### Landed Proposals

When target work lands, append `landed` line to source `STATUS` with:
- target issue or cycle reference
- landed commit
- artifact path if available

Example:

```text
landed 2026-05-15 cnos#352 commit=dc65c7e5 artifact=.cdd/unreleased/352/
```

`landed` means target work merged or became target truth. Does not wait for release movement out of `.cdd/unreleased/`; artifact path correctable later with `corrected` event.

## Transport

Use git. No external service required.

### Submission

1. Source commits `ISSUE.md` and `STATUS`
2. Source appends `submitted <date> source=<sha>` to `STATUS`
3. Source either:
   - Leaves on main where target scans
   - Pushes proposal branch
   - Sends patch

### Feedback

1. If target has write access to source repo, commit `STATUS` update directly
2. If not, write `git format-patch` patch that updates `STATUS`
3. Target issue or disposition note links back to source proposal

Branch names may help discovery but are not lifecycle state.

## Target Intake Algorithm (Gamma/Sigma)

During target selection:

1. **Scan** known source repos for active proposal paths:
   - `.cdd/iterations/proposals/*/STATUS`
   - `.cdd/proposals/{target}/*/STATUS`
2. **Consider** proposals whose last event is `submitted`
3. **Read** adjacent `ISSUE.md` and optional `PATCH.diff`
4. **Check** target state for duplicates or already-landed work
5. **Decide** one of: `accepted` / `modified` / `rejected`
6. **Create** target issue with source block (if accepted/modified)
7. **Update** source `STATUS` or emit patch if source not writable
8. **During close-out**, append `landed` to source `STATUS` or emit patch

Critical rule: once target decides, source proposal must not remain at `submitted`.

## Modification Policy

Use `modified` for "yes to governing gap, no to exact proposal."

Examples:
- Target splits one source proposal into multiple target issues
- Target folds proposal into existing issue
- Target changes acceptance criteria materially
- Target changes implementation design
- Target applies only part of `PATCH.diff`
- Target rewrites wording (files moved, invariants changed)

`modified` line must include short note:

```text
modified 2026-05-13 cnos#349 ; split operator access flow from activation cleanup
```

If delta cannot be explained in one line, add target issue note or optional `DISPOSITION.md`.

Do not use `modified` for template normalization, title cleanup, label changes, AC renumbering, or path spelling fixes.

## Source Revisions

After `submitted`, source should not materially rewrite `ISSUE.md` in place.

Allowed:
- Typo fixes
- Link fixes
- Appending revision note

If governing gap changes, create new proposal slug. If only details change:

```text
revised 2026-05-14 source=def5678 ; narrowed AC2 after target feedback
submitted 2026-05-14 source=def5678
```

Prevents target from accepting one proposal while source silently changes it.

## Examples

### New Submitted Proposal

```text
drafted 2026-05-12
submitted 2026-05-13 source=abc1234
```

### Accepted and Landed as Written

```text
drafted 2026-05-12
submitted 2026-05-13 source=abc1234
accepted 2026-05-13 cnos#352
landed 2026-05-15 cnos#352 commit=dc65c7e5 artifact=.cdd/unreleased/352/
```

### Accepted with Target Changes

```text
drafted 2026-05-12
submitted 2026-05-13 source=abc1234
modified 2026-05-13 cnos#349 ; accepted gap, changed subsection placement and proof plan
landed 2026-05-15 cnos#349 commit=7a93d821 artifact=.cdd/unreleased/349/
```

### Rejected (Already Landed)

```text
drafted 2026-05-12
submitted 2026-05-13 source=abc1234
rejected 2026-05-13 reason=already-landed evidence=cnos#343
```

## Non-Goals

Do not add these yet:
- Mandatory target mirrors
- YAML frontmatter status records
- Generated proposal indexes
- CI validators
- New `cn proposal` commands
- Forced path migration
- Review-board states

Add automation only after agents follow manual protocol consistently enough to reveal stable friction.

## Integration with CDD Skills

This skill is called by:
- `gamma/SKILL.md` during observation (§2.1) and close-out (§2.7)
- `post-release/SKILL.md` during pre-publish gate verification
- `issue/SKILL.md` when target issues need source proposal attribution

For skill patches and iteration improvements targeting this protocol, follow standard CDD cycle iteration rules (CDD.md §9.1).