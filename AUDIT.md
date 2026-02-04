# Project Audit – cn-agent v1.3.5

**Date:** 2026-02-04
**Branch:** `claude/repo-quality-audit-7Nwae`
**Auditor:** Independent automated audit (Claude Opus 4.5)
**Scope:** Full repo quality — code, documentation, architecture, security, testing, configuration, git practices, cross-file coherence.
**Prior audits:** v1.0.0, v1.2.1, v1.3.2, v1.3.3, v1.3.4 (same file, now replaced).

---

## 1. Executive Summary

cn-agent is a template repository for bootstrapping AI agent hubs on the git Coherence Network (git-CN). It contains a CLI tool (`cli/index.js`, 305 lines), six skills, six mindsets, a whitepaper (v2.0.3), and supporting documentation. The project is primarily Markdown (31 of 38 files) with a single JavaScript file and zero runtime dependencies.

**Key strengths:** Well-structured directory layout, clean hub/template separation, thorough whitepaper (v2.0.3), internally consistent TSC framework, strong git governance ("never self-merge"), zero dependencies in the CLI, no secrets in the repo, honest implementation-vs-spec tracking.

**Key weaknesses:** Zero tests, zero CI/CD, no linting, CLI has input validation gaps (agent name not sanitized), `package.json` incomplete, `.gitignore` fragile, two skills lack katas, the `experiments/` directory is orphaned, and the protocol spec is significantly ahead of the implementation (9 features specified but not built).

**Overall grade: B+** — strong documentation-driven project with engineering infrastructure gaps in testing, automation, and input validation.

---

## 2. Repository Overview

| Metric | Value |
|--------|-------|
| Total tracked files | 38 |
| Markdown files | 31 |
| JavaScript files | 1 (`cli/index.js`, 305 lines) |
| PDF files | 1 (`docs/CN-WHITEPAPER-v2.0.3.pdf`, 435 KB) |
| JSON files | 1 (`package.json`) |
| Runtime dependencies | 0 |
| Test files | 0 |
| CI/CD workflows | 0 |
| Linting config | None |
| License | Apache 2.0 |

---

## 3. Documentation Quality

### 3.1 README.md — Grade: A-

**Strengths:**
- Four-path audience dispatch table (human without agent, human with agent, agent told to cohere, agent exploring) is an effective navigation pattern.
- Step-by-step setup instructions with concrete commands.
- Clean repo structure table.
- Git-native coordination philosophy section is crisp.

**Weaknesses:**
- Version in heading (`v1.2.0`) is stale relative to `package.json` (`v1.3.2`). This is the first thing a visitor sees.
- The "Connect your agent" section (line 80) references `BOOTSTRAP.md` — the CLI no longer creates this file.
- The "Cohere as" section (lines 105–114) also references `BOOTSTRAP.md` and `Delete BOOTSTRAP.md when done`.
- Setup guide assumes Ubuntu/root; no mention of other OS or non-root setups.
- Missing: badges (build status, version, license), contributing guidelines, link to CHANGELOG.

### 3.2 Whitepaper (docs/CN-WHITEPAPER.md) — Grade: A

**Strengths:**
- Well-structured with clear abstract, motivation (§1), problem statement (§2), and solution (§3–9).
- Honest implementation status section (§10) — rare and valuable.
- Proper RFC 2119 keywords in normative appendix.
- Substrate/projection distinction is cleanly articulated.
- Self-referential: the document applies its own projection-robustness principles (plain §N cross-references, `text` language tags on code fences).

**Weaknesses:**
- PDF version duplicates the Markdown as a binary file (435 KB). PDFs don't diff in git and bloat history on updates.
- Reference [3] Reddit URL contains a slug that may not resolve correctly.

### 3.3 GLOSSARY.md — Grade: A-

**Strengths:**
- 17 entries covering all key terms.
- Doc-local versioning note explaining the versioning scheme.
- Cross-references to whitepaper sections and external specs.
- Clear ownership annotations (e.g., "Owner: daily-routine skill" for `memory/`).

