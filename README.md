# Hermes CLI Cockpit

Hermes CLI Cockpit is a terminal-native operator cockpit for AI-assisted development across machines, projects, ports, secrets, diffs, and agent worktrees.

## Current status

This repo is being extracted from Dan's private MBP/iMac Hermes workflow into a public-ready CLI project.

## First commands

```bash
bin/mission --no-attach
bin/hermes-health
bin/ports
bin/ports --registry config/ports.toml
bin/port-who 3000
```

Installed commands during local development:

```bash
mission
hermes-health
ports
port-who 3000
```

- `~/.local/bin/mission`, `~/.local/bin/ports`, and `~/.local/bin/port-who` should symlink to `~/Code/hermes-cli-cockpit/bin/*`.
- `config/ports.toml` is the local active port registry. `config/ports.example.toml` is a copyable template.
- `ports` classifications: `REGISTERED` active known listener, `UNKNOWN` active unregistered listener, `EXPECTED_DOWN` registered port not listening, `CONFLICT` duplicate service claims.

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
