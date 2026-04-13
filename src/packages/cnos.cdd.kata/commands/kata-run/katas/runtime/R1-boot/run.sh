#!/usr/bin/env bash
# R1 — Boot kata runner
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
KATA_DIR="$(cd "$SCRIPT_DIR/../../.." && pwd)"
source "$KATA_DIR/lib.sh"

echo "=== R1: Boot ==="
echo ""

require_cn

setup_temp_hub
cd "$KATA_HUB"

info "running: cn init kata-hub"
if cn init kata-hub 2>&1; then
  pass "cn init created hub"
else
  fail "cn init failed"
  kata_summary; exit
fi

cd kata-hub

if [ -d ".cn" ]; then
  pass ".cn/ directory exists"
else
  fail ".cn/ directory not created"
fi

info "running: cn status"
STATUS_OUTPUT=$(cn status 2>&1 || true)

if echo "$STATUS_OUTPUT" | grep -qi "cnos\.\|packages\|vendor"; then
  pass "cn status shows package information"
else
  # On older versions, status may not show packages
  if require_version 3.53.0 "package-aware status" 2>/dev/null; then
    fail "cn status does not show installed packages"
  else
    skip "cn status package display requires >= 3.53.0"
  fi
fi

info "status output:"
echo "$STATUS_OUTPUT" | sed 's/^/     /'

echo ""
kata_summary
