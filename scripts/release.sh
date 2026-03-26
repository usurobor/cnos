#!/usr/bin/env bash
# release.sh — Automate the CDD release pipeline.
#
# Usage: scripts/release.sh <version> <summary>
# Example: scripts/release.sh 3.20.1 "bugfix: restore path edge case"
#
# Steps (per release skill §2):
#   1. Bump VERSION
#   2. Stamp all manifests
#   3. Check version consistency
#   4. Commit
#   5. Tag (bare version, no v prefix)
#   6. Push main + tag
#   7. Create GitHub release
#
# Abort on any failure. Human confirms before push.

set -euo pipefail

if [ $# -lt 2 ]; then
  echo "Usage: $0 <version> <summary>"
  echo "Example: $0 3.20.1 'bugfix: restore path edge case'"
  exit 1
fi

VERSION="$1"
shift
SUMMARY="$*"

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$REPO_ROOT"

# Preflight
if [ -n "$(git status --porcelain)" ]; then
  echo "ERROR: working tree not clean. Commit or stash first."
  exit 1
fi

if ! git diff --quiet origin/main..HEAD 2>/dev/null; then
  echo "WARNING: local main is ahead of origin. Push first or continue?"
  read -r -p "Continue? [y/N] " confirm
  [ "$confirm" = "y" ] || exit 1
fi

echo "=== Release $VERSION — $SUMMARY ==="
echo

# 1. Bump VERSION
echo "$VERSION" > VERSION
echo "✓ VERSION → $VERSION"

# 2. Stamp manifests
bash scripts/stamp-versions.sh
echo

# 3. Check consistency
bash scripts/check-version-consistency.sh
echo

# 4. Stage and show
git add -A
echo "--- Staged changes ---"
git diff --cached --stat
echo

# 5. Confirm before commit
read -r -p "Commit, tag, push, and release? [y/N] " confirm
if [ "$confirm" != "y" ]; then
  echo "Aborted. Changes staged but not committed."
  exit 1
fi

# 6. Commit
git commit -m "release: $VERSION — $SUMMARY"

# 7. Tag (bare, no v prefix)
git tag "$VERSION"

# 8. Push
git push origin main
git push origin "$VERSION"

# 9. GitHub release
gh release create "$VERSION" \
  --repo "$(gh repo view --json nameWithOwner -q .nameWithOwner)" \
  --title "$VERSION — $SUMMARY" \
  --notes "Release $VERSION — $SUMMARY

See CHANGELOG.md for details."

echo
echo "✓ Released $VERSION"
echo "  Tag: $VERSION"
echo "  URL: $(gh release view "$VERSION" --json url -q .url)"
