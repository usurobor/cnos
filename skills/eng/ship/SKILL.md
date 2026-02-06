# ship

Ship code to production or merge to main.

## Pre-Ship Checklist

- [ ] Tests pass
- [ ] Branch rebased on main
- [ ] PR approved (if required)
- [ ] No unresolved comments

## Ship

```bash
git checkout main
git pull
git merge <branch> --no-ff
git push
```

Or squash if history is noisy:
```bash
git merge <branch> --squash
git commit -m "feat: <description>"
git push
```

## Post-Ship Checklist

- [ ] **Announce to peers** — outbox message: "shipped X to main"
- [ ] **Delete branch** — local and remote
- [ ] **Update daily thread** — log what shipped

### Announce Template

```markdown
---
to: <peer>
created: <timestamp>
subject: Shipped <feature>
---

Merged to main: <commit-hash>
Branch deleted: <branch-name>

—<your-name>
```

## Why Announce?

Peers track your work via branches and inbox. If you merge without announcing:
- Stale branches cause confusion ("59 commits behind")
- Peers don't know work is done
- Escalations happen unnecessarily

**Ship = merge + announce + cleanup.** Not just merge.
