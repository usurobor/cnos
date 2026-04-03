# PLAN-v3.32.0-thread-event-model

## Implementation Plan for the Thread Event Model

**Status:** Draft
**Implements:** docs/alpha/protocol/THREAD-EVENT-MODEL.md
**Issue:** #153
**Depends on:** docs/alpha/protocol/MESSAGE-PACKET-TRANSPORT.md, inbox processing, peer sync, Git-first transport

**Purpose:** Introduce a canonical thread-event layer above packet transport so cnos can support thread discovery, replies/comments, participant propagation, and human-readable thread projections without making thread files or inbox projections authoritative.

---

## 0. Coherence Contract

### Gap

cnos already has:

- validated packet transport
- thread-like markdown files under `threads/`
- inbox triage that expects one actionable item in `state/input.md`

But it does not yet have one canonical semantic object for:

- thread opens
- replies/comments
- participant discovery
- owner notification
- projection updates
- actionability routing

This leaves the system too flat:

- packet = transport unit
- thread file = human-readable artifact
- inbox = actionable projection

The missing piece is the semantic unit that relates them all.

### Mode

MCA — add a thread-event model and route packets through it before projection/materialization.

### α / β / γ target

- α PATTERN: one canonical semantic unit (`thread_event`) above packet transport
- β RELATION: packet transport, event routing, event store, thread projections, and inbox all describe the same conversation state
- γ EXIT: thread opens, replies, participant updates, and feed discovery become mechanically routable without the agent reasoning about transport or persistence

### Smallest coherent intervention

Do not redesign packet transport. Keep:

- packet validation
- Git-first transport
- pre-materialization safety

Add:

- canonical thread-event derivation
- local event store
- feed/inbox routing refs
- derived thread and inbox projections

---

## 1. Scope

### In scope

- thread-event schema
- packet envelope thread metadata
- event derivation from validated packets
- local thread-event store
- feed discovery refs
- inbox routing refs
- participant/subscription routing
- actionable event classification
- thread markdown projections
- skill/doc/runtime updates to reflect the new model

### Out of scope

- reflection unification
- attachments / multipart payloads
- non-Git transport adapters
- rich feed UI
- ranking / recommendation
- advanced access-control UX
- migration of all historical thread files in v1

---

## 2. Delivery Strategy

Deliver in three implementation slices.

### Phase 1 — Canonical event layer

Goal:
- every conversational packet derives exactly one canonical `thread_event`

### Phase 2 — Routing and persistence

Goal:
- route events to owners/participants/subscribers and persist them before any projection

### Phase 3 — Projection and actionability

Goal:
- materialize thread markdown and inbox items from the event store, with clear actionability rules

---

## 3. Phase 1 — Canonical Event Layer

## Step 1 — Extend packet envelope with thread-event metadata

### Goal

Make thread semantics transport-authoritative in the envelope.

### Work

Extend the packet envelope with fields such as:

- `thread_id`
- `root_event_id`
- `reply_to_event_id`
- `event_kind`
- `visibility`
- `audience`

### Rules

- `event_id` = `msg_id`
- `root_event_id` = `event_id` for Open
- `reply_to_event_id` required for Reply
- `thread_id` stable across all events in a thread
- markdown frontmatter in `message.md` is never authoritative for routing or thread semantics

### Acceptance

- packet validation rejects malformed or inconsistent thread metadata
- thread semantics are no longer inferred from filenames or markdown structure

### Likely files

- `src/transport/cn_packet.ml`
- packet tests
- packet docs

---

## Step 2 — Add thread-event derivation module

### Goal

Create a canonical semantic type above validated packets.

### Work

Add a new module, for example:

- `src/transport/cn_thread_event.ml`

It should define:

- `thread_event_kind`
- `visibility`
- `audience`
- `thread_event`
- derivation function from validated packet → `thread_event`

### Acceptance

- every validated conversational packet can derive exactly one `thread_event`
- non-conversational packets reject or are explicitly out of scope
- semantic event identity is explicit and detached from transport implementation details

### Tests

