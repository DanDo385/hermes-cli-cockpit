# Remote AI Cockpit Implementation Plan

> For Hermes: keep repo implementation lean. Keep deep/tinker research in Obsidian. This plan is the operational blueprint for local cmux + remote tmux + Tailscale + Hermes/OpenClaw/agent-deck.

## Goal

Build a remote AI cockpit where the local Mac runs native cmux as the terminal/browser/notification client, while the remote host owns persistent tmux sessions, Hermes/OpenClaw gateways, Neovim/Kickstart, browser-test servers, Obsidian vault access, Discord/API helpers, and agent-deck orchestration.

## Current source findings, checked 2026-05-14

- cmux latest GitHub release: `v0.64.6`, published 2026-05-14.
- cmux docs confirm native macOS app, Ghostty-based rendering, vertical tabs, notification panel, Unix socket/CLI API, embedded browser automation, and first-class `cmux ssh` remote workspaces.
- cmux docs now confirm SSH remote workspaces route browser panes through the remote network, relay remote `cmux notify` calls to the local sidebar, reconnect dropped SSH sessions, and upload a remote `cmuxd-remote` relay.
- cmux changelog `v0.64.4+` confirms Hermes Agent hook support and SSH workspace polish.
- agent-deck latest GitHub release: `v1.9.4`, published 2026-05-14.
- agent-deck README confirms remote instance support via `agent-deck remote add`, Tailscale recommendation for reaching remote services, conductor mode, cost dashboard, per-agent support, and tmux socket isolation.
- Hermes Agent latest release checked: `v2026.5.7` / v0.13.0. Relevant additions: durable Kanban multi-agent board, stronger gateway restart/session survival, browser/video tools, cron `no_agent`, provider plugins, gateway platform hardening.

## Architectural decision

Use real cmux for the local app layer. Do not continue treating this repo's `bin/cmux` as the long-term command name because official cmux also installs a `cmux` CLI.

Recommended rename path:

```text
Current repo helper: /Users/openclaw/Code/hermes-cli-cockpit/bin/cmux
Future repo helper:  /Users/openclaw/Code/hermes-cli-cockpit/bin/cockpit-workbench
Temporary shim:      /Users/openclaw/.local/bin/cockpit-workbench
Official cmux CLI:   /usr/local/bin/cmux -> /Applications/cmux.app/Contents/Resources/bin/cmux
```

Reason: official cmux automation commands like `cmux ssh`, `cmux notify`, `cmux browser`, `cmux list-workspaces`, and `cmux reload-config` must not be shadowed by our repo helper.

## Session model

Preferred model: one cmux window, several vertical workspaces, each attached to stable remote tmux sessions.

```text
Local Mac
└── cmux native app
    ├── Workspace: Hermes Ops       -> cmux ssh remote -> tmux attach -t mission-hermes
    ├── Workspace: OpenClaw Dev     -> cmux ssh remote -> tmux attach -t mission-openclaw
    ├── Workspace: Code Workbench   -> cmux ssh remote -> tmux attach -t cockpit-workbench
    ├── Workspace: Agent Deck       -> cmux ssh remote -> tmux attach -t agentdeck-home OR agent-deck
    └── Browser panes               -> routed through remote workspace network

Remote host
├── tmux session: mission-hermes
├── tmux session: mission-openclaw
├── tmux session: cockpit-workbench
├── agent-deck's isolated tmux server: tmux -L agent-deck
├── Hermes gateway owned by launchd/systemd, not ad-hoc tmux
├── OpenClaw dev gateway loopback/sandbox by default
├── Neovim/Kickstart
└── /Users/openclaw/.hermes/workspace Obsidian vault
```

## Files to create or update

### 1. Local Mac: official cmux CLI symlink

Only after installing cmux.app:

```bash
sudo ln -sf "/Applications/cmux.app/Contents/Resources/bin/cmux" /usr/local/bin/cmux
```

Verification:

```bash
/usr/local/bin/cmux list-workspaces --json
```

### 2. Local Mac: SSH config

File:

```text
/Users/openclaw/.ssh/config
```

Template:

