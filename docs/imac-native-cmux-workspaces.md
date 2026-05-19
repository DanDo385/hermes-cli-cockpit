# iMac native cmux workspaces

This is the real cockpit track.

```text
iMac = native cmux visual cockpit
MBP  = remote tmux runtime host
```

Do not run native cmux on the MBP. The MBP keeps `mission-hermes` and `mission-openclaw` tmux sessions for durable runtime monitoring. The iMac runs native cmux for the visual desktop cockpit: browser panes, Finder-like file panels, Obsidian/vault surfaces, notifications, and MCP-rich composition.

## Current project-local cmux config

This repo now includes:

```text
.cmux/cmux.json
bin/imac-cmux-bootstrap
```

`cmux` discovers project-local config at:

```text
./.cmux/cmux.json
```

The config defines command palette actions for:

- Hermes Ops
- OpenClaw Ops
- Workspace Cards
- Vault Root
- Code Workbench
- Agent Deck
- Obsidian Vault

The terminal actions target the MBP over SSH/Tailscale:

```text
openclaw@100.84.204.2
```

## iMac bootstrap sequence

Run from the iMac:

```bash
cd /Users/openclaw/Code/hermes-cli-cockpit
bin/imac-cmux-bootstrap --check
bin/imac-cmux-bootstrap --install
bin/imac-cmux-bootstrap --reload-config
bin/imac-cmux-bootstrap --launch
```

If the iMac hostname is not obviously iMac/control-imac, allow it explicitly:

```bash
ALLOW_NON_IMAC_HOST=1 bin/imac-cmux-bootstrap --check
```

## Required SSH topology

The iMac must be able to SSH into the MBP without interactive prompts. The cmux actions depend on this.

Expected MBP target:

```text
openclaw@100.84.204.2
```

Expected MBP tmux sessions:

```text
mission-hermes
mission-openclaw
```

Probe from the iMac:

```bash
ssh -o BatchMode=yes openclaw@100.84.204.2 'hostname; tmux list-sessions'
```

If this fails with `Permission denied`, add the iMac public key to the MBP user's `~/.ssh/authorized_keys`, or configure Tailscale SSH.

## cmux docs grounding

Native cmux supports project-local and global configuration:

```text
./.cmux/cmux.json
./cmux.json
~/.config/cmux/cmux.json
```

Reload after config changes:

```bash
cmux reload-config
```

Native cmux features we are using or designing around:

- vertical workspace tabs
- split panes
- terminal surfaces
- in-app browser surfaces
- command palette actions
- surface tab bar buttons
- notification hooks
- socket/CLI automation

## First workspace model

Default cockpit shape:

```text
1 Hermes Ops      native cmux workspace, SSH surface into MBP mission-hermes, vault/docs/browser surfaces nearby
2 OpenClaw Ops    native cmux workspace, SSH surface into MBP mission-openclaw, OpenClaw browser/docs nearby
3 Code Workbench  native cmux workspace for repo editing, browser testing, file/vault panels, agents
4 Agent Deck      native cmux workspace for worktrees, agents, GitHub/Discord/community surfaces
```

Browser Lab and Community Lab are embedded surfaces, not default top-level workspaces unless Dan asks.

## Manual blocker right now

From the MBP, SSH to the iMac currently reaches port 22 but fails auth:

```text
Permission denied (publickey,password,keyboard-interactive)
```

To let Hermes configure the iMac directly, add the MBP public key to the iMac user's authorized keys:

```text
ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIPmMt/YfNh3RGFeuHCQBjVMb67sOdw4Pw7yn65aduREd
```

Once that is authorized, Hermes can SSH to the iMac and run the bootstrap directly there.
