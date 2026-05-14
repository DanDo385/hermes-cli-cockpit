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
- `cmux`: repo workbench for Neovim editing, diffs, browser smoke tests, CLI coding agents, PR status, Obsidian notes, and dry-run-first Discord discussion posting.
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
  coding workbench: Neovim, diffs, browser tests, CLI agents, GitHub PR/discussion, Obsidian, Discord API drafts
```

This separation is intentional. Operational health and gateway ownership stay in `mission-*`; code changes and collaboration loops happen in `cmux`.
