# Hermes CLI Cockpit

Hermes CLI Cockpit is a terminal-native operator cockpit for AI-assisted development across machines, projects, ports, secrets, diffs, and agent worktrees.

## Current status

This repo is being extracted from Dan's private MBP/iMac Hermes workflow into a public-ready CLI project.

## Design source of truth

Private Obsidian master page:

```text
$HOME/.hermes/workspace/projects/hermes-cli-cockpit/cli-mission-control-master-page.md
```

Research links:

```text
$HOME/.hermes/workspace/resources/links/2026-05-09-cli-cockpit-research-links.md
```

Keep this public repo sanitized. Do not copy private hostnames, secrets, account details, or raw logs into public docs.

## First commands

Native cmux cockpit work belongs on the iMac. MBP tmux runtime pages now live separately in `hermes-tmux-workspaces`.

```bash
# iMac native cmux path
bin/imac-cmux-bootstrap --check
bin/imac-cmux-bootstrap --install
bin/imac-cmux-bootstrap --reload-config
bin/imac-cmux-bootstrap --launch

# MBP/runtime helper probes kept here until the split is fully published
bin/mission --no-attach
bin/mission-hermes --no-attach
bin/mission-openclaw --no-attach
bin/cctx
bin/cockpit-workspaces verify
bin/cockpit-workspaces list
bin/cockpit-workspaces show coding-workbench
bin/cockpit-workspaces show open-source-radar
bin/cockpit-workspaces inventory agent-deck
bin/cockpit-community --no-attach
bin/keystroke-mentor --context nvim --limit 8
bin/agent-worktree list
bin/agent-worktree create --slug fix-login-flow --agent codex --no-launch
bin/a2a-bridge agent-card | python3 -m json.tool
bin/browser-smoke --directory web --path /hermes/ --expect 'Hermes Mission Control' --path /openclaw/ --expect 'OpenClaw Mission Control'
bin/hermes-health
bin/ports
bin/ports --registry config/ports.toml
bin/port-who 3000
```

Installed commands during local development:

```bash
mission                 # legacy/current Hermes cockpit: mission-control
mission-hermes          # mirrored Hermes cockpit: mission-hermes
mission-openclaw        # mirrored OpenClaw cockpit: mission-openclaw
cmux                    # upstream native cmux on the iMac only; do not point this name at MBP tmux helpers
cctx                    # cwd/project/session context card for cmux
cockpit-workspaces      # read-only iMac cmux -> MBP tmux workspace cards
agent-worktree          # one-agent/one-branch/one-worktree slot manager
a2a-bridge              # local Agent Card + JSON-RPC stdio bridge
browser-smoke           # local HTTP front-end/cockpit smoke checker
mission-web-hermes      # static Hermes mission page, default port 4173
mission-web-openclaw    # static OpenClaw mission page, default port 4174
hermes-health
ports
port-who 3000
```

- `~/.local/bin/mission`, `~/.local/bin/mission-hermes`, `~/.local/bin/mission-openclaw`, `~/.local/bin/cctx`, `~/.local/bin/cockpit-workspaces`, `~/.local/bin/mission-web-hermes`, `~/.local/bin/mission-web-openclaw`, `~/.local/bin/ports`, and `~/.local/bin/port-who` should symlink to `~/Code/hermes-cli-cockpit/bin/*`. Do not symlink `~/.local/bin/cmux` on the MBP; reserve `cmux` for upstream native cmux on the iMac.
- `config/ports.toml` is the local active port registry. `config/ports.example.toml` is a copyable template.
- `ports` classifications: `REGISTERED` active known listener, `UNKNOWN` active unregistered listener, `EXPECTED_DOWN` registered port not listening, `CONFLICT` duplicate service claims.

## Dual mission controls

`mission-hermes` and `mission-openclaw` are **peer** AI assistant/runtime surfaces with the same mission-control shape. Do not collapse them into one generic agent pane.

