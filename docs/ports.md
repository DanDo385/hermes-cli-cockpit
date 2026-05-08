# Ports

`ports` and `port-who` are read-only port-inspection commands for Hermes CLI Cockpit.

## Commands

```bash
ports
ports --local
ports --all
port-who 3000
```

## Current behavior

- Lists listening TCP sockets on the current host using `lsof`.
- Shows host, mode, and timestamp.
- `port-who <port>` reports the process listening on one port.
- No process killing is implemented in this slice.

## Safety rule

Port inspection comes before port mutation. `port-kill` should be added only after the read-only workflow is useful and should require confirmation.

## Future behavior

- Compare live listeners against `config/ports.example.toml` / user registry.
- Add host-aware mode for MBP/iMac via SSH/Tailscale.
- Flag registered, unregistered, expected, and conflicting listeners.
- Add guarded `port-kill <port>`.
