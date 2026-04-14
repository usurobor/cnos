#!/usr/bin/env bash
# 04-doctor.sh — Tier 1 kata 04.
#
# Proves: `cn doctor` validates a clean hub.
# Pass condition: exits 0 on a freshly-init'd hub with no warnings.
#
# A Tier 1 doctor run checks that the hub structure is intact.
# Package/lockfile/wake artifacts belong to later lifecycle stages
# and are reported informationally by doctor (see doctor.go).

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/lib.sh"

echo "=== Kata 04: Doctor ==="
echo ""

require_cn
setup_temp_hub
cd "$KATA_HUB"

cn init kata-hub >/dev/null 2>&1 || { fail "cn init failed (precondition)"; kata_summary; }
cd cn-kata-hub

# `cn setup` is part of the minimal fresh-hub preparation: it writes
# .cn/deps.json and the .gitignore entry. Without it, doctor flags
# deps.json as missing. Running setup here keeps the kata scoped to
# "doctor on a prepared fresh hub".
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

# A clean fresh hub should have zero failing lines (✗) in doctor output.
if echo "$DOCTOR_OUTPUT" | grep -q "^✗"; then
  fail "cn doctor reports warnings on a freshly-init'd hub"
  info "$DOCTOR_OUTPUT"
else
  pass "cn doctor has no warnings on a freshly-init'd hub"
fi

echo ""
kata_summary
