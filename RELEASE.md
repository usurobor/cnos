# RELEASE.md

## Outcome

Coherence delta: C_Σ A+ (`α A+`, `β A+`, `γ A+`) · **Level:** L7

**Go kernel Phase 3 complete.** All 8 kernel commands implemented. The kernel can now bootstrap, manage, diagnose, build, and update itself. Design principles are a mechanical review gate, not just advice.

## Why it matters

This release completes the Go kernel's command surface — every command from the OCaml runtime has a Go equivalent. `cn update` enables self-updating binaries with SHA-256 verification. `cn setup` makes hubs wake-ready. The design-principles skill and architecture review gate (§2.2.14) turn architectural coherence from human judgment into a structured, gateable check.

## Added

- **Go kernel `update` command** (#212 Slice D, PR #225): fetches latest GitHub release, compares version + commit, downloads platform binary, SHA-256 verifies against checksums.txt, atomic rename install. `--check` for dry run. Same-version patch detection (mirrors OCaml).
- **Go kernel `setup` command** (#212 Slice D, PR #225): creates .cn/, agent/, default deps.json (engineer profile), .gitignore entry. Idempotent. Does not run restore — keeps setup scoped to "prepare the hub."
- **eng/design-principles skill** (L6): architectural decomposition — Parnas (information hiding), Martin (dependency direction), Liskov (truthful substitutability), plus cnos-specific rules for runtime surfaces, registries, source/artifact/install discipline.
- **CDD review §2.2.14**: architecture check with 7 structured questions (reason to change, policy above detail, truthful interfaces, registry normalization, source/artifact/installed clarity, surface separation, degraded-path visibility).
- **CDD review §2.3.5**: verdict gate — any "no" in architecture check blocks approval.
- **BUILD-AND-DIST migration steps**: explicit current → target path for #224.
- **T-004 fix**: current vs target layout both named explicitly (design-principles §3.8 transition honesty).

## Changed

- **INVARIANTS.md v1.2.0**: title normalized, stale references cleaned.
- **cnos.eng manifest**: eng/design-principles added (caught by I1 — first real coherence CI catch on main).

## Validation

- Go binary builds: `cn help` lists 8 kernel commands (help, init, setup, deps, status, doctor, build, update).
- All 63 Go tests pass across 8 packages.
- `cn update --check` reports version status.
- `cn setup` creates hub structure with default deps.json.
- CI dispatch boundary check passes.

## Known Issues

- #224 — src/packages layout migration (filed this session)
- #193 — encoding lag (growing, 12 cycles)
- #186 — encoding lag (design doc shipped)
- #175 — encoding lag (growing)