**Weaknesses:**
- Emoji in α/β/γ entry (🧩🤝🚪) is decorative and inconsistent with the whitepaper's projection-robustness principle.
- The `state/reflections/` structure diagram duplicates what's in `skills/reflect/SKILL.md`.

### 3.4 CHANGELOG.md — Grade: B

**Strengths:**
- TSC coherence grading per release is a novel and useful practice.
- Header explains the grading formula and axes.
- Disclaimer about intuition-level vs formal scores.

**Weaknesses:**
- Only 8 versions listed; no detailed change notes per version — only one-line coherence summaries.
- A reader cannot reconstruct what actually changed in any release from the changelog alone.
- No link to tagged releases or diff URLs.

### 3.5 Skill Documentation — Grade: B+

**Strengths:**
- Consistent TERMS / INPUTS / EFFECTS structure across all six skills.
- Ownership & Schema sections in reflect and daily-routine are clear.
- configure-agent has excellent UX principles ("one question at a time", "invisible plumbing").
- CHANGELOGs in self-cohere and configure-agent track skill-level evolution.

**Weaknesses:**
- reflect SKILL.md is 370 lines — the longest skill by 3x. Six cadence templates are structurally repetitive.
- self-cohere and configure-agent have no kata files. DOJO.md lists only 4 katas (01, 02, 03, 13).
- hello-world thread filename format `yyyyddmmhhmmss` puts day before month — non-standard and inconsistent with ISO 8601 and the `YYYY-MM-DD` format used everywhere else in the project.

### 3.6 Mindsets — Grade: A-

**Strengths:**
- COHERENCE.md is philosophically precise and practically actionable (Quick Self-Check section).
- ENGINEERING.md has clear, opinionated principles (KISS, YAGNI, "never self-merge").
- OPERATIONS.md covers memory management, heartbeats, and group chat behavior.
- MEMES.md enforces "share only what you live."

**Weaknesses:**
- PERSONALITY.md is all placeholders.
- WRITING.md is 25 lines with an instance-specific `sag` (ElevenLabs TTS) reference in a template repo.
- ENGINEERING.md has a dash/em-dash inconsistency (line 10 uses `-`, other lines use `—`).

### 3.7 Spec Files — Grade: A

**Strengths:**
- SOUL.md is concise and sets real behavioral constraints.
- USER.md has proper placeholder markers and a structured working contract.
- AGENTS.md covers startup checklist, memory management, safety, external vs internal actions, and git-native coordination.
- TOOLS.md explains the separation of tools from skills.

**Weaknesses:**
- HEARTBEAT.md is minimal (two example bullet points). Intentional for a template, but thin relative to other specs.

---

## 4. Code Quality — CLI (`cli/index.js`)

### 4.1 Overview

305 lines of Node.js using only built-in modules (`child_process`, `path`, `fs`, `readline`). Zero external dependencies. This is a significant positive — the CLI ships exactly what it needs with no supply chain risk.

### 4.2 Strengths

- **No shell injection:** Uses `spawn()` with array args throughout (line 55), never `exec()` with string concatenation.
- **Pre-flight checks:** Validates git identity (lines 90–103), GitHub CLI presence and auth (lines 112–124), and workspace existence (lines 83–87).
- **Fallback handling:** If `gh repo create` fails, falls back to manual remote add (lines 247–252).
- **Clean separation:** Utility functions (`run`, `runCapture`, `ask`) are small and focused.
- **Version from package.json:** `const VERSION = require('../package.json').version` (line 22) — single source of truth.

### 4.3 Issues

