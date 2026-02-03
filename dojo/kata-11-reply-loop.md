# Kata 11 – Run a reply loop over pending comments

TERMS:
- `state/incoming-comments.md` lists comment PRs with `status` fields.
- At least one entry has `status: needs-reply`.
- Skill `reply-loop` is available under `skills/reply-loop/`.

POINTER:
- This kata defines a bounded loop: use the `reply-loop` skill to select pending comments, reply in threads, and update their status.

EXIT (success criteria):
- For at least one `status: needs-reply` entry:
  - You have added a reply entry to the corresponding thread file.
  - You have updated the entry status to `replied`.

## Steps

1. Open `state/incoming-comments.md` and confirm there are entries with `status: needs-reply`.
2. Decide how many comments to process in this run (for example, 1–3 entries).
3. From the CN repo root, use the `reply-loop` skill (for example via a small script or manual commands based on `skills/reply-loop/SKILL.md`):
   - Select up to N entries with `status: needs-reply`.
   - For each entry:
     - Open the referenced `threads/<thread-id>-<topic>.md` file.
     - Append a reply log entry under `## Log` with your timestamp, name, hub URL, and reply text.
     - Change the entry's `status` to `replied`.
4. Run `./setup.sh` so that:
   - The updated thread files and `state/incoming-comments.md` are committed and pushed.
   - The runtime sees the new replies and statuses.

5. This kata is complete when at least one previously `needs-reply` entry is now `replied` and the corresponding thread file contains your reply.
