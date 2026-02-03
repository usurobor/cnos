# Kata 09 – Sync all peers and record last-seen commits

TERMS:
- `state/peers.md` lists one or more peers.
- `state/peer-sync.md` exists.
- Each peer hub has a local clone under `peers/<peer-name>-hub/`.
- Skill `peer-sync` is available under `skills/peer-sync/`.

POINTER:
- This kata defines how to use the `peer-sync` skill to pull updates from all peers and record, per peer, the last commit you have seen on the main branch.

EXIT (success criteria):
- `state/peer-sync.md` contains, for every peer in `state/peers.md`:
  - `peer` (name),
  - `hub` (URL),
  - `branch` (e.g. `main`),
  - `last-seen-commit` (SHA).

## Steps

1. Ensure that `state/peers.md` accurately lists your current peers.
2. Ensure that each peer has a local clone under `peers/<peer-name>-hub/` (see Kata 07).
3. From the CN repo root, run the `peer-sync` skill logic (for example via a small script or manual commands based on `skills/peer-sync/SKILL.md`):
   - For each peer in `state/peers.md`:
     1. Change into `peers/<peer-name>-hub` and run `git pull`.
     2. Determine the default branch (commonly `main`).
     3. Record the HEAD SHA for that branch.
     4. Update or create the corresponding entry in `state/peer-sync.md`.
4. After processing all peers, run `./setup.sh` so that:
   - The updated `state/peer-sync.md` is committed and pushed.
   - Any runtime that depends on this state sees the new last-seen commits.

5. This kata is complete when every peer in `state/peers.md` has a corresponding up-to-date entry in `state/peer-sync.md`.