| # | Severity | Issue | Location |
|---|----------|-------|----------|
| C1 | **HIGH** | Agent name not sanitized — special characters flow into paths, git messages, GitHub repo names | `cli/index.js:142-147` |
| C2 | **MEDIUM** | `git pull --ff-only` with no fallback — crashes unhelpfully if template diverged | `cli/index.js:133` |
| C3 | **MEDIUM** | Hardcoded workspace path `/root/.openclaw/workspace` — no env var override | `cli/index.js:49` |
| C4 | **MEDIUM** | Duplicate `gh api user` call — same API call on lines 119 and 150 | `cli/index.js:119,150` |
| C5 | **LOW** | `readline` interface not closed on error paths (lines 84, 101, 117, 123) | `cli/index.js` |
| C6 | **LOW** | `fs.rmSync` with `force: true` on user-confirmed delete | `cli/index.js:189` |
| C7 | **LOW** | No timeout on git/gh spawn calls | `cli/index.js` |
| C8 | **LOW** | ANSI colors unconditional — no `NO_COLOR` env var support | `cli/index.js:25-27` |
| C9 | **LOW** | "New name" fallback (line 192–199) skips re-deriving hubRepo, hubUrl — these still reference the old name for confirmation/GitHub steps | `cli/index.js:192-199` |

