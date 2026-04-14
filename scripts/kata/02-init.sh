#!/usr/bin/env bash
# 02-init.sh — Tier 1 kata 02.
#
# Proves: `cn init` creates a hub.
# Pass condition: .cn/ skeleton exists with expected dirs, `cn status`
# exits 0 inside the new hub.
#
# `cn init <name>` creates a directory `cn-<name>/` with the skeleton
# described in src/go/internal/hubinit/hubinit.go.

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/lib.sh"

echo "=== Kata 02: Init ==="
echo ""

require_cn
setup_temp_hub
cd "$KATA_HUB"

info "running: cn init test-hub"
if cn init test-hub >/dev/null 2>&1; then
  pass "cn init exited 0"
else
  fail "cn init failed"
  kata_summary
fi

# `cn init <name>` writes to cn-<name>/ (hubinit.go line 37).
if [ -d "cn-test-hub" ]; then
  pass "hub directory cn-test-hub/ created"
else
  fail "cn-test-hub/ not created"
  kata_summary
fi

cd cn-test-hub

# Skeleton directories from hubinit.Run — see src/go/internal/hubinit/hubinit.go.
for d in .cn spec state threads logs agent; do
  if [ -d "$d" ]; then
    pass "skeleton dir $d/ exists"
  else
    fail "skeleton dir $d/ missing"
  fi
done

# .cn/config.json is the hub identity file.
if [ -f ".cn/config.json" ]; then
  pass ".cn/config.json exists"
else
  fail ".cn/config.json missing"
fi

info "running: cn status"
if cn status >/dev/null 2>&1; then
  pass "cn status exits 0 in the new hub"
else
  fail "cn status failed in the new hub"
fi

echo ""
kata_summary
