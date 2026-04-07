#!/usr/bin/env bash
# build-packages.sh — Build package tarballs and the package index.
#
# For each directory under packages/ that has a cn.package.json, produces:
#   dist/packages/<name>-<version>.tar.gz
#
# Then writes packages/index.json (cn.package-index.v1) mapping
# name+version to URL+SHA-256.
#
# URL pattern is the GitHub release asset URL for the current VERSION:
#   https://github.com/<owner>/<repo>/releases/download/<version>/<name>-<version>.tar.gz
#
# Designed for the release workflow but runnable locally for testing.
#
# Usage:
#   scripts/build-packages.sh                    # default repo, VERSION
#   CNOS_REPO=usurobor/cnos scripts/build-packages.sh
#
# Outputs:
#   dist/packages/*.tar.gz
#   packages/index.json   (rewritten)

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$REPO_ROOT"

if [ ! -f VERSION ]; then
  echo "ERROR: VERSION file not found" >&2
  exit 1
fi
VERSION=$(tr -d '\n' < VERSION)
if [ -z "$VERSION" ]; then
  echo "ERROR: VERSION file is empty" >&2
  exit 1
fi

CNOS_REPO="${CNOS_REPO:-usurobor/cnos}"
DIST_DIR="dist/packages"
INDEX_FILE="packages/index.json"

mkdir -p "$DIST_DIR"

# Collect package directories deterministically
mapfile -t PKG_DIRS < <(find packages -mindepth 1 -maxdepth 1 -type d | sort)

if [ "${#PKG_DIRS[@]}" -eq 0 ]; then
  echo "ERROR: no package directories under packages/" >&2
  exit 1
fi

declare -a INDEX_ENTRIES

sha256_of() {
  if command -v sha256sum >/dev/null 2>&1; then
    sha256sum "$1" | awk '{print $1}'
  else
    shasum -a 256 "$1" | awk '{print $1}'
  fi
}

for pkg_dir in "${PKG_DIRS[@]}"; do
  manifest="$pkg_dir/cn.package.json"
  if [ ! -f "$manifest" ]; then
    echo "skip: $pkg_dir (no cn.package.json)"
    continue
  fi
  name=$(python3 -c "import json,sys; print(json.load(open('$manifest'))['name'])")
  pkg_version=$(python3 -c "import json,sys; print(json.load(open('$manifest'))['version'])")

  if [ "$pkg_version" != "$VERSION" ]; then
    echo "ERROR: $manifest version $pkg_version != VERSION $VERSION" >&2
    echo "       run scripts/stamp-versions.sh first" >&2
    exit 1
  fi

  tarball="$DIST_DIR/${name}-${VERSION}.tar.gz"
  echo "  building $tarball"

  # Tar contents: package files + cn.package.json, rooted at the package
  # name (so extraction yields a clean directory). Use --sort to make the
  # archive bit-reproducible across hosts.
  tar \
    --owner=0 --group=0 --numeric-owner \
    --sort=name \
    --mtime="1970-01-01 00:00:00 UTC" \
    -C "$pkg_dir" \
    -czf "$tarball" \
    .

  digest=$(sha256_of "$tarball")
  url="https://github.com/${CNOS_REPO}/releases/download/${VERSION}/${name}-${VERSION}.tar.gz"

  INDEX_ENTRIES+=("$name|$VERSION|$url|$digest")
  echo "    sha256: $digest"
done

# Emit packages/index.json (cn.package-index.v1)
{
  echo "{"
  echo "  \"schema\": \"cn.package-index.v1\","
  echo "  \"packages\": {"
  # Group by name (we only have one version per name in this build)
  total=${#INDEX_ENTRIES[@]}
  i=0
  for entry in "${INDEX_ENTRIES[@]}"; do
    i=$((i + 1))
    IFS='|' read -r name version url digest <<<"$entry"
    comma=","; [ "$i" -eq "$total" ] && comma=""
    echo "    \"$name\": {"
    echo "      \"$version\": {"
    echo "        \"url\": \"$url\","
    echo "        \"sha256\": \"$digest\""
    echo "      }"
    echo "    }$comma"
  done
  echo "  }"
  echo "}"
} > "$INDEX_FILE"

echo ""
echo "Wrote $INDEX_FILE"
echo "Wrote ${#INDEX_ENTRIES[@]} package tarball(s) under $DIST_DIR/"