**C1 Detail (HIGH):** The agent name input (line 142) is transformed by `.toLowerCase().replace(/\s+/g, '-')` (line 147). This only strips whitespace. A name like `../../etc` would produce `cn-../../etc`, and `path.join(WORKSPACE_ROOT, hubName)` would resolve to a directory outside the workspace. Characters like `"`, `'`, `` ` ``, `$`, `/`, `\`, or `..` could cause unexpected behavior in directory creation (`fs.mkdirSync`), git commits, or GitHub repo names. The fix is to reject or strip non-alphanumeric/non-hyphen characters.

**C9 Detail (LOW):** When the user chooses "New name" at the collision prompt (line 191–199), `hubDir` is updated but `hubRepo` and `hubUrl` (derived on lines 166–167) are not recalculated. The git push and `gh repo create` on lines 245–246 would use the old name.

### 4.4 Code Style

- No linter configuration (eslint, prettier, etc.).
- Consistent 2-space indentation.
- Good use of inline comments explaining each step.
- `async` IIFE pattern at top level is idiomatic.
- ANSI helpers are simple and appropriate (no dependency for terminal colors).

---

## 5. Architecture & Design

### 5.1 Two-Repo Model — Grade: A

The hub/template separation is well-conceived and consistently described across CLI, self-cohere, AGENTS.md, README, and the whitepaper:
- **Hub** (`cn-<agentname>/`): personal identity, specs, state, threads
- **Template** (`cn-agent/`): shared skills, mindsets, docs

The symlink strategy (CLI creates workspace-root symlinks pointing into hub and template) is pragmatic for the OpenClaw runtime. The model is clearly documented in self-cohere SKILL.md with a visual directory tree.

### 5.2 Skill Framework — Grade: B+

TERMS/INPUTS/EFFECTS is a clean contract format. All six skills follow it. The ownership model (reflect owns `state/reflections/`, daily-routine orchestrates) resolves a real design tension.

Gaps:
- No skill discovery mechanism — an agent must know which skills exist by reading `skills/README.md`.
- No skill versioning convention — some skills have versions in their title, others don't.
- No skill dependency declaration — daily-routine depends on reflect, but this is stated in prose, not machine-readable format.

### 5.3 Protocol vs Implementation Gap — Grade: B-

The whitepaper specifies a full protocol (cn.json, .gitattributes, cn.thread.v1, signature verification) that is largely unimplemented. §10.2 lists nine features that are specified but not built:

| Protocol Feature | Implementation Status |
|-----------------|----------------------|
| `cn.json` manifest | Not implemented |
| `.gitattributes` with `merge=union` | Not implemented |
| `cn.thread.v1` schema | Not implemented (threads use pre-v1 format) |
| `state/peers.json` (JSON) | Not implemented (uses `peers.md` Markdown) |
| `threads/` at repo root | Not implemented (uses `state/threads/`) |
| Commit signing | Not implemented |
| Signature verification | Not implemented |
| Multiple `repo_urls` | Not implemented |
| Operational metrics (A.9) | Not implemented |

The honest acknowledgment in §10.3 is valuable, but the gap is significant. Another implementation reading this repo would find a template that doesn't conform to its own spec.

### 5.4 Experiments Directory — Grade: D

`experiments/external-surface-replies.md` is a 212-line design document describing a reply loop for external surfaces (Moltbook, Twitter, etc.) with SQL schemas, cron patterns, and Bohmian dialogue guidance. It has:
- No README or index file
- No cross-reference from any other document in the repo
- No status indicator (active? archived? superseded?)
- References to "Moltbook" — which the whitepaper explicitly frames as a failed platform
- Instance-specific content (`author: 'usurobor'`) in a template repo

This directory is an orphan. It should be documented, archived, or removed.

---

## 6. Testing & CI/CD — Grade: F

| Category | Status |
|----------|--------|
| Unit tests | None |
| Integration tests | None |
| End-to-end tests | None |
| CI/CD pipeline | None (`.github/workflows/` does not exist) |
| Linting (eslint/prettier) | None |
| Type checking | None (no TypeScript, no JSDoc) |
| Pre-commit hooks | None |
| Code coverage | None |
| Markdown validation | None (no broken-link checker, no schema validation) |

**Impact:** The CLI is the only code file and has zero tests. It interacts with `git`, `gh`, the filesystem, and user input — all testable. Minimum viable test coverage:

1. `--help` outputs help text and exits 0
2. `--version` outputs version matching `package.json` and exits 0
3. `run()` rejects on non-zero exit code
4. `runCapture()` returns trimmed stdout
5. Hub name derivation: `"My Agent"` → `"cn-my-agent"`
6. Agent name validation rejects `../`, special characters
7. Directory creation produces expected structure

Node's built-in `node:test` module (available since Node 18, the minimum engine version) would require zero dependencies.

---

## 7. Configuration & Dependencies

### 7.1 package.json — Grade: C+

```json
{
  "name": "@usurobor/cn-agent-setup",
  "version": "1.3.2",
  "description": "CLI to clone/update cn-agent on an OpenClaw host and show the self-cohere cue",
  "bin": { "cn-agent-setup": "cli/index.js" },
  "files": [ "cli/index.js" ],
  "scripts": { "start": "node cli/index.js" },
  "author": "usurobor",
  "license": "Apache-2.0",
  "engines": { "node": ">=18" }
}
```

**Issues:**
- `description` is stale — doesn't mention hub creation, GitHub repo creation, or symlinks.
- Missing `repository` field — npm page shows "No repository."
- Missing `keywords` — reduces discoverability.
- Missing `bugs` and `homepage` fields.
- No `test` script — `npm test` does nothing.
- `files` array only includes `cli/index.js` — correct for npm, but anyone installing the package expecting the full template gets only the CLI.

### 7.2 .gitignore — Grade: C+

Current contents:
```
memory/
media/
*.db
*.log
.DS_Store
```

**Missing entries:**
- `node_modules/` — one accidental `npm install` of any dependency pollutes the repo.
- `.env` / `.env.*` — prevents accidental secrets commits.
- `*.swp`, `*.swo`, `*~` — editor temp files.
- `.vscode/`, `.idea/` — IDE configurations.
- `coverage/` — if tests are ever added.

The current `.gitignore` works for the project's current state but is fragile against future changes.

---

## 8. Security

### 8.1 CLI Security — Grade: B

**Positive:**
- `spawn()` with array args — no shell injection vector.
- No `eval()`, `Function()`, or dynamic `require()`.
- No external HTTP requests (uses `git` and `gh` as subprocesses).
- No secrets stored or transmitted in code.

**Concerns:**
- **Agent name input not sanitized** (C1). Characters like `/`, `..`, `"`, `'`, `` ` ``, `$`, or Unicode flow into `path.join()`, `fs.mkdirSync()`, git commit messages, and `gh repo create`. While `path.join` handles some traversal, names containing `/` or `..` can still create directories outside the workspace.
- **`fs.rmSync` with `recursive: true, force: true`** (line 189) — called after user confirmation with abort as default (safe default).
- **`git push -u origin HEAD:main`** in fallback path (line 251) — could push to an existing `main` on a repo the user doesn't control if the name collides.

### 8.2 Spec Security Model — Grade: A-

