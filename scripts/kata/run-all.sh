#!/usr/bin/env bash
# run-all.sh — Run Tier 1 kata scripts in numeric order.
#
# Usage: scripts/kata/run-all.sh
#
# Stops on the first failure (AC2 in #236). Exit non-zero if any kata
# fails. CI gates merges on this script's exit code.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

for kata in "$SCRIPT_DIR"/[0-9]*.sh; do
  [ -f "$kata" ] || continue
  echo ""
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  bash "$kata"
  rc=$?
  if [ "$rc" -ne 0 ]; then
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "KATA SUITE: $(basename "$kata") failed (rc=$rc) — stopping"
    exit "$rc"
  fi
done

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "KATA SUITE: all passed"
