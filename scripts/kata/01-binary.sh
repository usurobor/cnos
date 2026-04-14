#!/usr/bin/env bash
# 01-binary.sh — Tier 1 kata 01.
#
# Proves: the `cn` binary runs.
# Pass condition: `cn help` exits 0, output lists the 8 kernel commands
# (help, init, setup, deps, status, doctor, build, update) inside its
# "Kernel commands:" section.
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

# Extract only the "Kernel commands:" section so the 8-command
# assertion is not confused by repo-local or package commands that may
# share names. The section ends at the next blank line or header.
KERNEL_SECTION=$(echo "$HELP_OUTPUT" | awk '
  /^Kernel commands:/ { inside=1; next }
  inside && /^[A-Z]/ { exit }
  inside && NF == 0 { exit }
  inside { print }
')

if [ -z "$KERNEL_SECTION" ]; then
  fail "cn help has no 'Kernel commands:' section"
  info "$HELP_OUTPUT"
  kata_summary
fi

# The 8 kernel commands from GO-KERNEL-COMMANDS.md.
for cmd in help init setup deps status doctor build update; do
  if echo "$KERNEL_SECTION" | grep -qE "^\s+${cmd}\b"; then
    pass "kernel command '$cmd' listed"
  else
    fail "kernel command '$cmd' missing from 'Kernel commands:' section"
  fi
done

echo ""
kata_summary
