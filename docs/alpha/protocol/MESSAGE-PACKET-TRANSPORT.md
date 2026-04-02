# Message Packet Transport

**Issue:** #150
**Version:** 3.30.0
**Mode:** MCA
**Active Skills:** design, inbox, writing
**Engineering Level:** L7

## Problem

Inbox materialization can silently write the wrong message content. The receiver reads a different message than the sender sent, with no error or warning.

**Evidence:** Pi sent `sigma/axiom-says-hi` with body "Axiom says hi." Sigma materialized it with body from `where-does-a-surfaced-mca-for.md` — a completely different message from a different date. Triage proceeded on wrong content. The actual message was silently dropped.

**Mechanism:** `get_branch_files` runs `git diff main...origin/<branch>` on the local peer clone. When the clone's main is stale, the diff includes every file changed since the old merge base — not just the message file. `materialize_branch` iterates all diff results and writes the first unarchived `.md` match. Wrong file first in diff = wrong content in inbox.

### Failure modes

1. **Stale clone main** — diff against old merge base returns noise files
2. **Ambiguous file selection** — materializer picks first match, not the intended file
3. **No content verification** — receiver never checks that materialized content matches what the sender declared
4. **No dedup by identity** — duplicate detection is filename-based, not message-identity-based
5. **No equivocation detection** — same message ID with different content is not caught
6. **Git-specific packet identity** — packet semantics tied too tightly to Git objects
7. **Duplicate authority surfaces** — frontmatter and envelope can disagree
8. **Adversarial substitution risk** — integrity without authenticity is insufficient

## Constraints

### Existing contracts

- Pull-only transport: agents push to their own repo, peers fetch
- `cn_io.ml` `materialize_branch` is the current materialization entry point
- `peers.md` defines peer clones and their local paths
- Inbox skill governs triage; this design governs transport

### What can't change

- Git remains a supported transport substrate
- Pull-only fetch model remains
- Peer clone approach remains available
- Hub structure (`threads/mail/inbox/`, `threads/mail/outbox/`, `threads/mail/sent/`)

### Abstraction level

This is a transport protocol change. It sits below the inbox skill (triage) and above transport adapters (Git today, other transports later). The protocol defines:

- canonical packet shape (transport-agnostic)
- transport proof shape (Git-specific, extensible)
- validation pipeline
- materialization contract

## Challenged Assumption

**The current code assumes that diffing a branch against main is a reliable way to discover which file is the message.**

This fails when the clone's main diverges, branches contain unexpected files, multiple message-like files appear in the diff, transport state is stale, or the sender/transport is adversarial.

**Replacement assumption:** A message is a self-contained packet with a canonical envelope and transport proof. The receiver validates the envelope and proof before any inbox write. The canonical packet sits above any specific transport.

---

## Impact Graph

### Downstream consumers

| Consumer | How it's affected |
|----------|------------------|
| `materialize_branch` in `cn_io.ml` | Replaced by packet validation + exact materialization |
| `sync_inbox` in `cn_io.ml` | Fetches packet refs / transport proofs, not arbitrary branch diffs |
| `get_branch_files` in `cn_io.ml` | Removed or Phase 0 only; no longer authoritative |
| `inbox_check_once` in `cn_maintenance.ml` | Calls packet validation pipeline |
| `reject_orphan_branch` in `cn_maintenance.ml` | Uses packet schema / proof validation, not merge-base heuristics |
| `outbox_flush` / `send_thread` in `cn_mail.ml` | Produces canonical packets + transport proof |
| Inbox skill (`ops/inbox/SKILL.md`) | Updated to reflect validated packet input |
| Peer skill (`ops/peer/SKILL.md`) | Updated to reflect packet transport |

### Upstream producers

| Producer | What it provides |
|----------|-----------------|
| `send_thread` in `cn_mail.ml` | Canonical packet envelope + payload + transport proof |
| Transport adapter (Git) | Fetch, commit/tree/blob proof for packet |
| Future transport adapter (chain, mailbox, etc.) | Equivalent proof for packet inclusion/retrieval |

### Copies and authority

| Artifact | Authority |
|----------|-----------|
| `packet/envelope.json` | **Sole** transport-authoritative manifest |
| `packet/message.md` | Exact payload bytes named by the envelope |
| `packet/signature.ed25519` | Authenticity proof over canonical envelope |
| Inbox file frontmatter | Derived from validated envelope; never authoritative |
| Ref / tx / branch / locator | Routing / transport proof only — never authoritative for content |
| Markdown frontmatter inside `message.md` | Optional human/application metadata; **ignored for transport validation** |

---