- open event derivation
- reply event derivation
- malformed event-kind / missing reply target rejection
- envelope/payload mismatch rejection carries through

---

## Step 3 — Define canonical local event storage

### Goal

Persist semantic truth before projections.

### Work

Add a local store such as:

```text
state/thread-events/{thread_id}/{event_id}.json
```

Each stored event should be:

- canonicalized JSON
- keyed by `thread_id` + `event_id`
- derived only from validated packets

### Acceptance

- local semantic truth exists independently from thread markdown projections
- packet validation and event derivation always happen before event-store writes

### Likely files

- `src/transport/cn_thread_event.ml`
- local storage helpers
- tests

---

## 4. Phase 2 — Routing and Persistence

## Step 4 — Add feed discovery refs

### Goal

Let peers discover what threads another peer posted.

### Work

For top-level Open events, publish feed refs such as:

```
refs/cn/feed/{author}/{event_id}
```

These refs point to the same canonical packet commit as the message packet ref.

### Rules

- Open events always appear in the author feed
- Replies may appear depending on visibility policy
- Feed refs are discovery projections, not canonical semantic truth

### Acceptance

- a follower can discover a peer's posted threads without reading arbitrary markdown files
- feed projections are derived from canonical event packets

### Likely files

- `src/cmd/cn_mail.ml`
- peer sync/fetch logic
- tests

---

## Step 5 — Add inbox routing refs

### Goal

Make sure owners and routed participants learn about replies/comments mechanically.

### Work

For every routed event, publish inbox refs such as:

```
refs/cn/inbox/{recipient}/{event_id}
```

These refs point to the same canonical packet commit.

### Default routing rules

**Always route replies/comments to:**

- thread owner (`root_event.author`)
- all current participants
- explicit mentions

**Optionally route to:**

- subscribers
- feed followers if visibility allows

### Acceptance

- the thread owner always learns of replies to their thread
- participants can learn of thread updates without ad hoc routing logic
- routing occurs below the agent

### Likely files

- `src/cmd/cn_mail.ml`
- maintenance/sync logic
- tests

---

## Step 6 — Add subscription state

### Goal

Support "how do other peers know about replies/comments on threads they care about?"

### Work

Add local subscription state such as:

```
state/thread-subscriptions.json
```

Auto-subscribe:

- thread owner
- anyone who authored an event in the thread
- explicit mentions
- operator-manual subscriptions

### Acceptance

- cnos can route thread updates to interested peers without requiring them to follow every author feed
- subscription state remains local and explicit

### Likely files

- subscription storage helpers
- route computation code
- docs/tests

---

## Step 7 — Fetch/process feed and inbox refs

### Goal

Turn packet refs into semantic events and local state.

### Work

Update the receiver path to:

1. fetch feed refs and inbox refs
2. validate packet
3. derive thread event
4. store thread event
5. update feed/thread projections
6. classify actionability
7. optionally write `state/input.md`

**Important rule:** Routing/persistence happen in cnos. The agent does not scan feeds, routes, or event stores.

### Acceptance

- packet validation still happens before any write
- event store is updated before projections
- thread discovery and inbox delivery use the same canonical event path

### Likely files

- `src/cmd/cn_mail.ml`
- `src/cmd/cn_maintenance.ml`
- packet/event store tests

---

## 5. Phase 3 — Projection and Actionability

## Step 8 — Add thread projection builders

### Goal

Make human-readable thread files derived artifacts.

### Work

Create/rebuild projections such as:

- `threads/mail/inbox/{thread_id}.md`
- `threads/mail/outbox/{thread_id}.md`
- `threads/adhoc/{thread_id}.md`

Projection rules:

- thread markdown is derived from the event store
- ordering comes from event timestamps / event graph
- derived frontmatter must come from event metadata, not independent local guesses

### Acceptance

- thread markdown is never the semantic authority
- projections can be rebuilt from the event store

### Likely files

- projection module
- thread markdown tests
- docs

---

## Step 9 — Add actionable event classification

### Goal

Preserve the current inbox model: one actionable item to the agent, not routing mechanics.

### Work

Define what events are actionable:

**Default actionable examples:**

