# Architecture

Hermes CLI Cockpit separates source code from installed commands:

```text
~/Code/hermes-cli-cockpit/
  source repo, docs, examples, tests

~/.local/bin/
  PATH-accessible executable symlinks
```

Initial local deployment:

```text
~/.local/bin/mission -> ~/Code/hermes-cli-cockpit/bin/mission
```

## Machine roles

```text
iMac: native cmux visual client, browser panes, local workspace sidebar, notifications
MBP:  remote tmux persistence layer for all multi-pane/window terminal layouts
launchd/systemd: durable gateway/service owner
```

The iMac should use native cmux over SSH/Tailscale into the MBP. The MBP should not be asked to run native cmux; it should run tmux sessions such as `mission-hermes`, `mission-openclaw`, `cockpit-workbench`, and agent-deck's isolated tmux socket.

## Command families

- `mission`: control-host tmux cockpit.
- `cmux`: repo workbench for Neovim editing, diffs, browser smoke tests, CLI coding agents, PR status, Obsidian notes, and dry-run-first Discord discussion posting. This tmux-backed repo helper must be renamed before official native cmux is installed into PATH.
- `cctx`: cwd-aware context card/router for cmux. It detects project/vault/agent context and prints safe launch commands without rebuilding or mutating gateways.
- `cockpit-workspaces`: read-only four-workspace card deck for the iMac native-cmux -> MBP remote-tmux topology.
- `hermes-health`: compact operator dashboard for gateway, cron, cron model routes, Gemini quota history, 1Password, SSH agent, and ports.
- `devdash`: project tmux cockpit.
- `proj`: project picker.
- `ports`, `port-who`: read-only port inspection with TOML registry classification (`REGISTERED`, `UNKNOWN`, `EXPECTED_DOWN`, `CONFLICT`).
- `port-kill`: future guarded port mutation.
- `agent-task`, `agent-review`, `agent-merge`, `agent-drop`: worktree agent coordination.

## Cockpit layers

```text
mission-hermes / mission-openclaw
  operational control plane: chat, gateway, cron, sessions, heartbeat, ports, secrets, logs, Obsidian/browser pointers

cockpit-workbench / current tmux-backed cmux helper
  flexible workspace deck: Neovim, CLI coding agents, diffs, JS/React/Next browser tests, GitHub, Obsidian, contextual scratch terminals

agent-deck
  orchestration plane: one-agent-one-worktree sessions, status/cost board, GitHub/Discord/open-source tracking
```

This separation is intentional. Operational health and gateway ownership stay in `mission-*`; code changes and collaboration loops happen in the workbench; parallel-agent orchestration happens in agent-deck.

The native cmux target is four local workspaces, all pointing at MBP tmux/runtime surfaces:

```text
1 Hermes Ops      -> cmux ssh -> tmux mission-hermes + Obsidian browser surface
2 OpenClaw Ops    -> cmux ssh -> tmux mission-openclaw + OpenClaw/vault browser surface
3 Code Workbench  -> cmux ssh -> tmux cockpit-workbench + app/browser test surface
4 Agent Deck      -> cmux ssh -> agent-deck tmux socket + GitHub/Discord/community surfaces
```

The design target is outside-in navigation:

```text
project or Hermes conversation -> context router -> center surface -> nearby scratch/action pane
```

`docs/cmux-ai-assistant-workspace-design.md` is the north-star product/workflow recommendation across the three planes: mission control, coding workbench, and agent orchestration/community. `docs/cmux-flexible-workspace.md` tracks the native cmux/Kickstart/agent-deck research and cwd-aware router path. `bin/cctx` is the first implementation seed for that router.