```text
0 chat       Hermes | or OpenClaw | conversation
1 sessions   list, browse, continue, resume, export (where supported)
2 models     default, delegation, auxiliary, cron routes
3 tools      tools, skills, MCP list/test/status
4 secrets    1Password/SSH readiness, no raw values
5 notes      Obsidian vault runbooks at ~/.hermes/workspace
6 gateway    gateway health + control hints
7 cron       scheduler + latest job output
8 ops        logs, ports, processes, launchd/service health
9 scratch    command sheet shell
```

OpenClaw shows `unsupported/not configured` when a Hermes-equivalent feature is missing — the pane stays visible.

## Five cockpit workspaces

```text
1 Hermes Tool / Hermes CLI Mission Control    mission-hermes
2 OpenClaw Tool / OpenClaw CLI Mission Control mission-openclaw
3 Coding Workbench                            cockpit-workbench (tmux-workbench)
4 Agent Deck                                  cockpit-workbench:agents
5 Open Source Radar / Community               cockpit-community
```

```bash
bin/cockpit-workspaces verify
bin/cockpit-workspaces list
bin/cockpit-community --no-attach
bin/keystroke-mentor --context nvim --watch --interval 30
```

Default page ports:

```text
Hermes static page:    4173
OpenClaw static page:  4174
OpenClaw lab gateway:  19001
OpenClaw browser ctrl: 19003
```

## Native cmux cockpit

Native cmux is the iMac visual cockpit layer. It is not the MBP tmux monitor, and it is not a service supervisor.

Think of the cockpit as three clean layers:

```text
+----------------------------+       SSH / Tailscale       +-----------------------------+
| iMac desktop cockpit       | ==========================> | MBP runtime cockpit         |
| native cmux visual client  |                             | tmux sessions persist here  |
| browser/file/vault panes   | <=========================  | logs, gateways, agents      |
+----------------------------+       attach / detach       +-----------------------------+

cmux    = visual desktop shell on the iMac
tmux    = durable terminal workspaces on the MBP
launchd = service owner for durable gateways and daemons
```

The full ASCII operator manual for the MBP runtime layer lives in the split runtime repo:

```text
https://github.com/DanDo385/hermes-tmux-workspaces
```

This repo carries the iMac native-cmux layer:

```text
.cmux/cmux.json              project-local native cmux actions and buttons
bin/imac-cmux-bootstrap      iMac-only install/check/reload/launch helper
bin/cockpit-workspaces       read-only workspace cards for cmux -> tmux routing
```

### What the cmux buttons open

Native cmux buttons on the iMac open SSH-backed tmux sessions on the MBP:

```text
+------------------+-------------------------------------+---------------------------------------------+
| cmux action       | MBP target                          | Use it for                                  |
+------------------+-------------------------------------+---------------------------------------------+
| Hermes Ops        | mission-hermes                      | Hermes gateway, cron, logs, sessions       |
| OpenClaw Ops      | mission-openclaw                    | OpenClaw gateway, lab/debug surfaces       |
| Code Workbench    | cockpit-workbench                   | Neovim, tests, browser, agents, scratch    |
| Agent Deck        | cockpit-workbench:agents            | agent slots, worktrees, OSS/community flow |
| Browser Surface   | cockpit-workbench:browser           | app previews and browser smoke checks      |
| GitHub Review     | cockpit-workbench:github            | PRs, diffs, review/status checks           |
| Obsidian Notes    | cockpit-workbench:obsidian          | vault/project note workflow                |
| Discord Workflow  | cockpit-workbench:discord           | Discord/API readiness and draft/send flow  |
+------------------+-------------------------------------+---------------------------------------------+
```

The working SSH alias from the iMac to the MBP is `mbp-runtime`. The cmux config intentionally uses that alias.

### From the iMac desktop

Use this when your terminal is local to the iMac:

```bash
cd "$HOME/Code/hermes-cli-cockpit"

# Verify host, cmux config, native cmux app, and MBP SSH reachability.
bin/imac-cmux-bootstrap --check

# Install native cmux if it is missing.
bin/imac-cmux-bootstrap --install

# Reload .cmux/cmux.json after button/config edits.
bin/imac-cmux-bootstrap --reload-config

# Open the native cmux GUI on the iMac.
bin/imac-cmux-bootstrap --launch
```

Useful read-only cards:

