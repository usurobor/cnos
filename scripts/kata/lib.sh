#!/usr/bin/env bash
# lib.sh — shared helpers for Tier 1 (bare binary) kata scripts.
#
# Tier 1 kata prove the `cn` binary works end-to-end before any package
# is installed: help → init → status → doctor → build → install.
# These helpers are deliberately small. Version gating, metadata
# emission, and richer reporting belong in Tier 2 (cnos.kata).

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

# require_cn aborts the kata if `cn` is not on PATH.
require_cn() {
  if ! command -v cn &>/dev/null; then
    echo "ERROR: cn binary not found in PATH"
    exit 1
  fi
}

# repo_root returns the absolute path of the repository root (where
# src/packages/ and .git/ live). Used by 05-build and 06-install.
repo_root() {
  (cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
}

# setup_temp_hub creates an isolated workdir under $TMPDIR, registers
# a cleanup trap, and sets $KATA_HUB to the workdir path. The caller
# cds into $KATA_HUB and runs `cn init` from there.
setup_temp_hub() {
  KATA_HUB=$(mktemp -d "${TMPDIR:-/tmp}/kata-hub-XXXXXX")
  trap 'rm -rf "$KATA_HUB"' EXIT
  info "temp workdir: $KATA_HUB"
}

# kata_summary prints a one-line pass/fail summary and exits non-zero
# if any assertion failed. Called at the end of every kata script.
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