- SOUL.md enforces "Private things stay private."
- AGENTS.md separates external vs internal actions with clear boundaries.
- OPERATIONS.md warns against loading MEMORY.md in shared contexts.
- USER.md working contract defines a correction protocol (TERMS/POINTER/EXIT).

### 8.3 Sensitive Files — Grade: A

No secrets, credentials, API keys, or `.env` files in the tracked tree. The `.gitignore` excludes `memory/` (runtime state).

---

## 9. Git Practices & Repo Hygiene

### 9.1 Branch Strategy — Grade: A-

Clean topic-branch workflow with `claude/` and `sigma/` prefixes. Branches are merged into `master` with descriptive merge commits. No stale branches accumulating.

### 9.2 Commit Messages — Grade: B+

- Scoped prefixes (`glossary:`, `CLI:`, `reflect:`, `docs:`) used consistently.
- Merge commits have custom, human-readable subjects.
- Some subjects exceed 72 characters (soft violation).
- No conventional commits standard (`feat:`, `fix:`) — uses project-specific scoping.

### 9.3 Contributor Identity — Grade: B+

Two name variants for the same human: `usurobor` and `Usurobor`. This is a `git config user.name` casing inconsistency. `Claude` and `Sigma` are intentional AI agent identities.

### 9.4 Large Files — Grade: B

One 435 KB PDF tracked directly. Binary files don't diff and bloat history on updates. Consider Git LFS or CI-generated PDFs.

---

## 10. Cross-File Coherence

### 10.1 Terminology Consistency — Grade: A-

Terms are used consistently:
- "hub" vs "template" — consistent everywhere after v1.3.x cleanup.
- "TSC", "α/β/γ", "CLP" — defined in GLOSSARY.md and used consistently.
- "TERMS/INPUTS/EFFECTS" — consistent across all skill files.

Minor inconsistencies:
- `peers.md` (implementation) vs `peers.json` (whitepaper spec).
- `state/threads/` (implementation) vs `threads/` (whitepaper spec).
- Thread file naming `yyyyddmmhhmmss` puts day before month; the rest of the project uses `YYYY-MM-DD`.

### 10.2 Version Coherence — Grade: B

| File | Version | Status |
|------|---------|--------|
| `package.json` | v1.3.2 | Current template semver |
| `README.md` | v1.2.0 | **Stale** — most visible version |
| `CHANGELOG.md` | v1.3.2 | Current |
| `GLOSSARY.md` | v1.3.0 | Doc-local |
| `DOJO.md` | v1.2.1 | Doc-local |
| `skills/README.md` | v1.2.0 | Doc-local |
| Whitepaper | v2.0.3 | Protocol version |

### 10.3 Structural Coherence — Grade: A-

The directory structure follows a clear pattern:
- `spec/` — identity and behavioral contracts
- `mindsets/` — thinking patterns
- `skills/<name>/` — operational capabilities
- `state/` — runtime state
- `docs/` — reference documentation

Every directory has a clear purpose. The only orphan is `experiments/`.

### 10.4 README–Reality Alignment — Grade: B

The README references `BOOTSTRAP.md` in two places (lines 80 and 105–114). The CLI no longer creates a `BOOTSTRAP.md` file — the self-cohere skill's v2.1.0 removed this dependency. A visitor following the README's "Cohere as" instructions would look for a file that doesn't exist.

---

## 11. Issues Found (Prioritized)

### HIGH

| # | Issue | Impact | Location |
|---|-------|--------|----------|
| H1 | **Zero tests, zero CI/CD** | No safety net for changes; CLI could break silently. With six skills and a CLI, there is meaningful surface area to test. | Entire project |
| H2 | **Agent name input not sanitized** | Directory traversal, unexpected repo names, or git errors from special characters. `/`, `..`, and shell metacharacters all pass through. | `cli/index.js:142-147` |
| H3 | **Protocol vs implementation gap** | 9 protocol features specified in whitepaper but not implemented. The template doesn't conform to its own spec. Acknowledged honestly in §10, but the gap is widening. | Whitepaper §10.2 vs repo |
| H4 | **README references nonexistent `BOOTSTRAP.md`** | The "Cohere as" instructions (lines 105–114) tell agents to read a file the CLI no longer creates. First-time agents following these instructions will fail. | `README.md:80,105-114` |

