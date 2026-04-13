#!/usr/bin/env bash
# run-all.sh — Run all kata scripts in sequence
#
# Usage: scripts/kata/run-all.sh
#
# Each kata is independent. Failures in one don't prevent others from running.
# Exit code is non-zero if any kata failed.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
TOTAL_FAIL=0

for kata in "$SCRIPT_DIR"/[0-9]*.sh; do
  [ -f "$kata" ] || continue
  echo ""
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  bash "$kata"
  if [ $? -ne 0 ]; then
    TOTAL_FAIL=$((TOTAL_FAIL + 1))
  fi
done

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
if [ "$TOTAL_FAIL" -gt 0 ]; then
  echo "KATA SUITE: $TOTAL_FAIL kata(s) had failures"
  exit 1
else
  echo "KATA SUITE: all passed"
fi
