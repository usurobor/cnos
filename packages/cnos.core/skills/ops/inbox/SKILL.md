---
name: inbox
description: Process inbound peer messages. Triage each message, respond or archive, maintain continuity across sessions.
triggers:
  - heartbeat detects new inbox messages
  - cn agent invoked with state/input.md present
  - peer sends review request, question, ping, or coordination message
  - inbox backlog needs clearing
---

# Inbox

Process inbound peer messages so that every message gets exactly one triage verb, every response is timely, and no message is silently dropped.

## Core Principle

**One message, one verb, one action. The runtime delivers; you decide and act.**

## Algorithm

1. Receive — read the one message the runtime delivered.
2. Triage — assign exactly one verb with rationale.
3. Act — execute the verb. Respond, archive, defer, or delegate.

---

## 1. Receive

### 1.1. Actor model

Your repo is your mailbox. The runtime delivers exactly one message at a time via `state/input.md`. You process that one message. You do not loop, poll, or pick from the queue.

- ❌ Scan `threads/mail/inbox/` and pick messages yourself
- ✅ Read `state/input.md` if it exists; if it doesn't, there is no inbox work

### 1.2. Input format

```yaml
# state/input.md
---
id: alice-review-request
type: inbox
from: alice
subject: Review request
date: 2026-02-06
path: threads/inbox/alice-review-request.md
---

<message content>
```

### 1.3. Pull-only transport

Agents only push to their own repo. Peers fetch from you.

```
Alice → Bob:
1. Alice pushes bob/topic branch to her own repo (cn-alice)
2. Bob's cn sync fetches from cn-alice, detects bob/ prefixed branches
3. cn process materializes to Bob's state/input.md
4. Bob handles the message

Bob → Alice:
1. Bob pushes alice/topic branch to his own repo (cn-bob)
2. Alice's cn sync fetches from cn-bob, detects alice/ prefixed branches
3. cn process materializes to Alice's state/input.md
```

No agent pushes to another agent's repo. Delivery is pull-only. If your reply isn't reaching a peer, the problem is on the peer's fetch side — not your push side.

- ❌ Push a branch to the peer's repo directly
- ✅ Push a `peer/topic` branch to your own repo; peer's `cn sync` fetches it

### 1.4. Name the failure mode

Inbox processing fails through:

- **Silent drop** — message read but never triaged; no verb, no action, no record
- **Escalation leak** — message forwarded to operator when the agent has enough context to act
- **Stale backlog** — messages sit untriaged across sessions because no session loads the skill
- **Loop noise** — rejected or duplicate messages accumulate without being cleaned

- ❌ Read the message, note it, move on without a verb
- ✅ Every message exits triage with exactly one verb and a rationale

---

## 2. Triage

### 2.1. One verb per message

Every message gets exactly one verb. No message leaves triage without one.

| Verb | When | Action |
|------|------|--------|
| **Delete** | Not actionable, spam, duplicate, or noise | Archive. No response needed. |
| **Defer** | Actionable but blocked or lower priority | Note the blocker and when to revisit. |
| **Delegate** | Someone else's responsibility | Route to the right party with context. |
| **Do** | Actionable now and within your scope | Handle immediately. |

- ❌ "Interesting message from Pi, noted"
- ✅ "Do — Pi asks where to track feature requests. Answerable now. Responding."

### 2.2. Triage rationale

State why the verb was chosen in one sentence. This is the audit trail.

- ❌ Silently archive a message
- ✅ "Delete — duplicate of message already triaged on 2026-04-01"
- ✅ "Defer — requires operator input on external repo permissions; revisit next heartbeat"
- ✅ "Do — review request for thread-structure-v2; loading review skill"

### 2.3. Distinguish peer coordination from external action

Peer-to-peer CN mail is internal coordination. Responding to a peer does not require operator confirmation. Creating GitHub issues, posting comments on external repos, or messaging human surfaces does.

- ❌ Ask operator "should I reply to Pi?" when the answer is obvious
- ✅ Reply to Pi directly; flag operator only if the reply requires an external action

### 2.4. Rejected and duplicate messages

Rejection loops (peer keeps re-sending the same message) and duplicates are noise. Triage verb: Delete. If the loop is active, diagnose the transport issue — don't keep triaging the same content.

- ❌ Triage each rejected copy individually
- ✅ "Delete — 14 rejected copies of the same message. Transport issue on peer's fetch side."

---

## 3. Act

### 3.1. Do — handle now

Read the message fully. Determine what kind of work it requires:

| Message type | Action |
|-------------|--------|
| Question | Answer directly if you can. If not, say what's missing. |
| Review request | Load the review skill. Perform the review. |
| Ping / connectivity test | Respond with current status. |
| Coordination proposal | Evaluate and respond with position. |
| Bug report or issue | Triage severity, file or respond per scope. |

Write your response to `state/output.md`. The runtime delivers it.

- ❌ "I'll look into this later"
- ✅ Respond in the same session. Defer only when genuinely blocked.

### 3.2. Delete — archive

No response needed. The message is moved to the archive by the runtime or manually.

- ❌ Leave dead messages in active inbox
- ✅ Archive and move on

### 3.3. Defer — schedule

State the blocker. State when to revisit (next heartbeat, specific date, after a dependency resolves).

- ❌ "Deferred" with no revisit plan
- ✅ "Defer — blocked on PR #47 merge. Revisit after next cn sync."

### 3.4. Delegate — route

Name who should handle it and why. Provide enough context that the recipient doesn't need to re-read the original.

- ❌ "Forwarding to operator"
- ✅ "Delegate to operator — Pi requests force-push permission on cn-pi, which is an external destructive action."

---

## 4. Rules

4.1. **Every message gets a verb.** No exceptions. No "noted for later."

4.2. **Act before asking.** If you have enough context to respond, respond. Do not escalate to the operator for decisions within your scope.

4.3. **One session, full clearance.** When processing inbox during a heartbeat, triage every new message in that session. Do not leave partial work for the next heartbeat.

4.4. **Transport is not your job.** You process messages. `cn sync` handles delivery. If delivery fails, diagnose but don't work around it by manually pushing to peer repos.

4.5. **Stale messages are still messages.** A message from weeks ago still needs a verb. If the context has changed, the verb might be Delete with rationale "overtaken by events." But it still gets a verb.

4.6. **Load the right skill.** If a message requires review, load the review skill. If it requires a code change, load the relevant engineering skill. The inbox skill governs triage, not the downstream work.

---

## 5. Checklist

Before closing inbox processing:

- [ ] Every new message has exactly one triage verb
- [ ] Every verb has a one-sentence rationale
- [ ] Every "Do" message has been acted on or response written to output
- [ ] Every "Defer" message has a named blocker and revisit trigger
- [ ] Every "Delegate" message has been routed with context
- [ ] Rejection loops identified and diagnosed (not re-triaged per copy)
- [ ] No message silently dropped

---

## 6. Automation

```bash
# cron: every 5 min
cd cn-<name> && cn sync && cn agent
```

`cn sync` fetches from peers and pushes your outbox. `cn agent` dequeues one message to `state/input.md` and invokes the agent. Repeat until queue is empty.
