#!/usr/bin/env bash
# release.sh — Single-command release pipeline for cnos.
#
# Usage: scripts/release.sh <version>
# Example: scripts/release.sh 3.34.0
#
# Steps:
#   1. Preflight (clean tree, on main, up to date)
#   2. Bump VERSION
#   3. Stamp manifests (cn.json, packages)
#   4. Check consistency
#   5. Commit + push
#   6. Tag (v-prefixed) + push tag
#
# Release workflow triggers on the tag push.
# CHANGELOG.md and RELEASE.md must be updated before running this.

set -euo pipefail

if [ $# -lt 1 ]; then
  echo "Usage: $0 <version>"
  echo "Example: $0 3.34.0"
  exit 1
fi

VERSION="$1"
REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$REPO_ROOT"

# --- Preflight ---

if [ -n "$(git status --porcelain)" ]; then
  echo "ERROR: working tree not clean. Commit or stash first."
  exit 1
fi

BRANCH=$(git branch --show-current)
if [ "$BRANCH" != "main" ]; then
  echo "ERROR: must be on main (currently on $BRANCH)."
  exit 1
fi

git fetch origin main --quiet
LOCAL=$(git rev-parse HEAD)
REMOTE=$(git rev-parse origin/main)
if [ "$LOCAL" != "$REMOTE" ]; then
  echo "ERROR: local main ($LOCAL) differs from origin/main ($REMOTE)."
  echo "Pull or push first."
  exit 1
fi

# RELEASE.md and CHANGELOG.md should already reference this version
if ! grep -q "$VERSION" RELEASE.md 2>/dev/null; then
  echo "WARNING: RELEASE.md does not mention $VERSION"
  read -r -p "Continue without release notes? [y/N] " confirm
  [ "$confirm" = "y" ] || exit 1
fi

TAG="v$VERSION"
if git tag -l "$TAG" | grep -q "$TAG"; then
  echo "ERROR: tag $TAG already exists."
  exit 1
fi

echo "=== Release $TAG ==="
echo ""

# --- Bump + stamp + check ---

echo "$VERSION" > VERSION
echo "✓ VERSION → $VERSION"

bash scripts/stamp-versions.sh
echo ""
bash scripts/check-version-consistency.sh
echo ""

# --- Stage and confirm ---

git add -A
echo "--- Staged changes ---"
git diff --cached --stat
echo ""

read -r -p "Commit, tag $TAG, and push? [y/N] " confirm
if [ "$confirm" != "y" ]; then
  echo "Aborted. Changes staged but not committed."
  exit 1
fi

# --- Commit + tag + push ---

git commit -m "release: $TAG"
git tag "$TAG"
git push origin main
git push origin "$TAG"

echo ""
echo "✓ Released $TAG. Workflow will build and publish."
