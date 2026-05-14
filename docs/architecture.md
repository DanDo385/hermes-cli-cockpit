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
control host: Hermes gateway, cron, logs, sessions, mission tmux cockpit
dev host: project repos, dev servers, Neovim/Cursor, coding agents
```

## Command families

- `mission`: control-host tmux cockpit.
- `cmux`: repo workbench for Neovim editing, diffs, browser smoke tests, CLI coding agents, PR status, Obsidian notes, and dry-run-first Discord discussion posting. This repo helper must be renamed before official native cmux is installed into PATH.
- `cctx`: cwd-aware context card/router for cmux. It detects project/vault/agent context and prints safe launch commands without rebuilding or mutating gateways.
- `hermes-health`: compact operator dashboard for gateway, cron, cron model routes, Gemini quota history, 1Password, SSH agent, and ports.
- `devdash`: project tmux cockpit.
- `proj`: project picker.
- `ports`, `port-who`: read-only port inspection with TOML registry classification (`REGISTERED`, `UNKNOWN`, `EXPECTED_DOWN`, `CONFLICT`).
- `port-kill`: future guarded port mutation.
- `agent-task`, `agent-review`, `agent-merge`, `agent-drop`: worktree agent coordination.

## Cockpit layers

```text
mission-hermes / mission-openclaw
  operational control plane: chat, gateway, cron, sessions, heartbeat, ports, secrets, logs

cmux
  flexible workspace deck: project/session rail, Neovim, diffs, browser tests, CLI agents, Hermes/OpenClaw bridge, GitHub, Obsidian, Discord API drafts, contextual scratch terminals
```

This separation is intentional. Operational health and gateway ownership stay in `mission-*`; code changes and collaboration loops happen in `cmux`.

The design target is outside-in navigation:

```text
project or Hermes conversation -> context router -> center surface -> nearby scratch/action pane
```

`docs/cmux-ai-assistant-workspace-design.md` is the north-star product/workflow recommendation across the three planes: mission control, coding workbench, and agent orchestration/community. `docs/cmux-flexible-workspace.md` tracks the native cmux/Kickstart/agent-deck research and cwd-aware router path. `bin/cctx` is the first implementation seed for that router.