### MEDIUM

| # | Issue | Impact | Location |
|---|-------|--------|----------|
| M1 | **README version stale (`v1.2.0`)** | First impression suggests project is less maintained than it is. | `README.md:1` |
| M2 | **`git pull --ff-only` no fallback** | CLI crashes with unhelpful error if template has diverged. Flagged since v1.0.0 audit. | `cli/index.js:133` |
| M3 | **`.gitignore` incomplete** | Missing `node_modules/`, `.env*`, editor temps, IDE dirs. Fragile against accidental additions. | `.gitignore` |
| M4 | **`package.json` incomplete** | Missing `repository`, `keywords`, `bugs`, `homepage` fields. Stale `description`. | `package.json` |
| M5 | **reflect SKILL.md length (370 lines)** | Hardest skill to read/maintain. Six cadence templates are structurally repetitive. | `skills/reflect/SKILL.md` |
| M6 | **Thread file naming non-standard** | `yyyyddmmhhmmss` puts day before month; inconsistent with ISO 8601 and all other date formats in the project. | `state/threads/`, `skills/hello-world/` |
| M7 | **Hardcoded workspace path** | CLI only works on OpenClaw with root user. No env var override or `--workspace` flag. | `cli/index.js:49` |
| M8 | **`experiments/` uncontextualized** | 212-line design doc with no README, no cross-reference, no status, instance-specific content. | `experiments/` |
| M9 | **"New name" path doesn't update `hubRepo`/`hubUrl`** | When the user chooses a new name at collision, the variables used for GitHub repo creation still reference the old name. | `cli/index.js:192-199` |

### LOW

| # | Issue | Impact | Location |
|---|-------|--------|----------|
| L1 | Missing katas for self-cohere and configure-agent | Skills claim katas should exist but don't. | `skills/self-cohere/`, `skills/configure-agent/` |
| L2 | DOJO.md kata numbering gap (03→13) | Belt legend explains the scheme but gap is unexplained. | `docs/DOJO.md` |
| L3 | WRITING.md `sag` reference | Instance-specific (ElevenLabs TTS) in a template. | `mindsets/WRITING.md:24` |
| L4 | Duplicate `gh api user` call | Same API call on lines 119 and 150. Wastes a round-trip. | `cli/index.js:119,150` |
| L5 | ANSI colors unconditional | No `NO_COLOR` env var support. | `cli/index.js:25-27` |
| L6 | ENGINEERING.md em-dash inconsistency | Line 10 uses `-` where other lines use `—`. | `mindsets/ENGINEERING.md:10` |
| L7 | Emoji in framework tables | 🧩🤝🚪 in reflect/GLOSSARY α/β/γ entries. Inconsistent with projection-robustness principle. | `skills/reflect/SKILL.md`, `docs/GLOSSARY.md` |
| L8 | PDF tracked directly in git | Binary (435 KB) doesn't diff. Bloats history on updates. | `docs/CN-WHITEPAPER-v2.0.3.pdf` |
| L9 | Contributor name casing | `usurobor` vs `Usurobor` — inflates contributor count. | git config |
| L10 | `readline` not closed on early exits | Minor resource leak on error paths (process exits anyway). | `cli/index.js:84,101,117,123` |
| L11 | Coherence Walk metaphor duplicated verbatim | "Left, right, left, right" appears identically in 3 places. | `skills/reflect/SKILL.md`, `docs/GLOSSARY.md` |
| L12 | daily-routine cron format assumes specific runtime | JSON cron syntax is OpenClaw-specific; no crontab equivalent. | `skills/daily-routine/SKILL.md` |
| L13 | `state/` files in template repo | Template contains state files that conceptually belong in hubs. | `state/` |
| L14 | CHANGELOG lacks detailed change notes | Only one-line coherence summaries; can't reconstruct what changed. | `CHANGELOG.md` |
| L15 | `IDENTITY.md` in cleanup list | CLI line 259 still deletes `IDENTITY.md` — a filename that no longer exists in the template (renamed to `PERSONALITY.md`). Harmless but stale. | `cli/index.js:259` |

