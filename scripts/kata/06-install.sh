#!/usr/bin/env bash
# 06-install.sh — Tier 1 kata 06.
#
# Proves: `cn deps restore` installs packages from dist/.
# Pass condition: at least one package appears under .cn/vendor/packages/
# with a cn.package.json.
#
# Needs dist/ from 05-build.sh. restore.FindIndexPath walks up from the
# hub looking for dist/packages/index.json, so the temp hub is created
# under a workdir that symlinks dist/ from the repo root.

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/lib.sh"

echo "=== Kata 06: Install ==="
echo ""

require_cn

REPO_ROOT="$(repo_root)"
if [ ! -f "$REPO_ROOT/dist/packages/index.json" ]; then
  fail "dist/packages/index.json missing — run 05-build.sh first"
  kata_summary
fi

setup_temp_hub
# Expose dist/ to FindIndexPath: the hub will be at
# $KATA_HUB/cn-kata-hub/, walking up reaches $KATA_HUB/dist/.
ln -s "$REPO_ROOT/dist" "$KATA_HUB/dist"
cd "$KATA_HUB"

cn init kata-hub >/dev/null 2>&1 || { fail "cn init failed (precondition)"; kata_summary; }
cd cn-kata-hub

cn setup >/dev/null 2>&1 || { fail "cn setup failed (precondition)"; kata_summary; }

info "running: cn deps lock"
if cn deps lock >/dev/null 2>&1; then
  pass "cn deps lock exits 0"
else
  fail "cn deps lock failed"
  kata_summary
fi

if [ -f ".cn/deps.lock.json" ]; then
  pass ".cn/deps.lock.json written"
else
  fail ".cn/deps.lock.json missing after lock"
  kata_summary
fi

info "running: cn deps restore"
if cn deps restore >/dev/null 2>&1; then
  pass "cn deps restore exits 0"
else
  fail "cn deps restore failed"
  kata_summary
fi

# Count installed packages with a cn.package.json manifest.
INSTALLED=0
if [ -d ".cn/vendor/packages" ]; then
  for d in .cn/vendor/packages/*/; do
    [ -f "${d}cn.package.json" ] && INSTALLED=$((INSTALLED + 1))
  done
fi

if [ "$INSTALLED" -ge 1 ]; then
  pass "$INSTALLED package(s) installed under .cn/vendor/packages/ with cn.package.json"
else
  fail "no packages installed under .cn/vendor/packages/"
fi

echo ""
kata_summary