## Proposal

### 1. Canonical Packet Schema

A message packet is transport-agnostic. Its identity is:

```json
{
  "schema": "cn.packet.v1",
  "msg_id": "<ULID>@<sender>",
  "from": "<sender>",
  "to": "<recipient>",
  "created_at": "<ISO 8601>",
  "content_type": "text/markdown",
  "payload_path": "packet/message.md",
  "payload_sha256": "<SHA-256 of payload bytes>",
  "payload_bytes": 123,
  "topic": "<human label>",
  "thread": "<thread id>",
  "reply_to": "<msg_id>",
  "protocol": {
    "transport": "git-packet",
    "version": 1
  },
  "proof": {
    "git": {
      "payload_blob_oid": "<git blob SHA>",
      "commit_oid": "<commit SHA>",
      "tree_oid": "<tree SHA>"
    }
  }
}
```

#### Key rule

The canonical content identity is `payload_sha256`, not a Git blob OID.

- `payload_sha256` is the transport-agnostic content commitment
- `proof.git.payload_blob_oid` is a transport-specific verification detail

This makes the packet compatible with Git, blockchain/event transports, or future mailbox transports without redesigning materialization.

### 2. Packet Layout

Fixed tree shape:

```
packet/
  envelope.json
  message.md
  signature.ed25519   (required in secure mode)
```

No other files allowed. If the tree contains anything else, reject.

### 3. Transport Adapters

#### 3.1 Git transport (default)

Git remains the default transport adapter.

**Canonical Git ref namespace:**

```
refs/cn/msg/<sender>/<msg_id>
```

Only refs under `refs/cn/msg/` enter the inbox packet pipeline.

**Git proof invariants:**

- Ref sender must match `envelope.from`
- Ref msg_id must match `envelope.msg_id`
- `proof.git.payload_blob_oid` must match actual blob in tree
- Payload bytes must hash to `envelope.payload_sha256`

**Packet commit shape:**

Preferred: a root commit (no parents) whose tree contains only the packet files. This removes dependence on merge base, stale main, or branch history.

#### 3.2 Future transport adapters (compatible, not required)

A chain or event transport may prove inclusion, ordering, finality, and external timestamping. But the canonical packet validation remains the same: envelope → payload hash → signature → proof. On-chain data is not required for payload storage — the chain layer is a proof adapter, not the default payload store.

### 4. Envelope Rules

`packet/envelope.json` is the **sole** transport-authoritative manifest.

**Required invariants:**

- `payload_path` must equal `packet/message.md`
- `from` must match transport proof sender identity
- `msg_id` must match transport proof route identity
- `to` must match local node identity
- `payload_sha256` must match actual payload bytes
- `payload_bytes` must match actual payload length

**Frontmatter rule:** If `message.md` contains Markdown frontmatter, it is **ignored for transport validation**. It may be retained for human/application convenience, but inbox materialization derives its authoritative metadata from the envelope only.

This removes duplicate authority surfaces.

### 5. Signature Model

#### Secure mode (default for adversarial safety)

In secure mode, `packet/signature.ed25519` is **required**. The receiver must verify it before materialization.

The signature covers the canonical bytes of `envelope.json`. Since the envelope binds sender, recipient, payload hash, and payload bytes, the signature transitively authenticates the message payload.

**Rule:** If secure mode is on and signature verification fails — reject, quarantine, log, do not materialize.

#### Insecure / dev mode

In insecure/dev mode, unsigned packets may be accepted. This mode must be **explicit and non-default** — a compatibility phase only.

#### Why

Checksums/hashes prove integrity. Signatures prove authenticity. For adversarial transports, integrity alone is not enough.

### 6. Dedup and Equivocation

**Global message identity:** `msg_id` must be globally unique — `<ULID>@<sender>`.

**Inbound index:** `state/inbound-index.json` keyed by `(msg_id, sender, payload_sha256, status)`.

**Rules:**

- Same `msg_id` + same `payload_sha256` → duplicate; ignore safely
- Same `msg_id` + different `payload_sha256` → equivocation; reject loudly

### 7. Validation Pipeline (Before Materialization)

All assertions happen before any inbox write.

