# Ports

`ports` and `port-who` are read-only port-inspection commands for Hermes CLI Cockpit.

## Commands

```bash
ports
ports --local
ports --all
ports --registry config/ports.toml
port-who 3000
```

## Current behavior

- Lists listening TCP sockets on the current host using `lsof`.
- Shows host, mode, timestamp, and active registry path.
- Classifies active listeners as `REGISTERED`, `UNKNOWN`, or `CONFLICT` when a registry is available.
- Emits `EXPECTED_DOWN` rows for registered ports that are not currently listening.
- Maps registered listeners to service and role names from TOML sections/keys.
- Flags `CONFLICT` when more than one service claims the same port.
- `port-who <port>` reports the process listening on one port.
- No process killing is implemented in this slice.

## MBP mission-control ports

```text
4173   hermes-mission-control web page
4174   openclaw-mission-control web page
19001  openclaw-mission-control dev gateway
19003  openclaw-mission-control browser-control
4000   litellm-proxy local proxy
6463   Discord desktop local RPC
```

Notes:
- `mission-web-hermes` serves the Hermes static page on 4173 if that port is free; it refuses to replace an existing listener.
- `mission-web-openclaw` serves the OpenClaw static page on 4174.
- OpenClaw gateway/browser-control ports are loopback by default. For iMac dashboard access, use SSH/Tailscale forwarding unless you deliberately configure authenticated tailnet exposure.

## Registry lookup order

`ports` looks for a registry in this order:

1. `--registry <path>`
2. `HERMES_COCKPIT_PORTS_CONFIG`
3. `config/ports.toml` next to this repo
4. `~/.config/hermes-cli-cockpit/ports.toml`

## Registry format

```toml
[portfolio-site]
host = "dev-host"
frontend = 3000
preview = 3001

[litellm-proxy]
host = "control-host"
local_proxy = 4000
```

Rules:

- Section name = service name.
- Numeric keys = roles mapped to TCP ports.
- Non-numeric keys like `host` are metadata and ignored by the current classifier.
- Dynamic/random browser debug ports should usually stay unregistered.
- `REGISTERED` means exactly one service claims an active listening port.
- `UNKNOWN` means an active listener is not in the registry.
- `EXPECTED_DOWN` means a registered port is not currently listening.
- `CONFLICT` means multiple services claim the same port; do not treat it as safe.

## Safety rule

Port inspection comes before port mutation. `port-kill` should be added only after the read-only workflow is useful and should require confirmation.

## Next behavior

- Add host-aware mode for MBP/iMac via SSH/Tailscale.
- Add guarded `port-kill <port>`.
