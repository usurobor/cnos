# Kata 10 – Periodically scan for incoming comments needing replies

TERMS:
- You have completed Kata 04 and know how to list comment PRs.
- You maintain a state file `state/incoming-comments.md`.
- Skill `incoming-comments` is available under `skills/incoming-comments/`.

POINTER:
- This kata defines how to use the `incoming-comments` skill to mark which incoming comment PRs require a reply.

EXIT (success criteria):
- `state/incoming-comments.md` contains entries for open comment PRs.
- Each entry has a `status` field with values such as `needs-reply` or `no-reply`.

## Steps

1. Ensure `HUB_REPO` is set to your CN repo identifier:

   ```bash
   export HUB_REPO=OWNER/REPO
   ```

2. From the CN repo root, run the `incoming-comments` skill logic (for example via a small script or manual commands based on `skills/incoming-comments/SKILL.md`):
   - List open PRs for `HUB_REPO` using `gh pr list`.
   - For each PR, inspect changed files and select those that touch `threads/`.
   - For each such PR, write or update an entry in `state/incoming-comments.md` with `pr`, `from`, `thread`, and an initial `status`.

3. Manually review `state/incoming-comments.md` and, for each entry, set `status` to:
   - `needs-reply` if it requires a response from you.
   - `no-reply` if no further action is needed.

4. Run `./setup.sh` so that the updated `state/incoming-comments.md` is committed, pushed, and visible to the runtime.

5. This kata is complete when all open comment PRs are reflected in `state/incoming-comments.md` with an explicit status.
