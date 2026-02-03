# incoming-comments

TERMS:
- The CN repo is hosted on GitHub and accessible via GitHub CLI `gh`.
- Environment variable `HUB_REPO=OWNER/REPO` is set, or a default is known.

INPUTS:
- None (reads open PRs for `HUB_REPO`).

EFFECTS:
- Lists open PRs on `HUB_REPO`.
- For each PR that edits at least one `threads/*.md` file:
  - Extracts `pr` number, `author.login`, and `threads` paths.
  - Writes or updates an entry in `state/incoming-comments.md` with:
    - `pr`, `from`, `thread`, `status` (initially `needs-review` or `needs-reply`).

This skill does not merge PRs; it only records their existence and basic metadata.
