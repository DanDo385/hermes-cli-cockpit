# Navigation

Hermes CLI Cockpit uses tmux. In tmux, the "pages" across the bottom are called windows. Panes are the cards inside a page.

## First minute

1. Run `mission-hermes` for Hermes or `mission-openclaw` for OpenClaw.
2. Start on `0 chat` and talk to the selected assistant in the large pane.
3. Read the live overview/status page if anything looks off.
4. Use `Ctrl-b z` to zoom a noisy pane.
5. Use `Ctrl-b d` to detach safely. The cockpit keeps running.

For coding/review/browser/GitHub/Discord work, run `cmux`. It references the mission sessions but keeps code editing out of the ops cockpit.

Legacy note: `mission` still opens the original Hermes `mission-control` session.

## Core keyboard model

The tmux prefix is:

```text
Ctrl-b
```

Press `Ctrl-b`, release both keys, then press the next key.

## Window/page map

```text
Ctrl-b 0      chat       selected assistant CLI/TUI conversation
Ctrl-b 1      overview   health, URLs, process summary
Ctrl-b 2      gateway    gateway status/control hints
Ctrl-b 3      cron       scheduler/jobs
Ctrl-b 4      sessions   stored sessions/processes
Ctrl-b 5      heartbeat  heartbeat/system events
Ctrl-b 6      ports      local listeners + port registry
Ctrl-b 7      secrets    safe 1Password/SSH readiness, no raw values
Ctrl-b 8      logs       detailed runtime logs
Ctrl-b 9      scratch    blank command shell
```

The mirrored sessions are:

```text
mission-hermes     tmux session mission-hermes
mission-openclaw   tmux session mission-openclaw
cmux               tmux session cmux
```

Every window includes a bottom shortcut pane. Use the numbers shown in the bottom tmux bar. If a live session predates a layout change, run `mission-hermes --reset` or `mission-openclaw --reset` to rebuild the cockpit pages.

## Window navigation

```text
Ctrl-b w      window picker/list
Ctrl-b n      next window
Ctrl-b p      previous window
Ctrl-b 0-9    jump directly to a page
```

## Pane navigation

```text
Ctrl-b ←      pane left
Ctrl-b →      pane right
Ctrl-b ↑      pane up
Ctrl-b ↓      pane down
Ctrl-b o      next pane
Ctrl-b z      zoom/unzoom current pane
```

## Safe exit

```text
Ctrl-b d      detach from tmux without killing the cockpit
```

Detach means the cockpit keeps running on the MBP. You can reattach later with:

```bash
mission-hermes
mission-openclaw
cmux
```

or directly:

```bash
tmux attach -d -t mission-hermes
tmux attach -d -t mission-openclaw
```

Legacy Hermes cockpit:

```bash
mission
tmux attach -d -t mission-control
```