- direct message to local agent
- reply on a locally-authored thread
- explicit mention requiring response
- coordination/review requests

**Default non-actionable examples:**

- passive feed discoveries
- thread updates with no local obligation
- participant-only updates that do not require response

**Actionable event flow:**

- derive event
- persist event
- then if actionable:
  - materialize one `state/input.md` item

### Acceptance

- `state/input.md` remains a derived actionable projection
- agent still sees one triaged item, not the raw routing fabric
- non-actionable updates do not wake the agent unnecessarily

### Likely files

- `src/cmd/cn_mail.ml`
- inbox skill docs
- tests

---

## 6. Docs and Skill Updates

## Step 10 — Align docs

### Update

- `docs/alpha/protocol/MESSAGE-PACKET-TRANSPORT.md`
  - clarify that conversational packets carry thread-event metadata
- `docs/reference/GLOSSARY.md`
  - distinguish:
    - packet
    - thread event
    - thread projection
    - feed projection
- `docs/alpha/AGENT-RUNTIME.md`
  - clarify inbox/actionability remains derived
- `packages/.../ops/inbox/SKILL.md`
  - inbox items are actionable thread events
- `packages/.../ops/peer/SKILL.md`
  - peers exchange packet refs/feed refs/inbox refs, not arbitrary thread files

### Acceptance

The docs graph describes one coherent model:

- packet
- event
- projection

---

## 7. Tests

### Unit / schema tests

- thread metadata presence/shape in envelope
- event derivation from valid packet
- malformed thread metadata rejection
- reply requirements (`reply_to_event_id`) enforced

### Routing tests

- open event goes to author feed
- reply routes to owner + participants + mentions
- subscriber receives thread update
- visibility rules respected

### Persistence tests

- validated packet produces event-store entry
- invalid packet does not produce any event-store entry
- duplicate event does not duplicate event-store state
- equivocation rejects before store write

### Projection tests

- thread markdown rebuild from event-store
- inbox projection only for actionable events
- feed projection reflects opens and allowed replies

### Integration tests

- sender posts thread → follower sees it in feed projection
- follower replies → owner receives reply through inbox routing
- participant receives reply on subscribed thread
- non-actionable update does not wake agent

---

## 8. CI / Release Gating

Before release:

- envelope/thread metadata tests green
- event-derivation tests green
- routing tests green
- persistence/projection tests green
- inbox actionability tests green
- docs/skill updates landed
- no duplicate authority surface remains between packet, event, and projection

---

## 9. Non-goals

This implementation plan does not include:

- reflection unification
- alternate transports (chain/mailbox/nostr)
- feed ranking or social UI
- attachment support
- rich subscription UX
- migration of all historical threads in Phase 1

Those can be layered later.

---

## 10. Acceptance Criteria

This implementation line is complete when:

1. Every conversational packet derives exactly one validated `thread_event`
2. Thread opens are discoverable through actor feed projection
3. Replies/comments are represented as explicit Reply events with `reply_to_event_id`
4. Thread owners always receive replies/comments on their threads through inbox routing
5. Participants/subscribers can receive thread updates without ad hoc routing
6. `state/input.md` is produced only for actionable events
7. Thread markdown files are derived projections, not semantic authority
8. Packet validation still happens before any event-store write or projection update
9. A peer can discover what threads another peer posted without reading arbitrary markdown files from the repo
10. The agent never needs to reason about transport refs, feed refs, or persistence mechanics

---

## 11. Known Debt

- Reflections remain outside the unified thread-event model in v1
- Feed pagination and indexing are deferred
- Migration of legacy thread files is deferred
- Notification policy may need a separate runtime-policy document
- Participant/subscription UX is intentionally minimal in v1

---

## 12. Summary

This plan introduces the missing semantic layer between:

- validated packet transport
- and human-readable thread files / inbox items

The resulting stack becomes:

1. **Packet** — transport truth
2. **Thread event** — semantic truth
3. **Projection** — human/actionable views

That is the smallest coherent move that supports:

- peer thread discovery
- replies/comments
- owner notification
- participant propagation
- and agent isolation from routing mechanics
