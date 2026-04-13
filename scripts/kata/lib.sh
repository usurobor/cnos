#!/usr/bin/env bash
# lib.sh — shared helpers for kata scripts
set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
NC='\033[0m'

FAILURES=0
SKIPS=0
PASSES=0

pass() { echo -e "${GREEN}PASS${NC}: $1"; PASSES=$((PASSES + 1)); }
fail() { echo -e "${RED}FAIL${NC}: $1"; FAILURES=$((FAILURES + 1)); }
skip() { echo -e "${YELLOW}SKIP${NC}: $1"; SKIPS=$((SKIPS + 1)); }
info() { echo "     $1"; }

require_cn() {
  if ! command -v cn &>/dev/null; then
    echo "ERROR: cn binary not found in PATH"
    exit 1
  fi
}

cn_version_int() {
  cn --version 2>/dev/null | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1 | awk -F. '{printf "%d%03d%03d", $1, $2, $3}'
}

cn_version_str() {
  cn --version 2>/dev/null | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1
}

require_version() {
  local required="$1" feature="$2"
  local req_int=$(echo "$required" | awk -F. '{printf "%d%03d%03d", $1, $2, $3}')
  local cur_int=$(cn_version_int)
  if [ "$cur_int" -lt "$req_int" ]; then
    skip "$feature requires cn >= $required (have $(cn_version_str))"
    return 1
  fi
  return 0
}

setup_temp_hub() {
  KATA_HUB=$(mktemp -d "${TMPDIR:-/tmp}/kata-hub-XXXXXX")
  trap 'rm -rf "$KATA_HUB"' EXIT
  info "temp hub: $KATA_HUB"
}

# Write run metadata
write_metadata() {
  local run_dir="$1" kata_id="$2" mode="${3:-standalone}"
  mkdir -p "$run_dir"
  cat > "$run_dir/metadata.json" << EOF
{
  "kata_id": "$kata_id",
  "mode": "$mode",
  "cn_version": "$(cn_version_str)",
  "timestamp": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "platform": "$(uname -s)-$(uname -m)",
  "passes": $PASSES,
  "failures": $FAILURES,
  "skips": $SKIPS
}
EOF
}

kata_summary() {
  echo ""
  if [ "$FAILURES" -gt 0 ]; then
    echo -e "${RED}$FAILURES failure(s)${NC}, $PASSES pass(es), $SKIPS skip(s)"
    exit 1
  elif [ "$SKIPS" -gt 0 ]; then
    echo -e "${GREEN}All passed${NC} ($PASSES pass(es), $SKIPS skip(s))"
  else
    echo -e "${GREEN}All passed${NC} ($PASSES pass(es))"
  fi
}
