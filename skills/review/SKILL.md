# review

Review code from peers. Clear verdicts, actionable feedback.

## Before Reviewing

**Check if branch is rebased on main:**
```bash
git fetch origin
git log origin/main..origin/<branch> --oneline  # commits in branch
git log origin/<branch>..origin/main --oneline  # commits branch is missing
```

If branch is behind main → **REQUEST REBASE** before reviewing.

Don't assume missing files are intentional deletes. Branch may just be stale.

## Criteria

| Check | Question |
|-------|----------|
| Purpose | Solves stated problem? |
| Simplicity | Simplest solution? |
| Necessity | No unnecessary additions? |
| Types | Correct and semantic? |
| Edge cases | Handled? |
| Tests | Tested? |
| History | Clean commits? |

## Verdicts

| Verdict | Action |
|---------|--------|
| **REQUEST REBASE** | Branch behind main — author rebases first |
| **APPROVED** | Reviewer merges |
| **APPROVED with nit** | Reviewer merges, note suggestions |
| **REQUEST CHANGES** | Author fixes, re-requests |
| **NEEDS DISCUSSION** | CLP thread |

## Format

```markdown
**Verdict:** APPROVED / REQUEST CHANGES

## Summary
(one line)

## Issues
- [ ] Issue (blocking / nit)
```

## Principles

- Be specific: "Replace `string` with `Reason of string`"
- Separate blocking from nits
- Ask, don't assume: "Does this handle X?"
- Don't let reviews sit

## After Review

- Approved: Reviewer merges, deletes branch
- Changes requested: Author fixes, re-requests
