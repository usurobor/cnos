<!-- sections: [framing, runner-shape, delta-naming, cdw-generalization, dependencies, what-is-generic, error-handling, mechanization-claim, issue-sequence, design-issue-shape, key-rule, bottom-line] -->
<!-- completed: [framing, runner-shape, delta-naming, cdw-generalization, dependencies, what-is-generic, error-handling, mechanization-claim, issue-sequence, design-issue-shape, key-rule, bottom-line] -->

# γ design proposal — bounded triad runner over identity-task dispatch

**Author:** γ (`gamma@cdd.cnos`)
**Date:** 2026-05-02
**Anchor release:** 3.74.0
**Status:** draft (design proposal — no issue filed yet; see §issue-sequence)
**Depends on:** #310 (bounded identity-task dispatch), #311 (triadic-agent contract)

## Framing

Yes. This is likely the next coherent abstraction.

#310 gives cnos a bounded identity-task dispatch primitive.
A triad runner would compose those dispatches into a finite workflow:

```
choose next role
dispatch role
observe result/artifacts
validate required outputs
retry / repair / escalate / close
```

The important point: this is still not a full agent runtime. It is a small,
reentrant state machine that runs bounded role calls. #310 already frames the
core primitive as single-agent multi-agency: bounded identity tasks, no
persistent subagents, no scheduler, no message bus, and no session pool in v0.

### The best framing

I would call it something like:

```
triad runner
```

or:

```
bounded triad runner
```

Not:

```
CDD runner
```

because CDD is only the first profile.

The generic pattern is:

```
Triad runner
  core finite-state runner
CDD profile
  α implementer
  β reviewer/integrator
  γ coordinator
  δ release/error/external gate resolver
CDW profile
  writer
  document reviewer/editor
  coordinator/publisher
  δ external gate/error resolver
```

So the split becomes:

```
cn dispatch
  runs one bounded identity task
triad runner
  decides which bounded identity task to run next
CDD
  supplies a profile for development cycles
CDW
  supplies a profile for writing/document cycles
```

That is the clean architecture.

## Runner shape

The runner should be boring. Something like:

```
load triad profile
initialize run state
while not closed:
  select next role
  build role prompt
  call cn dispatch
  record attempt
  validate artifacts
  choose next transition
  if unexpected failure:
    route to δ
close with witness
```

In other words, it is closer to an event loop than a daemon.

```
γ / runner schedules α
α runs and returns
γ / runner schedules β
β runs and returns
γ / runner decides:
  retry
  repair
  escalate
  close
```

Roles do not poll. Roles do not stay alive. The runner owns the loop.

## δ should be carefully named

I would not casually redefine δ as "triad dispatcher" without separating two
meanings.

In CDD today, δ is the external boundary / operator / release-gate executor.
CDD's role model distinguishes α implementation, β review/integration, γ
coordination, and δ external boundary execution.

For a generic triad runner, δ could mean:

```
external resolver
```

not:

```
the ordinary scheduler
```

I would keep the scheduler as the runner itself, and use δ only when the runner
hits something it cannot resolve internally:

```
backend unavailable
role failed repeatedly
artifact contract impossible
authority missing
release/deploy/tag needed
operator judgment required
unexpected state
```

So:

```
runner = mechanical event loop
γ = cognitive coordinator role, when needed
δ = external gate / exception resolver
```

That avoids making δ both the dispatcher and the release manager.

## Why this generalizes to CDW

CDW has the same shape.

For a writing artifact:

```
writer role
  drafts or revises
document-review role
  reviews whole artifact coherence
coordinator role
  decides accept / revise / escalate / close with debt
```

The CDW issue already frames CDW as the document-lifecycle package, with write
as the local writing primitive and CDW as the package that owns document review
and self-review.

A CDW runner profile could be:

```
state: orient
  determine document kind, authority, audience, source map
state: draft
  dispatch writer
state: self_review
  dispatch writer self-review or run checklist
state: document_review
  dispatch document-review
state: repair
  re-dispatch writer with review findings
state: close
  produce artifact witness
```

That is the same event-loop pattern as CDD.

## Dependencies — the runner should depend on #310 and #311

I would not build the triad runner before #310 and #311 are settled.

The dependency chain should be:

```
#311 triadic-agent contract
  defines what a coherent run owes:
  orientation / intervention / witness
#310 bounded identity-task dispatch
  defines how to call one identity once and record an attempt
triad runner
  composes bounded identity-task attempts under a profile
CDD / CDW
  provide profiles and artifact contracts
```

