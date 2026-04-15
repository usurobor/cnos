#!/usr/bin/env bash
# R1 — Command kata.
#
# Proves: package command discovery + dispatch.
# Pass: `cn help` lists an installed-package command (daily) AND
#       `cn daily` does not report "unknown command".
#
# Runs inside the CI test hub (caller's $PWD); assumes cnos.core is
# installed there. Does not create its own hub — the hub we're in is
# exactly what we want to probe.

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/../../lib.sh"

echo "=== R1: Command ==="
echo ""

require_cn

info "running: cn help"
HELP_OUTPUT=$(cn help 2>&1 || true)

# The kata only passes if `daily` is surfaced. That command ships in
# cnos.core; if cnos.core is not installed in this hub, the whole
# Tier 2 premise is not met and we fail.
if echo "$HELP_OUTPUT" | grep -qE '^\s*daily\b'; then
  pass "cn help lists 'daily' (from cnos.core)"
else
  fail "cn help does not list 'daily'"
  info "help output: $HELP_OUTPUT"
  kata_summary
fi

# Package attribution — verifies the help groups commands by tier.
if echo "$HELP_OUTPUT" | grep -qi 'cnos.core\|package'; then
  pass "cn help shows package attribution"
else
  fail "cn help omits package attribution"
fi

# Dispatch. We don't care that the command succeeds — we care that the
# kernel routed to its entrypoint, not "unknown command".
info "running: cn daily (expect dispatch; content may still fail)"
DAILY_ERR=$(cn daily 2>&1 || true)
if echo "$DAILY_ERR" | grep -qi 'unknown command'; then
  fail "cn daily: unknown command — dispatch broken"
  info "output: $DAILY_ERR"
else
  pass "cn daily dispatched (no 'unknown command' error)"
fi

echo ""
kata_summary
