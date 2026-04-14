#!/usr/bin/env bash
# 03-status.sh — Tier 1 kata 03.
#
# Proves: `cn status` reads hub state.
# Pass condition: output contains hub identity and installed-packages
# section.
#
# cn status requires being inside a hub dir — it uses inv.HubPath,
# which the kernel discovers by walking up from cwd looking for .cn/.

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/lib.sh"

echo "=== Kata 03: Status ==="
echo ""

require_cn
setup_temp_hub
cd "$KATA_HUB"

cn init kata-hub >/dev/null 2>&1 || { fail "cn init failed (precondition)"; kata_summary; }
cd cn-kata-hub

info "running: cn status"
STATUS_OUTPUT=$(cn status 2>&1)
STATUS_RC=$?

if [ "$STATUS_RC" -eq 0 ]; then
  pass "cn status exits 0"
else
  fail "cn status exited $STATUS_RC"
  info "$STATUS_OUTPUT"
  kata_summary
fi

# hubstatus.Run prints "cn hub: <name>" as the first line.
if echo "$STATUS_OUTPUT" | grep -q "cn hub:"; then
  pass "status shows hub identity (cn hub: ...)"
else
  fail "status does not show hub identity"
  info "$STATUS_OUTPUT"
fi

# hubstatus.showPackages prints either "Installed packages:" or
# "No packages installed." — either counts as the packages section.
if echo "$STATUS_OUTPUT" | grep -qE "Installed packages:|No packages installed\."; then
  pass "status shows installed-packages section"
else
  fail "status does not show installed-packages section"
  info "$STATUS_OUTPUT"
fi

echo ""
kata_summary
