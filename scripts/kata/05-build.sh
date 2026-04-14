#!/usr/bin/env bash
# 05-build.sh — Tier 1 kata 05.
#
# Proves: `cn build` produces dist/.
# Pass condition: dist/packages/ contains at least one .tar.gz and an
# index.json.
#
# cn build discovers src/packages/*/cn.package.json and writes tarballs
# + index.json + checksums.txt into dist/packages/ (see
# src/go/internal/pkgbuild/build.go). Must run from the repo root.

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/lib.sh"

echo "=== Kata 05: Build ==="
echo ""

require_cn

REPO_ROOT="$(repo_root)"
cd "$REPO_ROOT"

info "running: cn build (from $REPO_ROOT)"
if cn build >/dev/null 2>&1; then
  pass "cn build exits 0"
else
  fail "cn build failed"
  kata_summary
fi

if [ -f "dist/packages/index.json" ]; then
  pass "dist/packages/index.json exists"
else
  fail "dist/packages/index.json missing"
fi

TARBALL_COUNT=$(find dist/packages -maxdepth 1 -name '*.tar.gz' 2>/dev/null | wc -l | tr -d ' ')
if [ "$TARBALL_COUNT" -ge 1 ]; then
  pass "$TARBALL_COUNT tarball(s) produced in dist/packages/"
else
  fail "no .tar.gz tarballs in dist/packages/"
fi

echo ""
kata_summary