```bash
bin/cockpit-workspaces list
bin/cockpit-workspaces show code
bin/cockpit-workspaces show agent-deck
bin/cockpit-workspaces commands agent-deck
bin/cockpit-workspaces inventory agent-deck
```

### If your visible terminal is SSH'd into the MBP

This is the common brain-bender. You may be sitting at the iMac, but the shell prompt may be running on the MBP. In that case, `tmux` commands affect the MBP directly, while native `cmux` still has to be launched on the iMac GUI.

From the MBP shell, launch or reload the iMac cmux app by SSHing back to the iMac:

```bash
# Launch native cmux on the iMac GUI.
ssh imac-cockpit 'cd "$HOME/Code/hermes-cli-cockpit" && bin/imac-cmux-bootstrap --launch'

# Reload cmux actions/buttons after .cmux/cmux.json changes.
ssh imac-cockpit 'cd "$HOME/Code/hermes-cli-cockpit" && bin/imac-cmux-bootstrap --reload-config'

# Check iMac cmux + MBP SSH reachability.
ssh imac-cockpit 'cd "$HOME/Code/hermes-cli-cockpit" && bin/imac-cmux-bootstrap --check'
```

If you only need the durable terminal workspace and do not need the iMac GUI, attach to tmux directly from the MBP shell:

```bash
tmux attach -d -t mission-hermes
tmux attach -d -t mission-openclaw
tmux attach -d -t cockpit-workbench
```

Jump straight to the most useful workbench pages:

```bash
# Browser testing surface.
tmux select-window -t cockpit-workbench:browser
tmux attach -d -t cockpit-workbench

# Agent Deck.
tmux select-window -t cockpit-workbench:agents
tmux attach -d -t cockpit-workbench

# GitHub review.
tmux select-window -t cockpit-workbench:github
tmux attach -d -t cockpit-workbench

# Obsidian notes.
tmux select-window -t cockpit-workbench:obsidian
tmux attach -d -t cockpit-workbench
```

### Safety and naming rules

Official native cmux owns the `cmux` CLI name on the iMac. Do not put this repo's historical tmux-backed `bin/cmux` on PATH. Keep MBP tmux helpers under explicit names like `cockpit-workbench`, `mbp-cockpit-tmux`, or the split `hermes-tmux-workspaces` repo.

`cctx` is the cwd-aware context router. It prints a workspace card for the current directory, writes `~/.cache/hermes-cli-cockpit/cctx.env`, and shows the exact `cmux --project=...` command for that context without rebuilding sessions or touching gateways. `cmux` rereads that state so status panes can repaint around the active context. The zsh hook is opt-in and can be disabled with `cctx-off`.

Agent Deck live inventory is read-only. It reports agent-deck presence, isolated tmux socket status, git worktrees, and empty/filled agent slots. Creating a worktree remains an explicit operator command.

When the training wheels get annoying in the tmux-backed prototype, launch without guide panes:

```bash
CMUX_GUIDE_MODE=off cmux --reset
```

See `docs/cmux-ai-assistant-workspace-design.md` for the north-star workspace recommendations across Hermes/OpenClaw ops, coding workbench, and agent-deck/community orchestration. See `docs/cmux.md` for the operational map, `docs/cmux-flexible-workspace.md` for the deeper design/research notes covering the screenshot, native cmux, Kickstart Neovim, and agent-deck, and `docs/remote-ai-cockpit-plan.md` for the local cmux + remote tmux + Tailscale implementation plan.

OpenClaw has two supported operator modes:

```text
normal mode   openclaw gateway status/run/start/install
lab mode      openclaw --dev gateway run --port 19001 --bind loopback --auth none --allow-unconfigured --verbose --compact
```

Use normal mode when Dan wants OpenClaw available as an assistant. Use dev/loopback mode for debugging gateway behavior, queueing, or crash isolation. The cockpit documents both, but it should not install/start/stop a persistent OpenClaw service without an explicit operator decision.

For iMac access to OpenClaw pages or gateway surfaces, prefer native cmux SSH browser routing or SSH/Tailscale forwarding over broad unauthenticated exposure.

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
