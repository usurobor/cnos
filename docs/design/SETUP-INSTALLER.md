# CN Setup & Installation — Design Doc

**Status:** Draft
**Date:** 2026-02-23
**Author:** usurobor (aka Axiom)
**Contributors:** Sigma

---

## 1. Problem

Users must manually: export env vars, create config files, write systemd units, and wire everything together. There is no single command that takes a fresh machine from "cn binary on PATH" to "daemon running, secrets stored, config written."

## 2. Goals

- **One command** (`cn setup`) takes a user from zero to running daemon
- **Idempotent** — safe to re-run; converges state without destroying existing config
- **Industry-standard** secrets handling — no secrets in JSON, no secrets in install pipes
- **Minimal** — no new dependencies, no framework, no global state

## 3. Non-Goals

- Cron/timer as a first-class deployment mode (users can DIY)
- Global/multi-hub config (`~/.config/cnos/...`) — YAGNI
- GUI or web-based setup
- Package manager distribution (apt/brew) — separate effort

## 4. Architecture

### 4.1 Installation vs Configuration

Two distinct phases, two distinct commands:

| Phase | Command | What it does | Requires root |
|-------|---------|-------------|---------------|
| **Install** | `curl ... \| sh` (or manual) | Places `cn` binary on PATH | Yes (writes to /usr/local/bin or similar) |
| **Configure** | `cn setup` | Interactive config, secrets, systemd | Yes (systemd operations) |

The installer script (`install.sh`) does **only** binary placement. No secrets, no config, no prompts. It can optionally print "run `cn setup` to configure."

### 4.2 What `cn setup` does

Run from inside a hub directory (a repo with `.cn/`). Idempotent — re-running updates values, preserves unknown config keys, never duplicates entries.

#### Step 1: Hub structure

Ensure `.cn/` directory exists. Create `.cn/config.json` if missing (empty `{}`).

#### Step 2: Interactive prompts

| Prompt | Required | Stored in | Notes |
|--------|----------|-----------|-------|
| Anthropic API key | Yes | `secrets.env` | Masked on re-run: `sk-ant-…abcd` |
| Telegram bot token | No | `secrets.env` | Masked on re-run |
| Allowed Telegram user IDs | Only if token set | `config.json` | Comma-separated; empty = deny all |
| Model | No | `config.json` | Default: `claude-sonnet-4-20250514` (or current) |

Pressing Enter on any prompt keeps the existing value.

#### Step 3: Write secrets

Write `.cn/secrets.env`:

```
# CN secrets — do not commit (chmod 600)
ANTHROPIC_KEY="sk-ant-..."
TELEGRAM_TOKEN="123456:ABCDEF..."
```

- `chmod 0600`
- Append `.cn/secrets.env` to `.gitignore` if not already present

#### Step 4: Write config

Write/update `.cn/config.json`:

```json
{
  "runtime": {
    "model": "claude-sonnet-4-20250514",
    "allowed_users": ["498316684"]
  }
}
```

Merge strategy: read existing JSON, update only known keys under `runtime`, preserve everything else.

#### Step 5: Validate (warn-only)

| Service | Method | Success | Failure |
|---------|--------|---------|---------|
| Anthropic | `GET /v1/models` with `x-api-key` + `anthropic-version` headers | 200 → ✓ | 401/403 → "invalid key"; network error → "unreachable" |
| Telegram | `GET /bot<token>/getMe` | 200 → ✓ (print bot username) | 401 → "invalid token" |

Validation failures **warn but do not block**. User may be offline, behind a proxy, etc.

#### Step 6: Install systemd service

Prompt: "Install and start cn as a systemd service? [Y/n]"

If yes:

1. Write unit file to `/etc/systemd/system/cn.service`:

```ini
[Unit]
Description=CN Agent Daemon
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
WorkingDirectory=<hub_path>
ExecStart=<cn_binary_path> agent --daemon
EnvironmentFile=<hub_path>/.cn/secrets.env
Restart=on-failure
RestartSec=10

[Install]
WantedBy=multi-user.target
```

2. `systemctl daemon-reload`
3. `systemctl enable --now cn.service`
4. Print status confirmation

If no: print the manual commands.

### 4.3 Secrets resolution (runtime)

When `Cn_config.load` resolves a secret:

```
1. Environment variable (if set and non-empty)  →  use it
2. .cn/secrets.env (hub-local file)              →  use it
3. Neither                                       →  None / error
```

Env vars always win. This lets users override per-invocation or via CI without touching files.

### 4.4 Dotenv parser spec

Minimal, zero-dependency parser for `.cn/secrets.env`:

- **Blank lines:** skip
- **Comment lines** (`# ...`): skip
- **Key-value lines:** `KEY=VALUE`
  - Key: everything before first `=`, trimmed
  - Value: everything after first `=`, trimmed, then strip one layer of surrounding `"` or `'`
- **No** `export` prefix
- **No** variable interpolation (`$VAR`, `${VAR}`)
- **No** multiline values
- **No** escape sequences (beyond outer quote stripping)

If the file doesn't exist or is unreadable, silently return empty (not an error — secrets may come from env).

### 4.5 Security

| Concern | Mitigation |
|---------|-----------|
| Secrets in git | `.cn/secrets.env` added to `.gitignore` by `cn setup` |
| File permissions | Created with 0600; `cn` warns at startup if more permissive |
| Secrets in config.json | Never. Model/users/settings only. |
| Secrets in install pipe | Never. `install.sh` handles binary only. |
| Git tracking check | `cn doctor` warns if `secrets.env` is tracked (optional, later) |

## 5. User journey

```
$ curl -fsSL https://cnos.dev/install.sh | sh
  ✓ cn installed to /usr/local/bin/cn

$ cd my-project
$ cn setup
  CN Setup
  ────────
  Anthropic API key: sk-ant-api03-xxxxx
  Telegram bot token (optional): 123456:ABCDEF
  Allowed Telegram user IDs: 498316684
  Model [claude-sonnet-4-20250514]:

  Validating...
  ✓ Anthropic API key valid
  ✓ Telegram bot @my_cn_bot

  Writing .cn/secrets.env (0600)... ✓
  Writing .cn/config.json... ✓
  Updating .gitignore... ✓

  Install as systemd service? [Y/n] y
  Writing /etc/systemd/system/cn.service... ✓
  Starting cn.service... ✓

  Done. cn is running.
  View logs: journalctl -u cn -f
```

Re-running:

```
$ cn setup
  CN Setup
  ────────
  Anthropic API key [sk-ant-…xxxx]:
  Telegram bot token [123…DEF]:
  Allowed Telegram user IDs [498316684]:
  Model [claude-sonnet-4-20250514]:

  Validating...
  ✓ Anthropic API key valid
  ✓ Telegram bot @my_cn_bot

  No changes detected. ✓
```

## 6. Implementation plan

| Patch | Scope | Depends on |
|-------|-------|-----------|
| **A** | Dotenv parser + `get_secret` with precedence in `Cn_config` | — |
| **B** | `cn setup` command (prompts, file writes, validation, systemd) | A |
| **C** | Docs update (README, CLI help) | B |

## 7. Open questions

1. **Unit file name:** `cn.service` assumes one hub per machine. Multi-hub would need `cn-<name>.service`. Punt for now?
2. **Non-systemd platforms:** macOS (launchd), BSDs. Document manual setup, or add launchd plist generation later?
3. **Upgrade story:** When `cn` binary updates, should `cn setup` re-run automatically, or just remind the user?
