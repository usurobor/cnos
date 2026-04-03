# RELEASE.md

## Outcome

Coherence delta: C_Σ A (`α A`, `β A`, `γ A`) · **Level:** `L7`

Message transport replaced: diff-based branch materialization deleted, canonical packet protocol (`cn.packet.v1`) is now the sole inbound/outbound path. Inbox writes only occur after full envelope + payload validation. Silent content swap is structurally impossible.

## Why it matters

Issue #150 demonstrated that stale peer clone state could silently swap message content — the receiver would write the wrong file without error. This was a transport-integrity failure at the lowest level. The fix eliminates the entire diff-based discovery mechanism rather than patching it, replacing it with a packet schema where payload identity is verified by SHA-256 before any inbox write.

## Fixed

- **Silent content swap from stale clone** (#150): deleted `materialize_branch` and all diff-based file discovery. Packet validation (9-step pipeline) now gates every inbox write.

## Added

- **`cn_packet.ml`** (#150): canonical packet schema (`cn.packet.v1`), envelope serialization/parsing, 9-step validation pipeline, dedup/equivocation index, Git packet ref operations.
- **`refs/cn/msg/{sender}/{msg_id}` namespace** (#150): dedicated Git ref namespace for inbound packets, replacing arbitrary branch discovery.
- **Packet lifecycle trace events** (#150): `packet.fetched`, `packet.validated`, `packet.rejected`, `packet.duplicate`, `packet.equivocation`, `packet.materialized`.
- **16 ppx_expect tests** (#150): envelope round-trip, 5 validation rejection modes, 3 dedup cases, 3 ref parsing cases, payload commitment determinism, msg_id format.

## Changed

- **Send path** (#150): `send_thread` now creates root commits under `refs/cn/msg/{sender}/{msg_id}` instead of branch-based push.
- **Inbox processing** (#150): `inbox_process` fetches packet refs only. Legacy branch-based inbound path fully removed.

## Removed

- **`materialize_branch`** (#150): entire diff-based materialization function deleted.
- **`get_inbound_branches`** (#150): branch discovery for inbox deleted.
- **Orphan rejection pipeline** (#150): `parse_rejected_branch`, `rejection_filename`, `is_already_rejected` deleted (obsoleted by packet dedup).
- **17 legacy tests**: branch-based rejection/materialization tests replaced by packet tests.

## Validation

- CI green: all 3 checks pass (ocaml build+test, I1 package/source drift, I2/I3 protocol contract)
- 16 new packet tests + 8 cram tests updated for packet transport
- Payload SHA-256 verification confirmed: wrong content structurally rejected before inbox write

## Known Issues

- Phase 2 (signature enforcement) deferred — design in MESSAGE-PACKET-TRANSPORT.md
- Dedup index pruning not yet designed (index grows unbounded)
- `cn_io.ml` contains dead code from old materialization path (#152)
- Peers running pre-3.31.0 will not receive packets (protocol upgrade boundary)
