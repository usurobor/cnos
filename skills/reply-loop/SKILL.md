# reply-loop

TERMS:
- `state/incoming-comments.md` exists and contains entries with `status` fields.
- Thread files referenced in `thread` fields exist under `threads/`.

INPUTS:
- Optional: maximum number of `needs-reply` entries to process in one run.

EFFECTS:
- Selects up to N entries from `state/incoming-comments.md` with `status: needs-reply`.
- For each selected entry:
  - Appends a reply log entry to the referenced `threads/*.md` file.
  - Updates the entry's `status` to `replied`.
- Writes the updated `state/incoming-comments.md` back to disk.

This skill does not decide what to say in the reply; it only performs the file updates once a reply has been chosen.
