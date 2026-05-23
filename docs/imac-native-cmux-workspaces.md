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
mbp-runtime
```

## iMac bootstrap sequence

Run from the iMac:

```bash
cd "$HOME/Code/hermes-cli-cockpit"
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
mbp-runtime
```

Expected MBP tmux sessions:

```text
mission-hermes
mission-openclaw
```

Probe from the iMac:

```bash
ssh -o BatchMode=yes mbp-runtime 'hostname; tmux list-sessions'
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

Six cockpit surfaces — Home is the overview, and Hermes/OpenClaw are not merged:

```text
1 DanOS Home / Cockpit Overview              local danos registry/home
2 Hermes Tool / Hermes CLI Mission Control   mission-hermes
3 OpenClaw Tool / OpenClaw CLI Mission Control mission-openclaw
4 Coding Workbench                           cockpit-workbench
5 Agent Orchestration / Agent Deck           cockpit-workbench:agents
6 Open Source Radar / Community              cockpit-community
```

OpenClaw missing Hermes-equivalent features show `unsupported/not configured` — panes stay visible.

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
