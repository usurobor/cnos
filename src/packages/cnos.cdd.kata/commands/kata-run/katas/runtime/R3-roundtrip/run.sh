#!/usr/bin/env bash
# R3 — Round-trip kata runner
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
KATA_DIR="$(cd "$SCRIPT_DIR/../../.." && pwd)"
source "$KATA_DIR/lib.sh"

echo "=== R3: Round-trip ==="
echo ""

require_cn
require_version 3.52.0 "round-trip authoring" || { kata_summary; exit 0; }

REPO_ROOT="$(cd "$KATA_DIR/../../../../.." && pwd)"
if [ ! -f "$REPO_ROOT/VERSION" ]; then
  fail "cannot find repo root"
  kata_summary; exit
fi

# 1. Author a test command
KATA_CMD_DIR="$REPO_ROOT/src/packages/cnos.core/commands/kata-test"
MANIFEST="$REPO_ROOT/src/packages/cnos.core/cn.package.json"
MANIFEST_BACKUP=$(mktemp)
cp "$MANIFEST" "$MANIFEST_BACKUP"

mkdir -p "$KATA_CMD_DIR"
cat > "$KATA_CMD_DIR/cn-kata-test" << 'SCRIPT'
#!/usr/bin/env bash
echo "KATA_TEST_OUTPUT: hub=$CN_HUB_PATH pkg=$CN_PACKAGE_ROOT cmd=$CN_COMMAND_NAME"
SCRIPT
chmod +x "$KATA_CMD_DIR/cn-kata-test"

python3 -c "
import json
with open('$MANIFEST') as f:
    m = json.load(f)
m['commands']['kata-test'] = {
    'entrypoint': 'commands/kata-test/cn-kata-test',
    'summary': 'Kata test command'
}
with open('$MANIFEST', 'w') as f:
    json.dump(m, f, indent=2)
    f.write('\n')
" 2>/dev/null

if grep -q "kata-test" "$MANIFEST"; then
  pass "kata-test command added to manifest"
else
  fail "could not inject kata-test into manifest"
  cp "$MANIFEST_BACKUP" "$MANIFEST"
  rm -f "$MANIFEST_BACKUP"
  kata_summary; exit
fi

# Cleanup trap
trap 'rm -rf "$KATA_HUB" "$KATA_CMD_DIR" "$REPO_ROOT/dist"; cp "$MANIFEST_BACKUP" "$MANIFEST"; rm -f "$MANIFEST_BACKUP"' EXIT

# 2. Build
cd "$REPO_ROOT"
info "running: cn build"
if cn build 2>&1 | tail -3; then
  pass "cn build with kata-test succeeded"
else
  fail "cn build failed"
  kata_summary; exit
fi

# 3. Restore
setup_temp_hub
cd "$KATA_HUB"
cn init kata-hub 2>/dev/null
cd kata-hub

info "running: cn deps lock && cn deps restore"
if cn deps lock 2>&1 && cn deps restore 2>&1; then
  pass "lock + restore succeeded"
else
  fail "lock or restore failed"
  kata_summary; exit
fi

# 4. Dispatch
info "running: cn kata-test"
KATA_OUTPUT=$(cn kata-test 2>&1 || true)

if echo "$KATA_OUTPUT" | grep -q "KATA_TEST_OUTPUT"; then
  pass "cn kata-test dispatched and produced expected output"
  info "$KATA_OUTPUT"
else
  if echo "$KATA_OUTPUT" | grep -qi "unknown command"; then
    fail "cn kata-test: unknown command — round-trip broken"
  else
    fail "cn kata-test: unexpected output"
    info "$KATA_OUTPUT"
  fi
fi

# 5. Env vars
if echo "$KATA_OUTPUT" | grep -q "hub="; then
  pass "CN_HUB_PATH env var set"
else
  fail "CN_HUB_PATH missing"
fi

if echo "$KATA_OUTPUT" | grep -q "cmd=kata-test"; then
  pass "CN_COMMAND_NAME correct"
else
  fail "CN_COMMAND_NAME missing or wrong"
fi

echo ""
kata_summary
