# peer-sync

TERMS:
- `state/peers.md` lists one or more peers with at least `name` and `hub`.
- Each peer hub has (or will have) a local clone under `peers/<peer-name>-hub/`.
- Git is available on the host.

INPUTS:
- Optional: limit of peers to process in one run.

EFFECTS:
- For each peer:
  - Ensures `peers/<peer-name>-hub/` exists and is up to date via `git pull`.
  - Writes or updates an entry in `state/peer-sync.md` with:
    - `peer`, `hub`, `branch`, `last-seen-commit`.

This skill does not talk to any external APIs beyond git remotes.
