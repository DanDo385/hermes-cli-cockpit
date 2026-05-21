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

Hermes and OpenClaw mission controls (mirrored layout, separate sessions):

```text
Ctrl-b 0      chat       conversation (Hermes | or OpenClaw |)
Ctrl-b 1      sessions   list, browse, continue, export
Ctrl-b 2      models     default, aux, cron routes
Ctrl-b 3      tools      tools, skills, MCPs
Ctrl-b 4      secrets    1Password readiness, no raw secrets
Ctrl-b 5      notes      vault runbooks
Ctrl-b 6      gateway    gateway health
Ctrl-b 7      cron       scheduler + latest output
Ctrl-b 8      ops        logs, ports, launchd
Ctrl-b 9      scratch    command sheet
```

Coding Workbench (`cockpit-workbench`):

```text
Ctrl-b 4      agents     Agent Deck slots (not Hermes/OpenClaw chat)
Ctrl-b 5      runway     git diff, test, build
Ctrl-b 6      review     diff gates before accept
Ctrl-b 8      missions   attach mission-hermes / mission-openclaw / cockpit-community
```

The mirrored mission sessions are:

```text
mission-hermes        Hermes CLI Mission Control
mission-openclaw      OpenClaw CLI Mission Control
cockpit-workbench     Coding Workbench
cockpit-community     Open Source Radar / Community
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
