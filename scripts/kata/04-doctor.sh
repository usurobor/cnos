#!/usr/bin/env bash
# 04-doctor.sh — Tier 1 kata 04.
#
# Proves: `cn doctor` validates a clean hub.
# Pass condition: exits 0 on a freshly-init'd hub, with zero broken
# checks (✗). Pending lifecycle items (✓/○) are allowed.
#
# Doctor reports three statuses (see internal/doctor/doctor.go):
#   ✓ validated     — the artifact or tool is present and healthy
#   ○ pending/opt   — legitimately absent at this lifecycle stage
#   ✗ broken        — fails the run
# Tier 1 asserts the absence of ✗; presence of ○ (pending lockfile,
# runtime contract, origin remote) is the expected fresh-hub signal.

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/lib.sh"

echo "=== Kata 04: Doctor ==="
echo ""

require_cn
setup_temp_hub
cd "$KATA_HUB"

cn init kata-hub >/dev/null 2>&1 || { fail "cn init failed (precondition)"; kata_summary; }
cd cn-kata-hub

# `cn setup` writes .cn/deps.json and the .gitignore entry. Without
# it, doctor flags deps.json as missing (required after setup). Running
# setup keeps the kata scoped to "doctor on a prepared fresh hub".
cn setup >/dev/null 2>&1 || { fail "cn setup failed (precondition)"; kata_summary; }

info "running: cn doctor"
DOCTOR_OUTPUT=$(cn doctor 2>&1)
DOCTOR_RC=$?

if [ "$DOCTOR_RC" -eq 0 ]; then
  pass "cn doctor exits 0 on a freshly-init'd hub"
else
  fail "cn doctor exited $DOCTOR_RC"
  info "$DOCTOR_OUTPUT"
fi

# Zero broken checks. ✗ (U+2717) is the doctor glyph for failures;
# ○ (U+25CB) pending items are allowed.
if echo "$DOCTOR_OUTPUT" | grep -q "^✗"; then
  fail "cn doctor reports broken checks on a freshly-init'd hub"
  info "$DOCTOR_OUTPUT"
else
  pass "cn doctor reports no broken checks"
fi

echo ""
kata_summary
