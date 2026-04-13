#!/usr/bin/env bash
# 02-command.sh — Command kata
#
# Proves: cn build produces packages, cn deps restore installs them,
#         package commands are discovered and dispatch.
# Requires: cn >= 3.52.0 (command discovery shipped in v3.52.0)
#
# Scenario: repo with src/packages/ → cn build → cn deps restore → cn daily dispatches
# Before: packages exist in source, not installed
# After: cn help shows package commands, cn daily dispatches to entrypoint

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/lib.sh"

echo "=== Kata 02: Command ==="
echo ""

require_cn
require_version 3.52.0 "command discovery" || { kata_summary; exit 0; }

# Find repo root
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
if [ ! -f "$REPO_ROOT/VERSION" ]; then
  fail "cannot find repo root (expected VERSION at $REPO_ROOT)"
  kata_summary; exit
fi

# 1. Build packages
info "running: cn build (in $REPO_ROOT)"
cd "$REPO_ROOT"
if cn build 2>&1 | tail -3; then
  pass "cn build succeeded"
else
  fail "cn build failed"
  kata_summary; exit
fi

# Verify dist/ output
if [ -f "dist/packages/index.json" ]; then
  pass "dist/packages/index.json exists"
else
  fail "dist/packages/index.json missing"
fi

TARBALL_COUNT=$(ls dist/packages/*.tar.gz 2>/dev/null | wc -l)
if [ "$TARBALL_COUNT" -ge 3 ]; then
  pass "$TARBALL_COUNT tarballs produced"
else
  fail "expected >= 3 tarballs, got $TARBALL_COUNT"
fi

# 2. Set up a temp hub and restore
setup_temp_hub
cd "$KATA_HUB"
cn init kata-hub 2>/dev/null
cd kata-hub

# Generate lockfile and restore
info "running: cn deps lock"
if cn deps lock 2>&1; then
  pass "cn deps lock generated lockfile"
else
  fail "cn deps lock failed"
  kata_summary; exit
fi

info "running: cn deps restore"
if cn deps restore 2>&1; then
  pass "cn deps restore installed packages"
else
  fail "cn deps restore failed"
  kata_summary; exit
fi

# Verify installed packages
if [ -d ".cn/vendor/packages/cnos.core" ]; then
  pass "cnos.core installed"
else
  fail "cnos.core not found in vendor"
fi

# 3. Help shows package commands
info "running: cn help"
HELP_OUTPUT=$(cn help 2>&1 || true)

if echo "$HELP_OUTPUT" | grep -q "daily"; then
  pass "cn help shows 'daily' command"
else
  fail "cn help does not show 'daily'"
  info "help output: $HELP_OUTPUT"
fi

if echo "$HELP_OUTPUT" | grep -qi "package\|cnos.core\|pkg"; then
  pass "cn help shows package attribution"
else
  fail "cn help does not show package source"
fi

# 4. Command dispatch
info "running: cn daily (expect dispatch, may fail on missing hub state)"
if cn daily 2>&1; then
  pass "cn daily dispatched and succeeded"
else
  # Dispatch working but command failing due to missing hub state is acceptable
  # The key test is: did it dispatch to the entrypoint, not "unknown command"?
  DAILY_ERR=$(cn daily 2>&1 || true)
  if echo "$DAILY_ERR" | grep -qi "unknown command"; then
    fail "cn daily: unknown command — dispatch not working"
  else
    pass "cn daily dispatched (command exited non-zero — likely missing hub state, not a dispatch failure)"
    info "output: $DAILY_ERR"
  fi
fi

# 5. Clean up dist/
rm -rf "$REPO_ROOT/dist"
info "cleaned dist/"

echo ""
kata_summary
