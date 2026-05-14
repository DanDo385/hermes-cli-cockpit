# Hermes CLI Cockpit

Hermes CLI Cockpit is a terminal-native operator cockpit for AI-assisted development across machines, projects, ports, secrets, diffs, and agent worktrees.

## Current status

This repo is being extracted from Dan's private MBP/iMac Hermes workflow into a public-ready CLI project.

## Design source of truth

Private Obsidian master page:

```text
/Users/openclaw/.hermes/workspace/projects/hermes-cli-cockpit/cli-mission-control-master-page.md
```

Research links:

```text
/Users/openclaw/.hermes/workspace/resources/links/2026-05-09-cli-cockpit-research-links.md
```

Keep this public repo sanitized. Do not copy private hostnames, secrets, account details, or raw logs into public docs.

## First commands

```bash
bin/mission --no-attach
bin/mission-hermes --no-attach
bin/mission-openclaw --no-attach
bin/cmux --no-attach
bin/cctx
bin/hermes-health
bin/ports
bin/ports --registry config/ports.toml
bin/port-who 3000
```

Installed commands during local development:

```bash
mission                 # legacy/current Hermes cockpit: mission-control
mission-hermes          # mirrored Hermes cockpit: mission-hermes
mission-openclaw        # mirrored OpenClaw dev cockpit: mission-openclaw
cmux                    # coding/review/test/discussion workbench: cmux
cctx                    # cwd/project/session context card for cmux
mission-web-hermes      # static Hermes mission page, default port 4173
mission-web-openclaw    # static OpenClaw mission page, default port 4174
hermes-health
ports
port-who 3000
```

- `~/.local/bin/mission`, `~/.local/bin/mission-hermes`, `~/.local/bin/mission-openclaw`, `~/.local/bin/cmux`, `~/.local/bin/cctx`, `~/.local/bin/mission-web-hermes`, `~/.local/bin/mission-web-openclaw`, `~/.local/bin/ports`, and `~/.local/bin/port-who` should symlink to `~/Code/hermes-cli-cockpit/bin/*`.
- `config/ports.toml` is the local active port registry. `config/ports.example.toml` is a copyable template.
- `ports` classifications: `REGISTERED` active known listener, `UNKNOWN` active unregistered listener, `EXPECTED_DOWN` registered port not listening, `CONFLICT` duplicate service claims.

## Dual mission controls

`mission-hermes` and `mission-openclaw` intentionally have the same tmux layout:

```text
0 chat       main CLI/TUI chat
1 overview   health, URLs, process summary
2 gateway    gateway status/control hints
3 cron       scheduler/jobs
4 sessions   stored sessions/processes
5 heartbeat  heartbeat/system events
6 ports      port ownership and registry
7 secrets    1Password/SSH readiness, no raw values
8 logs       detailed runtime logs
9 scratch    shell
```

Every window has a shortcut pane at the bottom with the local navigation map. Use the bottom tmux bar numbers with `Ctrl-b 0-9`.

Default page ports:

```text
Hermes static page:    4173
OpenClaw static page:  4174
OpenClaw dev gateway:  19001
OpenClaw browser ctrl: 19003
```

## CMUX workbench

`cmux` is the code/edit/review/test/discussion layer that references the live mission sessions without replacing them.

```text
mission-hermes      Hermes operations/control plane
mission-openclaw    OpenClaw dev/sandbox operations/control plane
cmux                repo editing, review, browser testing, PRs, Obsidian, Discord discussions
```

The current implementation is a tmux-backed flexible workspace deck inspired by native cmux:

```text
left rail       project/session cards
center          active surface: editor, agent, browser, PR, vault, API
right/bottom    contextual scratch terminals near command lists
ops bridge      Hermes/OpenClaw mission sessions remain reachable
```

Run:

```bash
cmux --reset
cmux --two-sessions --reset
cmux --project=/path/to/repo --reset
cctx /path/to/repo
source /Users/openclaw/Code/hermes-cli-cockpit/bin/cctx-hook.zsh
cctx-on
```

See `docs/cmux.md` for the operational map, `docs/cmux-flexible-workspace.md` for the deeper design/research notes covering the screenshot, native cmux, Kickstart Neovim, and agent-deck, and `docs/remote-ai-cockpit-plan.md` for the local cmux + remote tmux + Tailscale implementation plan.

Important: official native cmux also installs a `cmux` CLI. This repo currently has a tmux-backed `bin/cmux` helper, so the long-term plan is to rename the repo helper before installing official cmux into PATH.

`cctx` is the cwd-aware context router. It prints a workspace card for the current directory, writes `~/.cache/hermes-cli-cockpit/cctx.env`, and shows the exact `cmux --project=...` command for that context without rebuilding sessions or touching gateways. `cmux` rereads that state so status panes can repaint around the active context. The zsh hook is opt-in and can be disabled with `cctx-off`.

When the training wheels get annoying, launch without guide panes:

```bash
CMUX_GUIDE_MODE=off cmux --reset
```

OpenClaw defaults to `--dev` and loopback gateway operation. For iMac access to the OpenClaw dashboard, prefer SSH/Tailscale port forwarding over broad unauthenticated exposure.

## Project goals

- MBP control-plane tmux cockpit.
- iMac project development cockpit.
- Project registry and picker.
- Port registry and inspector.
- 1Password + direnv secret-loading pattern.
- Git diff/review workflow.
- ACP + git-worktree agent coordination.

## Safety rules

- Observe before mutating.
- No raw secrets in repos.
- No automatic agent merges.
- One agent, one branch, one worktree.