```sshconfig
Host ai-remote
  HostName REPLACE_WITH_TAILSCALE_MAGICDNS_OR_IP
  User openclaw
  IdentityFile /Users/openclaw/.ssh/id_ed25519
  IdentitiesOnly yes
  ServerAliveInterval 20
  ServerAliveCountMax 2
  ControlMaster auto
  ControlPath /Users/openclaw/.ssh/cm-%r@%h:%p
  ControlPersist 10m
```

Use the real Tailscale MagicDNS hostname once confirmed.

### 3. Local Mac: Ghostty config consumed by cmux

File:

```text
/Users/openclaw/.config/ghostty/config
```

Minimum additions:

```text
font-family = SF Mono
font-size = 13
scrollback-limit = 50000000

# Shift+Enter multiline support for agent CLIs that treat Enter as submit.
keybind = shift+enter=text:\x1b\x0d
```

### 4. Local Mac: cmux app config

File:

```text
/Users/openclaw/.config/cmux/cmux.json
```

Lean starter:

```jsonc
{
  "$schema": "https://raw.githubusercontent.com/manaflow-ai/cmux/main/web/data/cmux.schema.json",
  "schemaVersion": 1,
  "browser": {
    "openTerminalLinksInCmuxBrowser": true,
    "hostsToOpenInEmbeddedBrowser": ["localhost", "127.0.0.1", "*.ts.net"]
  },
  "terminal": {
    "autoResumeAgentSessions": true
  }
}
```

Reload:

```bash
/usr/local/bin/cmux reload-config
```

### 5. Remote host: tmux config

File:

```text
/Users/openclaw/.tmux.conf
```

Starter:

```tmux
# Remote persistence layer for local cmux.
set -g mouse on
set -g focus-events on
set -g history-limit 100000
set -g set-clipboard on
set -g allow-passthrough on
set -g escape-time 10
set -g detach-on-destroy off

# Keep remote panes stable when attached from different clients.
setw -g aggressive-resize off
setw -g window-size smallest

# Human navigation fallbacks.
bind h select-pane -L
bind j select-pane -D
bind k select-pane -U
bind l select-pane -R
bind r source-file /Users/openclaw/.tmux.conf \; display-message "tmux config reloaded"
```

Why `allow-passthrough on`: cmux notification escape sequences and terminal integrations need escape sequences to pass through tmux.

### 6. Remote host: cockpit shell helpers

File:

```text
/Users/openclaw/.config/hermes-cli-cockpit/remote-ai-cockpit.zsh
```

Starter:

```zsh
# Source from /Users/openclaw/.zshrc on the remote host.

cmux_notify() {
  local title="${1:-Remote AI Cockpit}"
  local body="${2:-Task finished}"
  if command -v cmux >/dev/null 2>&1; then
    cmux notify --title "$title" --body "$body" 2>/dev/null || true
  else
    printf '\e]777;notify;%s;%s\a' "$title" "$body"
  fi
}

hermes_tmux() {
  tmux new-session -Ad -s mission-hermes
  tmux attach -t mission-hermes
}

openclaw_tmux() {
  tmux new-session -Ad -s mission-openclaw
  tmux attach -t mission-openclaw
}

workbench_tmux() {
  tmux new-session -Ad -s cockpit-workbench -c /Users/openclaw/Code/hermes-cli-cockpit
  tmux attach -t cockpit-workbench
}

vault() {
  cd /Users/openclaw/.hermes/workspace || return
  ${EDITOR:-nvim} .
}

agents() {
  if command -v agent-deck >/dev/null 2>&1; then
    agent-deck
  else
    echo "agent-deck not installed. Install with: brew install asheshgoplani/tap/agent-deck"
    return 127
  fi
}
```

Add to remote `/Users/openclaw/.zshrc`:

```zsh
[ -r /Users/openclaw/.config/hermes-cli-cockpit/remote-ai-cockpit.zsh ] && source /Users/openclaw/.config/hermes-cli-cockpit/remote-ai-cockpit.zsh
```

### 7. Remote host: agent-deck config

File:

```text
/Users/openclaw/.agent-deck/config.toml
```