#311's job is to define the generic run contract:
`tri(orientation, intervention, witness)`, while #310 is the dispatch
mechanism. They are intentionally separate.

The runner should use both:

```
orientation
  issue/doc/task/profile state
intervention
  sequence of dispatch attempts
witness
  artifacts, attempt records, close-outs, review verdicts, debt
```

## What is generic

A triad runner should not know CDD-specific names.

It should know:

```
roles
states
transitions
required artifacts
attempt records
retry policy
failure routing
closure conditions
```

A profile supplies:

```yaml
name: cdd
roles:
  alpha:
    prompt_template: ...
    required_outputs:
      - self-coherence.md
      - alpha-closeout.md
  beta:
    prompt_template: ...
    required_outputs:
      - beta-review.md
      - beta-closeout.md
  gamma:
    prompt_template: ...
    required_outputs:
      - gamma-closeout.md
  delta:
    kind: external_resolver
transitions:
  start -> alpha
  alpha.completed -> beta
  beta.repair_needed -> alpha
  beta.accepted -> gamma
  gamma.ready_for_release -> delta
```

For CDW:

```yaml
name: cdw
roles:
  writer:
    required_outputs:
      - draft
      - writer-self-review
  document_review:
    required_outputs:
      - document-review
  coordinator:
    required_outputs:
      - closure
transitions:
  start -> writer
  writer.completed -> document_review
  document_review.repair_needed -> writer
  document_review.accepted -> coordinator
```

The runner stays generic. Packages own profiles.

## Unexpected error handling

This is where δ becomes valuable.

The runner should classify failures before escalating:

```
role failure:
  role returned failed descriptor
artifact failure:
  required artifact missing
backend failure:
  Claude CLI unavailable, timeout, bad exit
state failure:
  branch/worktree mismatch, dirty tree, missing issue
policy failure:
  profile has no transition for observed result
authority failure:
  needs tag/deploy/secrets/operator judgment
```

Then:

```
retry automatically only if policy allows
otherwise:
  produce δ request
```

A δ request should look like:

```json
{
  "kind": "delta_request",
  "run_id": "...",
  "profile": "cdd",
  "state": "beta_review",
  "failure_kind": "missing_required_artifact",
  "failed_role": "alpha",
  "required_artifact": "alpha-closeout.md",
  "attempts": ["..."],
  "available_next_moves": [
    "redispatch alpha",
    "mark debt",
    "operator override"
  ],
  "recommended_next_move": "redispatch alpha"
}
```

That makes δ resolution explicit and auditable.

## Do not call it "fully mechanized CDD" too early

I would avoid claiming full mechanization until the runner can prove these
things:

```
role dispatch works
attempt records persist
artifact validation works
retry policy works
δ request path works
closure gate works
```

The first implementation should be:

```
triad-runner v0
  non-daemon
  local repo only
  one run at a time
  Claude CLI backend through cn dispatch
  profile-driven
  no background polling
  no remote workers
```

That is enough.

## Suggested issue sequence

I would not put this into #310 or #325.

File a new issue after #310/#311 are stable, or file now as a design issue:

```
design(core): define bounded triad runner over identity-task dispatch
```

Then implementation:

```
tools(core): implement triad runner v0 with CDD profile
```

Then CDW:

```
package(cdw): add writer/reviewer/coordinator triad profile
```

## First design issue shape

The design issue should answer:

```
What is a triad runner?
What is a profile?
What does the runner own?
What does the package own?
What is δ?
What failures are automatic retry vs δ escalation?
How does this relate to #310 and #311?
How does CDD bind it?
How does CDW bind it?
```

Non-goals:

```
no daemon
no scheduler service
no remote workers
no persistent subagents
no role polling
no CTB interpreter
```

## The key rule

The cleanest rule is:

```
A triad runner does not keep agents alive.
It keeps the run state alive.
```

That is the central design.

```
agents/roles:
  invoked temporarily
run state:
  durable
artifacts:
  durable
attempt records:
  durable
δ requests:
  durable
coordinator:
  selected by state/profile, not hidden in chat
```

This is exactly why CDD and CDW can share it.

## Bottom line

Yes, CDD can probably be mechanized.

But the general primitive is not "CDD runner." It is:

```
profile-driven bounded triad runner
```

with:

```
#310 = call one role
#311 = define what a coherent run owes
triad runner = compose role calls into a state machine
CDD/CDW = profiles over the runner
δ = external resolver for failures/authority/gates
```

That is the next abstraction. It would turn "single-agent multi-agency" from a
pattern into an executable process while still avoiding a full always-on
runtime.
