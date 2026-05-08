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
- `devdash`: project tmux cockpit.
- `proj`: project picker.
- `ports`, `port-who`: read-only port inspection.
- `port-kill`: future guarded port mutation.
- `agent-task`, `agent-review`, `agent-merge`, `agent-drop`: worktree agent coordination.
