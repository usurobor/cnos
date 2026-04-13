#!/usr/bin/env bash
# R4 — Doctor kata runner
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
KATA_DIR="$(cd "$SCRIPT_DIR/../../.." && pwd)"
source "$KATA_DIR/lib.sh"

echo "=== R4: Doctor ==="
echo ""

require_cn
require_version 3.52.0 "doctor command integrity" || { kata_summary; exit 0; }

REPO_ROOT="$(cd "$KATA_DIR/../../../../.." && pwd)"
if [ ! -f "$REPO_ROOT/VERSION" ]; then
  fail "cannot find repo root"
  kata_summary; exit
fi

# 1. Build
cd "$REPO_ROOT"
cn build 2>/dev/null

setup_temp_hub
trap 'rm -rf "$KATA_HUB"; rm -rf "$REPO_ROOT/dist"' EXIT

cd "$KATA_HUB"
cn init kata-hub 2>/dev/null
cd kata-hub
cn deps lock 2>/dev/null && cn deps restore 2>/dev/null

# 2. Clean doctor
info "running: cn doctor (clean state)"
DOCTOR_CLEAN=$(cn doctor 2>&1 || true)
if echo "$DOCTOR_CLEAN" | grep -qi "error\|fail\|✗"; then
  fail "cn doctor reports issues on clean install"
  info "$DOCTOR_CLEAN"
else
  pass "cn doctor clean on fresh install"
fi

# 3. Break entrypoint
DAILY_ENTRYPOINT=".cn/vendor/packages/cnos.core/commands/daily/cn-daily"
if [ -f "$DAILY_ENTRYPOINT" ]; then
  rm "$DAILY_ENTRYPOINT"
  info "deleted $DAILY_ENTRYPOINT"

  DOCTOR_BROKEN=$(cn doctor 2>&1 || true)
  if echo "$DOCTOR_BROKEN" | grep -qi "missing\|not found\|entrypoint\|✗"; then
    pass "cn doctor caught missing entrypoint"
  else
    fail "cn doctor did not catch missing entrypoint"
    info "$DOCTOR_BROKEN"
  fi
else
  skip "daily entrypoint not found"
fi

# 4. Break manifest
CORE_MANIFEST=".cn/vendor/packages/cnos.core/cn.package.json"
if [ -f "$CORE_MANIFEST" ]; then
  echo "NOT JSON" > "$CORE_MANIFEST"
  info "corrupted $CORE_MANIFEST"

  DOCTOR_CORRUPT=$(cn doctor 2>&1 || true)
  if echo "$DOCTOR_CORRUPT" | grep -qi "parse\|invalid\|malformed\|error\|✗"; then
    pass "cn doctor caught corrupted manifest"
  else
    fail "cn doctor did not catch corrupted manifest"
    info "$DOCTOR_CORRUPT"
  fi
else
  skip "cnos.core manifest not found"
fi

echo ""
kata_summary