---

## 12. Prior Audit Tracking

Issues carried from the v1.3.4 audit with updated status:

| v1.3.4 Ref | Finding | Status | Notes |
|------------|---------|--------|-------|
| 4.4 | reflect SKILL.md length | **Open** | Still 370 lines |
| 4.5 | Emoji in framework table | **Open** | Still present |
| 4.7 | DOJO kata gap 03→13 | **Open** | Still unexplained |
| 4.9 | daily-routine cron assumption | **Open** | Still unstated |
| 4.10 | Coherence Walk duplication | **Open** | Still in 3 places |
| 4.11 | package.json stale/incomplete | **Open** | Still missing fields |
| 4.12 | state/ files in template | **Open** | Still present |
| 4.13 | git pull --ff-only | **Open** | Still no fallback |
| 4.14 | WRITING.md sag reference | **Open** | Still present |
| 4.15 | experiments/ uncontextualized | **Open** | Still orphaned |
| 4.16 | No tests | **Open** | Still zero |
| 4.17 | Missing katas | **Open** | self-cohere + configure-agent |
| 4.18 | ENGINEERING.md em-dash | **Open** | Still inconsistent |

**New findings in this audit:** H2 (input sanitization), H4 (BOOTSTRAP.md references), M1 (README version), M6 (thread naming), M9 (new-name path bug), L4 (duplicate API call), L5 (NO_COLOR), L10 (readline leak), L14 (CHANGELOG detail), L15 (stale IDENTITY.md cleanup).

**Total open findings: 13 carried + 10 new = 23 open.** All 13 v1.3.4 carried items remain open — no forward motion since the last audit.

---

## 13. Coherence Assessment (TSC Axes)

### 13.1 PATTERN (α) — Structural Consistency — Grade: A-

The repo structure is clean and consistent:
- 5 spec files, 6 mindsets, 6 skills, 3 docs — all follow their respective formats.
- TERMS/INPUTS/EFFECTS in all SKILL.md files.
- Placeholder markers in template specs.
- New skills (reflect, daily-routine) follow the established pattern.

Deductions:
- Thread file naming (`yyyyddmmhhmmss` vs ISO 8601).
- reflect SKILL.md is 3x the length of any other skill.
- README version stale.

### 13.2 RELATION (β) — Alignment Between Parts — Grade: A-

Cross-file references are mostly accurate. The glossary matches reality. The whitepaper and implementation are honestly differentiated (§10). The hub/template separation is consistently described.

Deductions:
- README references `BOOTSTRAP.md` which no longer exists in the flow.
- Protocol spec vs implementation gap (9 features specified but not built).
- `peers.md` (Markdown) vs `peers.json` (whitepaper spec).
- `state/threads/` (implementation) vs `threads/` (whitepaper spec).

### 13.3 EXIT/PROCESS (γ) — Evolution Stability — Grade: B+

Clean evolution through ~96 commits. "Never self-merge" governance is practiced. Merges are descriptive. The audit-driven improvement cycle (v1.0.0 → v1.3.4 → now) shows disciplined intent.

Deductions:
- 13 of 13 v1.3.4 open findings remain open — no forward motion on prior audit items.
- Zero tests means evolution has no safety net.
- No CI means regressions aren't caught automatically.
- The spec is evolving faster than the implementation, creating technical debt.

### 13.4 Aggregate

```
C_Σ = (A- · A- · B+)^(1/3) ≈ A- / B+
```

The project is structurally sound and internally coherent in its documentation. The primary drag is engineering infrastructure: no tests, no CI, no linting, unvalidated input, and accumulated open findings.

---

## 14. Recommendations (Prioritized)

### Must Address

1. **Fix README `BOOTSTRAP.md` references.** Lines 80, 105–114 describe a file the CLI no longer creates. Agents following these instructions will fail. This is a broken user path.