Starter additions:

```toml
[tmux]
socket_name = "agent-deck"
mouse = true

[costs]
cost_line_template = "{cost_today} today | {cost_this_week} wk"
cost_line_hide_when_zero = true
```

Reason: socket isolation prevents agent-deck from mutating or crashing the user's normal tmux server.

### 8. Local or remote: register remote in agent-deck

If managing remote sessions from local agent-deck:

```bash
agent-deck remote add ai-remote openclaw@REPLACE_WITH_TAILSCALE_MAGICDNS_OR_IP
agent-deck remote list
agent-deck remote sessions ai-remote
```

If running agent-deck entirely on the remote host, skip `remote add` and launch from the remote workspace:

```bash
agent-deck
```

Recommended first implementation: run agent-deck on the remote host inside a cmux SSH workspace. Add `agent-deck remote` later if useful.

### 9. Repo helper scripts to add later

Do not implement until official cmux CLI is installed and the helper name collision is resolved.

Create:

```text
/Users/openclaw/Code/hermes-cli-cockpit/bin/cockpit-remote
/Users/openclaw/Code/hermes-cli-cockpit/bin/cockpit-smoke
/Users/openclaw/Code/hermes-cli-cockpit/templates/remote/tmux.conf
/Users/openclaw/Code/hermes-cli-cockpit/templates/remote/remote-ai-cockpit.zsh
/Users/openclaw/Code/hermes-cli-cockpit/templates/local/cmux.json
/Users/openclaw/Code/hermes-cli-cockpit/templates/local/ssh-config.example
```

`cockpit-remote` should preflight the remote host, seed tmux sessions, then open cmux SSH:

```bash
ssh ai-remote 'tmux new-session -Ad -s mission-hermes; tmux new-session -Ad -s mission-openclaw; tmux new-session -Ad -s cockpit-workbench -c /Users/openclaw/Code/hermes-cli-cockpit'
/usr/local/bin/cmux ssh ai-remote --name "AI Cockpit"
```

`cockpit-smoke` should run non-destructive checks and avoid killing existing sessions. It may create or seed named tmux sessions, so do not call it read-only.

## Browser testing loop

Use cmux browser panes for human-visible smoke tests, not as the only CI.

Remote dev server example:

```bash
cd /Users/openclaw/Code/hermes-cli-cockpit
python3 -m http.server 4175 --bind 127.0.0.1
```

From the cmux SSH workspace browser pane:

```bash
/usr/local/bin/cmux browser open http://localhost:4175
/usr/local/bin/cmux browser identify
/usr/local/bin/cmux browser surface:2 wait --load-state complete --timeout-ms 15000
/usr/local/bin/cmux browser surface:2 snapshot --compact
/usr/local/bin/cmux browser surface:2 screenshot --out /tmp/cockpit-smoke.png
```

Because cmux SSH browser panes route through the remote network, `localhost:4175` should refer to the remote host, not the local Mac.

## Hermes-specific rules

- Keep production Hermes gateway owned by launchd/systemd. Do not start/stop production gateway casually from tmux panes.
- Use tmux for visibility and manual control, not as the service supervisor.
- Interactive Hermes CLI requires a real PTY. For persistent interactive sessions, run it inside tmux.
- For one-shot work, use `hermes chat -q ...` with explicit timeout or background process.
- Enable browser/discord/file/terminal toolsets in Hermes only where needed; start new sessions after tool changes.
- Use `/Users/openclaw/.hermes/workspace` as the canonical Obsidian vault/workspace path.
- Keep OpenClaw dev gateway loopback/sandboxed unless explicitly promoting it.

## Security considerations

- Tailscale should be the only network exposure path at first. No public port forwarding.
- cmux socket default should remain `cmux processes only`; avoid `CMUX_SOCKET_MODE=allowAll` on shared machines.
- SSH config should use key auth and ControlMaster, but not `StrictHostKeyChecking=no` except throwaway tests.
- agent-deck web mode must bind to `127.0.0.1` and use `--token` before any tailnet/shared exposure.
- Discord/API tokens belong in 1Password or private env files, never repo templates.
- Obsidian vault symlink rule: one canonical real directory, `/Users/openclaw/.hermes/workspace`; symlink to it if needed, do not maintain duplicate vault clones.
- Do not run `tmux kill-server` on the remote. Use named sessions and socket isolation.

