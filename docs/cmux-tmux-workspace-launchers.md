# Native cmux to MBP tmux launchers

## Purpose

This project maps a small number of native iMac cmux workspaces to durable MBP tmux sessions. It does **not** mirror every tmux window into cmux.

```text
cmux workspace = operating plane
MBP tmux session = persistent runtime
MBP tmux window = sub-page within that runtime
```

## Configured primary pages

| cmux page | MBP tmux target | default tmux window |
|---|---|---|
| Hermes Ops | `mission-hermes` | `chat` |
| OpenClaw Ops | `mission-openclaw` | `chat` |
| Code Workbench | `cockpit-workbench` | `hub` |
| Agent Deck | `cockpit-workbench:agents` | `agents` |
| Community / Review | `cockpit-community` | `projects` |

The definitions live in `.cmux/cmux.json` as inline `workspace` actions.

## Lifecycle behavior

Each primary action uses cmux `restart: "ignore"`.

```text
First launch: cmux creates the named page and opens one SSH terminal.
Later launch: cmux selects the existing page unchanged.
```

This protects attached tmux clients. It never runs `tmux kill-session`, `tmux kill-server`, gateway restart, or launchd mutation.

## One-time deployment on the iMac

The iMac checkout must be on the cockpit pilot branch and cmux must be opened with the repo as its project root:

```bash
cd ~/Code/hermes-cli-cockpit
git pull --ff-only
bin/imac-cmux-bootstrap --reload-config
bin/imac-cmux-bootstrap --launch
```

cmux will ask to trust each new project action fingerprint. Inspect the command in the prompt. The expected action only SSHes to `mbp-runtime` and attaches or creates the documented tmux session.

## Opening pages

Use any one of these inside the cmux cockpit project:

1. Surface tab bar: click `Hermes Mission Control`, `OpenClaw Mission Control`, `Coding Workbench`, `Agent Deck`, or `OSS Radar / Community`.
2. Command Palette: open it and search the same title.
3. New-workspace plus menu: choose the named page. The workspace actions opt into this menu.

Do not use the Browser Surface action for the local Browser Lab. Browser Lab stays independently managed.

## Daily navigation

After opening a cmux page, cmux handles the outer workspace selection. The SSH terminal is a tmux client. Use tmux for the inner pages:

```text
Ctrl-b w     tmux window picker
Ctrl-b 0-9   direct numbered tmux window
Ctrl-b n/p   next/previous tmux window
Ctrl-b z     zoom/unzoom active tmux pane
Ctrl-b d     detach without killing the session
```

Examples:

```text
Hermes Ops -> Ctrl-b 6: gateway, Ctrl-b 7: cron, Ctrl-b 1: sessions
Code Workbench -> Ctrl-b 1: editor, Ctrl-b 4: agents, Ctrl-b 5: runway, Ctrl-b 6: review
Community / Review -> Ctrl-b 1: GitHub, Ctrl-b 2: my PRs, Ctrl-b 3: discussions
```

## Right-side rail

The `bin/cmux-cockpit-page` launcher tries to reveal the project Dock without moving focus. The Dock is a cmux project feature, not a tmux pane.

- Operational cmux pages: use the Dock after the project action trust prompt is accepted.
- Browser Lab: leave the Dock hidden unless you later ask for browser-specific guidance.

The Dock does not own or restart tmux. It only renders command/keybinding guidance and may expose safe read-only status commands.

## Verification

From the MBP staging checkout:

```bash
tests/test_cmux_dock_rail.sh
tests/test_danos_cmux_adapter.sh
tests/test_keystroke_mentor.sh
```

From a terminal surface **inside** native cmux on the iMac:

```bash
cmux current-workspace --json
cmux list-workspaces --json
cmux right-sidebar mode
```

Outside cmux, control-socket calls should fail. Do not set `CMUX_SOCKET_MODE=allowAll` to bypass that boundary.
