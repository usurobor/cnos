# Deploy

Ship a new cnos version to production agents.

---

## Inventory

| Agent | Host | Hub path | Mode | User |
|-------|------|----------|------|------|
| Pi | 143.198.14.19 | /home/cn/cn-pi | daemon | root |

Binary: `/usr/local/bin/cn`

---

## Steps

### 1. Build & release (from dev machine)

```bash
cd cnos
# Merge, tag, push (triggers CI → builds binaries)
git push origin main --tags
# Wait for release workflow
gh run watch
# Create GitHub release
gh release create vX.Y.Z --title "vX.Y.Z: Summary" --notes-file RELEASE.md
```

### 2. Update binary on target

```bash
ssh root@143.198.14.19

# Download to tmp first (binary may be locked by running daemon)
curl -fsSL -o /tmp/cn-new \
  "https://github.com/usurobor/cnos/releases/download/vX.Y.Z/cn-linux-x64"
chmod +x /tmp/cn-new
mv /tmp/cn-new /usr/local/bin/cn
cn --version  # verify
```

### 3. Restart daemon

```bash
# Kill old daemon
pkill -f "cn agent --daemon"

# Start new daemon
cd /home/cn/cn-pi
nohup cn agent --daemon > /var/log/cn-pi-daemon.log 2>&1 &

# Verify
ps aux | grep "cn agent" | grep -v grep
```

### 4. Verify

```bash
cn --version          # correct version
tail -f /var/log/cn-pi-daemon.log  # no errors
```

---

## One-liner

```bash
ssh root@143.198.14.19 'curl -fsSL -o /tmp/cn-new "https://github.com/usurobor/cnos/releases/download/vX.Y.Z/cn-linux-x64" && chmod +x /tmp/cn-new && mv /tmp/cn-new /usr/local/bin/cn && pkill -f "cn agent --daemon"; sleep 1; cd /home/cn/cn-pi && nohup cn agent --daemon > /var/log/cn-pi-daemon.log 2>&1 & sleep 2 && cn --version && ps aux | grep "cn agent" | grep -v grep'
```

---

## Notes

- `cn update` has a bug: the binary download succeeds but then the git-based source update runs and overwrites with a stale build. Use direct binary download instead.
- Always download to `/tmp` first then `mv` — the running daemon locks the binary.
- Pi has no cron, no systemd unit — daemon mode only (`cn agent --daemon`).
- Hub config: `/home/cn/cn-pi/.cn/config.json`
- Secrets: `/home/cn/cn-pi/.cn/secrets.env`