2. **Sanitize agent name input.** Reject or strip characters that aren't alphanumeric or hyphens. A simple regex like `/[^a-z0-9-]/g` applied after lowercasing would be sufficient. This closes directory traversal and unexpected repo name vectors.

3. **Add basic CLI tests.** Use Node's built-in `node:test` module (zero dependencies). Minimum: `--help` exits 0, `--version` matches `package.json`, name derivation logic, rejection of special characters.

4. **Add `git pull --ff-only` fallback.** On failure: inform the user, suggest manual resolution, exit cleanly.

### Should Address

5. **Fix the "new name" path** (lines 192–199) to recalculate `hubRepo` and `hubUrl`.

6. **Update README version** to match current release or remove the version from the heading.

7. **Harden `.gitignore`** with `node_modules/`, `.env*`, `*.swp`, `.vscode/`, `.idea/`.

8. **Complete `package.json`** — add `repository`, `keywords`, `bugs`, `homepage`; update `description`.

9. **Add a GitHub Actions CI workflow** — even `node cli/index.js --help && node cli/index.js --version` catches CLI breakage.

10. **Fix thread file naming** to use ISO 8601 (`yyyyMMddHHmmss` or similar).

11. **Contextualize `experiments/`** — add a README with status, or move to a branch, or delete.

12. **Add workspace path override** — env var `CN_WORKSPACE` or `--workspace` flag.

### Nice to Have

13. Extract reflect cadence templates to `skills/reflect/templates/`.
14. Remove emoji from framework tables (projection robustness).
15. Add katas for self-cohere and configure-agent.
16. Remove `sag` reference from WRITING.md.
17. Fix contributor name casing.
18. Add `NO_COLOR` env var support to CLI.
19. Cache the `gh api user` result to avoid the duplicate call.
20. Explain DOJO kata numbering scheme or renumber.
21. Consider Git LFS for the PDF or CI-generated PDFs.
22. Add detailed change notes to CHANGELOG entries.
23. Remove `IDENTITY.md` from the CLI cleanup list (line 259).

---

## 15. Scorecard

| Dimension | Grade | Weight | Notes |
|-----------|-------|--------|-------|
| Documentation | A- | High | Strong whitepaper, good README (stale refs), thorough glossary |
| Code Quality | B- | Medium | Clean CLI, but input validation gaps and a bug in the "new name" path |
| Architecture | B+ | High | Two-repo model is solid; protocol gap is the main concern |
| Testing & CI | F | High | Zero tests, zero CI, zero linting |
| Security | B | Medium | No injection, no secrets; input sanitization missing |
| Git Practices | A- | Medium | Good governance, clean history, minor hygiene issues |
| Configuration | C+ | Low | Incomplete package.json and .gitignore |
| Cross-file Coherence | A- | High | Consistent terminology; BOOTSTRAP.md references and version staleness are the gaps |

**Weighted Overall: B+**

### Compared to v1.3.4 Audit

The v1.3.4 audit graded the project `A` aggregate. This audit grades it **B+**. The difference is not regression — the project hasn't changed. The difference is scope: this audit examines code-level issues (input validation, CLI bugs, the "new name" path), engineering infrastructure (testing, CI, linting), configuration completeness, and README–reality alignment that the v1.3.4 audit did not cover in depth. The documentation quality remains high.

---

## 16. What's Done Well

1. **Zero-dependency CLI** — ships exactly what it needs, no supply chain risk.
2. **Whitepaper quality** — honest, well-structured, self-aware of its own projection failures.
3. **Audit-driven improvement** — five iterations of self-assessment. Rare and valuable practice.
4. **Git governance** — "never self-merge", descriptive merges, topic-branch workflow.
5. **TSC framework integration** — coherence is operationalized through the reflect skill and measured in the CHANGELOG.
6. **Hub/template separation** — clean, well-documented, consistently applied.
7. **No secrets in repo** — clean security posture.
8. **Apache 2.0 license** — clear, permissive, standard.
9. **Honest spec-vs-impl tracking** — §10 of the whitepaper doesn't pretend features exist when they don't.
10. **Spec file design** — SOUL.md is one of the better behavioral contracts for AI agents in the wild.
