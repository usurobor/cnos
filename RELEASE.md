## Fixed

- **Daemon crash loop from false version drift** (#148): `resolve_bin_path` spawned a shell child to read `/proc/self/exe`, but the child's `/proc/self/exe` was `/usr/bin/bash`, not `cn`. This caused `check_binary_version_drift` to run `bash --version`, detect false drift, and trigger a failing re-exec every 5 minutes. Fix: `Unix.readlink "/proc/self/exe"` — reads the symlink directly in-process, no child shell.

## Changed

- **Release skill:** Added §2.5 (RELEASE.md format + workflow integration) and §3.7 (mechanical gate — no tag without RELEASE.md).

## Validation

- Deployed to Pi VPS, daemon stable, no false version drift, no re-exec loop.

## Known Issues

- #148 remains open for the `--daemon` argv issue on re-exec (separate from the version drift false positive fixed here).
