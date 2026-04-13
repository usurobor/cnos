#!/usr/bin/env bash
# lib.sh — shared helpers for kata scripts
set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
NC='\033[0m'

pass() { echo -e "${GREEN}PASS${NC}: $1"; }
fail() { echo -e "${RED}FAIL${NC}: $1"; FAILURES=$((FAILURES + 1)); }
skip() { echo -e "${YELLOW}SKIP${NC}: $1"; SKIPS=$((SKIPS + 1)); }
info() { echo "     $1"; }

FAILURES=0
SKIPS=0

# Require cn binary
require_cn() {
  if ! command -v cn &>/dev/null; then
    echo "ERROR: cn binary not found in PATH"
    exit 1
  fi
}

# Get cn version as comparable integer (3.53.0 → 3053000)
cn_version_int() {
  cn --version 2>/dev/null | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1 | awk -F. '{printf "%d%03d%03d", $1, $2, $3}'
}

# Check minimum cn version. Usage: require_version 3.52.0 "feature name"
require_version() {
  local required="$1" feature="$2"
  local req_int=$(echo "$required" | awk -F. '{printf "%d%03d%03d", $1, $2, $3}')
  local cur_int=$(cn_version_int)
  if [ "$cur_int" -lt "$req_int" ]; then
    skip "$feature requires cn >= $required (have $(cn --version 2>/dev/null | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1))"
    return 1
  fi
  return 0
}

# Create a temp hub dir, cleaned up on exit
setup_temp_hub() {
  KATA_HUB=$(mktemp -d "${TMPDIR:-/tmp}/kata-hub-XXXXXX")
  trap 'rm -rf "$KATA_HUB"' EXIT
  info "temp hub: $KATA_HUB"
}

# Summary
kata_summary() {
  echo ""
  if [ "$FAILURES" -gt 0 ]; then
    echo -e "${RED}$FAILURES failure(s)${NC}, $SKIPS skip(s)"
    exit 1
  elif [ "$SKIPS" -gt 0 ]; then
    echo -e "${GREEN}All passed${NC}, $SKIPS skip(s)"
  else
    echo -e "${GREEN}All passed${NC}"
  fi
}