| Step | Check | Reject reason |
|------|-------|---------------|
| 1 | Fetch to quarantine ref / staging area | `fetch_failed` |
| 2 | Resolve transport proof (commit, tree, sender, route) | `invalid_proof` |
| 3 | Validate packet shape (exactly allowed files) | `invalid_tree_shape` |
| 4 | Parse `envelope.json` — all required fields, `schema = cn.packet.v1` | `invalid_envelope` |
| 5 | Validate route/identity bindings: transport sender = `envelope.from`, transport msg_id = `envelope.msg_id`, `envelope.to` = local name | `namespace_mismatch` |
| 6 | Load payload bytes — SHA-256 match, byte length match | `payload_mismatch` |
| 7 | Verify signature (secure mode) — require, verify against sender public key | `signature_invalid` |
| 8 | Check dedup/equivocation index | `duplicate` or `equivocation` |
| 9 | Materialize exact validated payload to inbox | — |

**Rule:** If any step fails, no inbox write occurs. The packet is quarantined with a structured diagnostic.

### 8. Materialization Rule

The materializer never searches for a "likely" file. It writes exactly:

- The payload bytes whose SHA-256 matches the envelope
- From the validated packet
- After all checks succeed

Inbox file metadata is derived from the validated envelope — never from filenames, branch topics, diff output, or message.md frontmatter.

There is no diff against main, no "first matching .md file," no dependence on clone freshness.

### 9. Send-Side Changes

`send_thread` / `outbox_flush` must produce canonical packets.

**Git transport send flow:**

1. Write `packet/envelope.json` with all required fields + `proof.git` block
2. Write `packet/message.md` with message content
3. Compute `payload_sha256` and `payload_bytes`
4. Sign the envelope in secure mode
5. Create root commit containing only the packet tree
6. Push to `refs/cn/msg/<recipient>/<msg_id>` on own repo

**Future transport send flow:** Equivalent — canonical envelope, canonical payload hash, signature, transport proof.

### 10. Error Handling

**Reject classes:**

| Code | Meaning |
|------|---------|
| `fetch_failed` | Transport fetch failed |
| `invalid_proof` | Transport proof unresolvable |
| `invalid_tree_shape` | Packet tree contains unexpected files |
| `invalid_envelope` | Envelope missing, malformed, or wrong schema |
| `namespace_mismatch` | Transport identity ≠ envelope identity |
| `payload_mismatch` | SHA-256, byte length, or path mismatch |
| `signature_missing` | Secure mode, no signature |
| `signature_invalid` | Signature verification failed |
| `signer_unknown` | Sender public key not configured |
| `duplicate` | Same msg_id + same hash (safe ignore) |
| `equivocation` | Same msg_id + different hash (reject) |

**Runtime behavior:** On reject — fail early, do not wake the agent, do not create inbox content, emit operator-visible diagnostic.

### 11. Operator and Traceability Surface

Emit packet lifecycle events:

- `packet.fetched`
- `packet.validated`
- `packet.rejected`
- `packet.duplicate`
- `packet.equivocation`
- `packet.materialized`

Each event includes: `msg_id`, `from`, `to`, transport proof identifiers, `payload_sha256`, `reason_code` if rejected.

---

## Leverage

- Canonical packet is transport-agnostic — future transports plug in without redesigning materialization
- Single authority surface (envelope only) eliminates frontmatter/envelope disagreement class
- Signature verification enables adversarial-safe transport
- Dedup index enables exactly-once delivery semantics
- Packet shape is testable in isolation
- Orphan detection becomes trivial: ref exists but fails validation = orphan

## Negative Leverage

- Send path heavier: hash computation, envelope generation, root commits, optional signing
- Two-phase migration: old-format branches coexist with packets during rollout
- Dedup index is new persistent state requiring garbage collection
- Envelope schema becomes a versioned contract — changes require migration
- Secure mode requires key management infrastructure

## Alternatives Considered

| Option | Pros | Cons | Decision |
|--------|------|------|----------|
| Better diffing (pull clone main before diff) | Minimal code change | Still diff-based discovery | Phase 0 hotfix only |
| Diff against branch parent | Correct diff semantics | Still guesses which file | Phase 0 hotfix only |
| Filter diff to `threads/in/` | Reduces noise | No content verification | Phase 0 hotfix only |
| Git-specific packet (v1 of this design) | Simpler | Ties identity to Git objects; two authority surfaces | Superseded by this version |
| **Transport-agnostic packet with Git proof adapter** | Canonical identity above transport; single authority; extensible | Heavier; migration needed | **Selected** |

## Non-goals

- Encrypting message content (application-layer, not transport)
- Replacing Git as transport substrate
- Changing the pull-only fetch model
- Non-Markdown payloads in Phase 1
- On-chain payload storage by default
- Key management infrastructure in Phase 1 (insecure/dev mode available)

## File Changes

### Create

