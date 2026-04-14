#!/usr/bin/env bash
# 01-binary.sh — Tier 1 kata 01.
#
# Proves: the `cn` binary runs.
# Pass condition: `cn help` exits 0, output contains kernel command names.
#
# No hub is required. This is the first gate — if this fails, the binary
# is broken and nothing else in the suite can pass.

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/lib.sh"

echo "=== Kata 01: Binary ==="
echo ""

require_cn

info "running: cn help"
HELP_OUTPUT=$(cn help 2>&1)
HELP_RC=$?

if [ "$HELP_RC" -eq 0 ]; then
  pass "cn help exits 0"
else
  fail "cn help exited $HELP_RC"
  info "$HELP_OUTPUT"
  kata_summary
fi

# The 8 kernel commands (GO-KERNEL-COMMANDS.md): help, init, setup,
# deps, status, doctor, build, update. All must be listed by `cn help`.
for cmd in help init setup deps status doctor build update; do
  if echo "$HELP_OUTPUT" | grep -qE "^\s+${cmd}\b"; then
    pass "cn help lists '$cmd'"
  else
    fail "cn help does not list '$cmd'"
  fi
done

echo ""
kata_summary
