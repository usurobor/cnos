# star-sync

TERMS:
- The CN repo is hosted on GitHub and accessible via GitHub CLI `gh`.
- `state/peers.md` lists current peers with GitHub-backed `hub` URLs.

INPUTS:
- None (operates on the current peer list and previous star state).

EFFECTS:
- For each peer in `state/peers.md`:
  - Derives `OWNER/REPO` from the `hub` URL when it points at GitHub.
  - Stars that repo via `gh repo star OWNER/REPO`.
  - Records an entry in `state/starred-peers.md`.
- For any entry in `state/starred-peers.md` whose `name` no longer appears in `state/peers.md`:
  - Unstars the corresponding GitHub repo via `gh repo unstar OWNER/REPO`.
  - Removes the entry from `state/starred-peers.md`.

This skill keeps GitHub stars aligned with the current peer subscriptions.