| File | Contents |
|------|----------|
| `src/transport/cn_packet.ml` | Packet types, envelope parser, validation pipeline (9 steps) |
| `src/transport/cn_packet.mli` | Public interface for packet validation |
| `src/transport/cn_packet_git.ml` | Git transport adapter: fetch, proof resolution, ref namespace |
| `test/transport/cn_packet_test.ml` | Tests: valid packet, each rejection class, dedup, equivocation |

### Edit

| File | Change |
|------|--------|
| `src/transport/cn_io.ml` | `sync_inbox`: fetch `refs/cn/msg/` via adapter. `materialize_branch` → `materialize_packet`: validate then write. Remove `get_branch_files`. |
| `src/cmd/cn_mail.ml` | `send_thread` / `outbox_flush`: produce canonical packets. Compute `payload_sha256`. Create root commit. Push to `refs/cn/msg/`. |
| `src/cmd/cn_maintenance.ml` | `inbox_check_once`: call packet validation. `reject_orphan_branch`: use packet schema for orphan detection. |
| `src/transport/git.ml` | Add: `create_root_commit`, `ls_tree`, `show_blob`, `fetch_refspec`. |
| `src/agent/skills/ops/inbox/SKILL.md` | §2.1.2: input shape reflects packet envelope. §2.1.3: transport docs describe packet model. Frontmatter non-authoritative. |
| `packages/cnos.core/skills/ops/inbox/SKILL.md` | Mirror of above. |

### Phase 0 Hotfix (immediate)

| File | Change |
|------|--------|
| `src/transport/cn_io.ml` | `get_branch_files`: fail closed if 0 or >1 candidate message files. Pull clone main before diff. Filter to `threads/in/` and `threads/out/` only. |

## Acceptance Criteria

### Phase 0

- [ ] `get_branch_files` returns error when diff yields 0 or >1 message files
- [ ] Clone main is pulled before any diff computation
- [ ] `materialize_branch` never writes content from an unintended file

### Phase 1

- [ ] `send_thread` produces packet commits: root commit, `envelope.json`, `message.md`, pushed to `refs/cn/msg/<recipient>/<msg_id>`
- [ ] `envelope.json` contains all required fields; `proof.git` block present
- [ ] Canonical identity is `payload_sha256`, not Git blob OID
- [ ] Validation pipeline rejects: invalid tree shape, missing envelope, wrong recipient, payload SHA-256 mismatch, payload byte length mismatch
- [ ] Dedup: same msg_id + same hash = ignored
- [ ] Equivocation: same msg_id + different hash = rejected
- [ ] Materialized inbox content is exactly the validated payload bytes
- [ ] Inbox metadata derived from envelope, not from `message.md` frontmatter
- [ ] Stale clone main does not affect materialization correctness
- [ ] `grep -rn "diff.*main\.\.\." src/transport/cn_io.ml` returns zero matches

### Phase 2

- [ ] Unsigned packets rejected in secure mode (default)
- [ ] Invalid signatures rejected
- [ ] Sender public key verified against configured peer keys
- [ ] Insecure/dev mode is explicit opt-in, not default

### Transport compatibility

- [ ] Canonical packet validation is independent of transport adapter
- [ ] Git remains supported as default transport
- [ ] Additional transport adapters can provide proof without changing materialization semantics

## Known Debt

- Legacy non-packet branches need temporary compatibility handling during migration
- Dedup index garbage collection not designed
- Attachments / multipart payloads deferred
- Packet schema migration strategy (`cn.packet.v2`) not designed
- Key management infrastructure deferred to Phase 2

## Prior Art

| System | Lesson adopted |
|--------|---------------|
| Git | Content-addressed objects — bind transport proof to exact blob/commit identity |
| BitTorrent | Trust declared hashes and verified content, not filenames or peer hints |
| NNTP / store-and-forward | Globally unique Message-ID — duplicates and reinjection must be detectable |
| Blockchain / event transports | Inclusion/finality proof; external timestamping. Proof adapter, not payload store. |

## CDD Trace

| Step | Artifact | Skills loaded | Decision |
|------|----------|--------------|----------|
| 0 Observe | Daily reflection, Pi message triage failure | inbox | Silent content swap observed during heartbeat triage |
| 1 Select | #150 | — | P0: data integrity failure in messaging |
| 4 Gap | This design doc | design, inbox, writing | Diff-based discovery is structurally unsafe; transport-agnostic packet with fail-closed validation is the minimum coherent fix |
| 5 Mode | This design doc | design, inbox, writing | MCA, L7 — protocol replacement with transport abstraction |
| 6 Artifacts | MESSAGE-PACKET-TRANSPORT.md | — | Design v2: transport-agnostic canonical packet, Git as proof adapter, single authority surface, mandatory signatures in secure mode |
