# Self-Coherence Report — v3.15.2

**Branch:** `claude/3.15.2-29-telegram-empty-filter`
**Issue:** #29 — Empty Telegram messages cause Claude API 400
**Mode:** MCA (bugfix)
**Author:** Claude

## Pipeline Compliance

| Step | Status | Evidence |
|------|--------|----------|
| 0. Observe | done | §0 run: γ lowest at A-, #29 selected via §0.6 (operational debt) |
| 1. Branch | done | `claude/3.15.2-29-telegram-empty-filter`, pre-flight passed |
| 2. Bootstrap | done | `docs/gamma/cdd/3.15.2/README.md` created as first diff |
| 3. Gap | done | Empty Telegram messages → Claude API 400 → infinite retry |
| 4. Mode | done | MCA — runtime bug, code fix needed |
| 5. Design | N/A | Small bugfix per §1.3 — issue body is the design |
| 6. Contract | done | In commit message: gap, mode, scope, AC coverage |
| 7. Plan | done | 3-step plan: filter in drain_tg, trace event, tests |
| 8. Tests | done | 4 filter predicate tests in cn_cmd_test.ml |
| 9. Code | done | cn_runtime.ml: empty-text check in drain_tg |
| 10. Docs | N/A | No operator-facing doc changes needed for this fix |
| 11. Self-coherence | this file | |

## Triadic Assessment

- **α (PATTERN): A** — Single filter point in drain_tg, consistent with existing rejected_user pattern. No structural change.
- **β (RELATION): A** — Fix directly addresses the issue's root cause. Both ACs met. Trace event follows existing conventions.
- **γ (EXIT/PROCESS): A** — Full CDD pipeline followed. §0 observation performed. Pre-flight checks passed. AC self-check done before commit. Tests written.

## Known Coherence Debt

- #28 (daemon retry limit) remains open — this fix prevents the trigger but doesn't add the safety net. #28 is next in the §0.6 operational debt queue.
- No build verification possible (no OCaml toolchain in this environment). CI will validate.

## Reviewer Notes

- The filter is in `drain_tg` (cn_runtime.ml), not in `parse_update` (cn_telegram.ml). Reason: parse_update returns messages that drain_tg must advance the offset past. Filtering in parse_update would cause the offset to never advance, creating an infinite poll loop of the same filtered message.
- The filter uses `String.trim msg.text = ""` which catches both missing text (photo/sticker → `text=""` from parse_update) and whitespace-only text.
- Existing test for "no text field (photo message)" is unchanged — parse_update still returns `text=""` for these. The filter is the caller's responsibility.
