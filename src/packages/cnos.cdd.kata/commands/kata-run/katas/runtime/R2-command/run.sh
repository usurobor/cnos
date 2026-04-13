#!/usr/bin/env bash
# R2 — Command kata runner
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
KATA_DIR="$(cd "$SCRIPT_DIR/../../.." && pwd)"
source "$KATA_DIR/lib.sh"

echo "=== R2: Command ==="
echo ""

require_cn
require_version 3.52.0 "command discovery" || { kata_summary; exit 0; }

# Find repo root
REPO_ROOT="$(cd "$KATA_DIR/../../../../.." && pwd)"
if [ ! -f "$REPO_ROOT/cn.package.json" ] && [ ! -f "$REPO_ROOT/VERSION" ]; then
  # Try from installed package context
  REPO_ROOT="${CN_PACKAGE_ROOT:-}"
  if [ -z "$REPO_ROOT" ] || [ ! -f "$REPO_ROOT/../../VERSION" ]; then
    fail "cannot find repo root — run from cnos repo or set CN_PACKAGE_ROOT"
    kata_summary; exit
  fi
  REPO_ROOT="$(cd "$REPO_ROOT/../.." && pwd)"
fi

# 1. Build
cd "$REPO_ROOT"
info "running: cn build"
if cn build 2>&1 | tail -3; then
  pass "cn build succeeded"
else
  fail "cn build failed"
  kata_summary; exit
fi

TARBALL_COUNT=$(ls dist/packages/*.tar.gz 2>/dev/null | wc -l)
if [ "$TARBALL_COUNT" -ge 3 ]; then
  pass "$TARBALL_COUNT tarballs produced"
else
  fail "expected >= 3 tarballs, got $TARBALL_COUNT"
fi

# 2. Restore into temp hub
setup_temp_hub
# Override trap to clean dist too
trap 'rm -rf "$KATA_HUB"; rm -rf "$REPO_ROOT/dist"' EXIT

cd "$KATA_HUB"
cn init kata-hub 2>/dev/null
cd kata-hub

info "running: cn deps lock && cn deps restore"
if cn deps lock 2>&1 && cn deps restore 2>&1; then
  pass "lock + restore succeeded"
else
  fail "lock or restore failed"
  kata_summary; exit
fi

if [ -d ".cn/vendor/packages/cnos.core" ]; then
  pass "cnos.core installed"
else
  fail "cnos.core not found in vendor"
fi

# 3. Help
info "running: cn help"
HELP_OUTPUT=$(cn help 2>&1 || true)

if echo "$HELP_OUTPUT" | grep -q "daily"; then
  pass "cn help shows 'daily' command"
else
  fail "cn help missing 'daily'"
fi

if echo "$HELP_OUTPUT" | grep -qi "package\|cnos.core\|pkg"; then
  pass "cn help shows package attribution"
else
  fail "cn help missing package source attribution"
fi

# 4. Dispatch
info "running: cn daily"
DAILY_OUTPUT=$(cn daily 2>&1 || true)

if echo "$DAILY_OUTPUT" | grep -qi "unknown command"; then
  fail "cn daily: unknown command — dispatch not working"
else
  pass "cn daily dispatched (may fail on missing hub state — that's expected)"
  info "output: $(echo "$DAILY_OUTPUT" | head -3)"
fi

echo ""
kata_summary