## Gotchas

1. Official `cmux` CLI name conflicts with this repo's current `/Users/openclaw/.local/bin/cmux` helper. Rename the repo helper before installing official cmux CLI into PATH.
2. cmux app restore is not a process supervisor. tmux remains the persistence layer for live processes.
3. cmux SSH now has remote workspace/session relay features, so avoid overbuilding manual SSH forwarding.
4. agent-deck socket isolation is opt-in and immutable per existing session; new config does not migrate old sessions automatically.
5. agent-deck has had tmux/session crash hotfixes recently; keep it current and avoid running ancient versions.
6. Different clients attached to the same tmux session can fight over size. Use `window-size smallest` and avoid attaching phone + desktop to active edit panes unless needed.
7. cmux browser automation target IDs are surface-specific. Smoke scripts must discover IDs dynamically via `cmux browser identify` or JSON output.

## One-command non-destructive validation sequence

After hostnames are filled and official cmux is installed, run locally:

```bash
AI_REMOTE=ai-remote bash -lc '
set -euo pipefail
printf "[1/8] local official cmux...\n"
command -v /usr/local/bin/cmux >/dev/null
/usr/local/bin/cmux list-workspaces --json >/tmp/cmux-workspaces.json

printf "[2/8] tailscale/ssh reachability...\n"
ssh -o BatchMode=yes -o ConnectTimeout=8 "$AI_REMOTE" "hostname; uname -a" >/tmp/cockpit-ssh.txt

printf "[3/8] remote toolchain...\n"
ssh "$AI_REMOTE" "command -v tmux && command -v zsh && command -v nvim && command -v hermes" >/tmp/cockpit-tools.txt

printf "[4/8] remote tmux config syntax...\n"
ssh "$AI_REMOTE" "tmux -f /Users/openclaw/.tmux.conf start-server \; display-message ok" >/tmp/cockpit-tmux.txt

printf "[5/8] seed persistent sessions safely...\n"
ssh "$AI_REMOTE" "tmux new-session -Ad -s mission-hermes; tmux new-session -Ad -s mission-openclaw; tmux new-session -Ad -s cockpit-workbench -c /Users/openclaw/Code/hermes-cli-cockpit; tmux list-sessions" >/tmp/cockpit-sessions.txt

printf "[6/8] Hermes health, read-only...\n"
ssh "$AI_REMOTE" "hermes doctor || true" >/tmp/cockpit-hermes-doctor.txt

printf "[7/8] agent-deck presence...\n"
ssh "$AI_REMOTE" "if command -v agent-deck >/dev/null; then agent-deck --version; agent-deck remote list --json 2>/dev/null || true; else echo agent-deck-missing; fi" >/tmp/cockpit-agent-deck.txt

printf "[8/8] open cmux SSH workspace...\n"
/usr/local/bin/cmux ssh "$AI_REMOTE" --name "AI Cockpit Smoke"
'
```

Expected result:

- `/tmp/cmux-workspaces.json` exists locally.
- SSH reaches the Tailscale host.
- Remote tmux sessions exist and survive detach.
- Hermes doctor output is captured without mutating gateway state.
- agent-deck version or `agent-deck-missing` is captured.
- cmux opens a remote workspace.

## Next implementation slices

1. Rename repo `bin/cmux` helper to avoid official cmux CLI collision.
2. Add `cockpit-remote` helper with read-only preflight and non-destructive tmux seeding.
3. Add `cockpit-smoke` helper that runs the one-command validation sequence with readable pass/fail output.
4. Add templates for remote `.tmux.conf`, remote zsh helpers, local cmux config, and SSH config.
5. Add cmux browser smoke helper that discovers browser surface IDs dynamically.
6. Add agent-board pane that summarizes Hermes Kanban + agent-deck status without owning either runtime.
7. Add optional notification hooks using `cmux notify` first, OSC 777 fallback second.
