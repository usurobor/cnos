# Cross-Repo Proposal Lifecycle Examples

This document provides concrete examples of the STATUS file format and lifecycle flows for cross-repo proposals.

## Example 1: Simple Accepted Proposal

**Scenario:** tsc proposes a CI green-gate enhancement to cnos

**Source structure:**
```
tsc/.cdd/iterations/proposals/cdd-ci-green-gate/
├── ISSUE.md
└── STATUS
```

**Source STATUS lifecycle:**
```
# Initial submission
drafted 2026-05-12
submitted 2026-05-13 source=abc1234

# Target decision
accepted 2026-05-13 cnos#352

# Implementation completion
landed 2026-05-15 cnos#352 commit=dc65c7e5 artifact=.cdd/unreleased/352/
```

**Target issue (cnos#352) includes:**
```markdown
## Source Proposal

- Source: `tsc:.cdd/iterations/proposals/cdd-ci-green-gate/`
- Source commit: `abc1234`
- Disposition: `accepted`

## Problem

[Issue content implementing the tsc proposal...]
```

## Example 2: Modified Acceptance

**Scenario:** tsc proposes operator access flow changes, cnos accepts the gap but splits the implementation

**Source STATUS lifecycle:**
```
drafted 2026-05-10
submitted 2026-05-12 source=def5678
modified 2026-05-13 cnos#349 ; split operator access flow from activation cleanup
landed 2026-05-16 cnos#349 commit=7a93d821 artifact=.cdd/unreleased/349/
```

**Target issue (cnos#349) includes:**
```markdown
## Source Proposal

- Source: `tsc:.cdd/iterations/proposals/operator-access-flow/`
- Source commit: `def5678`  
- Disposition: `modified`
- Delta: accepted the gap, split operator flow from activation cleanup per AC boundary analysis.

## Problem

[Implementation that addresses the core gap but with different scope...]
```

## Example 3: Rejected Proposal

**Scenario:** tsc proposes a feature that cnos already implemented

**Source STATUS lifecycle:**
```
drafted 2026-05-08
submitted 2026-05-09 source=ghi9012
rejected 2026-05-09 reason=already-landed evidence=cnos#343
```

**No target issue created.** Target instead appends rejection to source STATUS with reference to existing implementation.

## Example 4: Source Revision Flow

**Scenario:** tsc submits proposal, receives feedback, revises and resubmits

**Source STATUS lifecycle:**
```
# Initial submission
drafted 2026-05-01
submitted 2026-05-02 source=jkl3456

# Target feedback leads to revision
revised 2026-05-03 source=mno7890 ; narrowed AC2 scope based on cnos constraint feedback
submitted 2026-05-03 source=mno7890

# Target acceptance
accepted 2026-05-04 cnos#355
landed 2026-05-06 cnos#355 commit=9f2a4b6c artifact=.cdd/unreleased/355/
```

## Example 5: Patch-Based Proposal

**Scenario:** tsc proposes specific code changes via patch file

**Source structure:**
```
tsc/.cdd/iterations/proposals/auth-middleware-fix/
├── ISSUE.md
├── STATUS  
└── PATCH.diff
```

**Source STATUS lifecycle:**
```
drafted 2026-04-28
submitted 2026-04-30 source=pqr4567
modified 2026-05-01 cnos#358 ; accepted fix, applied partial patch with path adjustments
landed 2026-05-02 cnos#358 commit=a1b2c3d4 artifact=.cdd/unreleased/358/
```

**PATCH.diff contains:**
```diff
diff --git a/src/auth/middleware.js b/src/auth/middleware.js
index abc123..def456 100644
--- a/src/auth/middleware.js
+++ b/src/auth/middleware.js
@@ -15,7 +15,7 @@ function validateToken(token) {
-  return token && token.expires > Date.now();
+  return token && token.expires > Date.now() && token.valid;
```

## Example 6: Cross-Repo Write Failure (Patch Output)

**Scenario:** cnos cannot write to tsc repo, emits patch instead

**Target cannot update source STATUS directly, so generates patch:**

**cnos output:**
```bash
# Generated patch for tsc:.cdd/iterations/proposals/logging-enhancement/STATUS
cat > /tmp/tsc-proposal-logging-enhancement.patch << 'EOF'
diff --git a/.cdd/iterations/proposals/logging-enhancement/STATUS b/.cdd/iterations/proposals/logging-enhancement/STATUS
index abc123..def456 100644
--- a/.cdd/iterations/proposals/logging-enhancement/STATUS
+++ b/.cdd/iterations/proposals/logging-enhancement/STATUS
@@ -1,2 +1,3 @@
 drafted 2026-05-05
 submitted 2026-05-06 source=xyz789
+accepted 2026-05-07 cnos#360
EOF

echo "Apply with: cd tsc && git apply /tmp/tsc-proposal-logging-enhancement.patch"
```

**Target issue (cnos#360) includes feedback patch reference:**
```markdown
## Source Proposal

- Source: `tsc:.cdd/iterations/proposals/logging-enhancement/`
- Source commit: `xyz789`
- Disposition: `accepted`
- Feedback patch: `/tmp/tsc-proposal-logging-enhancement.patch`
```

## Example 7: Withdrawn Proposal

**Scenario:** tsc realizes proposal is no longer needed and withdraws it

**Source STATUS lifecycle:**
```
drafted 2026-04-20
submitted 2026-04-22 source=stu5678
withdrawn 2026-04-25 ; requirements changed, no longer needed
```

**Target action:** If target had not yet decided, no action needed. If target had started work, note the withdrawal in target issue.

## Lifecycle State Transitions

```
drafted → submitted → {accepted|modified|rejected|withdrawn}
accepted → landed
modified → landed
```

**Notes:**
- `corrected` can appear after any event to fix errors
- `revised` + `submitted` can repeat for iterative refinement
- Once `landed`, `rejected`, or `withdrawn`, proposal is terminal (create new proposal for further changes)

## Integration Points

### Gamma Observation (CDD gamma/SKILL.md §2.1)

During candidate building, γ scans:
```bash
# Check both proposal path formats
find .cdd/iterations/proposals/*/STATUS .cdd/proposals/*/*/STATUS 2>/dev/null | \
  xargs grep -l "submitted" | \
  while read status_file; do
    echo "Active proposal: $(dirname "$status_file")"
    # Read adjacent ISSUE.md and PATCH.diff
  done
```

### Gamma Close-out (CDD gamma/SKILL.md §2.7)

After merge completion, γ updates source STATUS:
```bash
# Direct update (if writable)
echo "landed $(date +%Y-%m-%d) cnos#352 commit=$(git rev-parse HEAD) artifact=.cdd/unreleased/352/" >> \
  /path/to/source/.cdd/iterations/proposals/slug/STATUS

# Or emit patch (if not writable)  
git format-patch --stdout HEAD~1 > /tmp/source-proposal-feedback.patch
```

### Post-Release Verification (CDD post-release/SKILL.md)

During pre-publish gate:
- [ ] Cross-repo proposal status updated or feedback patch emitted for any proposal that contributed to this cycle

This ensures no accepted proposal remains in `accepted` or `modified` state after target implementation ships.