# Navigation

Hermes CLI Cockpit uses tmux. In tmux, the "pages" across the bottom are called windows.

## Core keyboard model

The tmux prefix is:

```text
Ctrl-b
```

Press `Ctrl-b`, release both keys, then press the next key.

## Window navigation

```text
Ctrl-b w      window picker/list
Ctrl-b n      next window
Ctrl-b p      previous window
Ctrl-b 0      jump to window 0
Ctrl-b 1      jump to window 1
Ctrl-b 2      jump to window 2
Ctrl-b 3      jump to window 3
Ctrl-b 4      jump to window 4
Ctrl-b 5      jump to window 5
```

Use the numbers shown in the bottom tmux bar. Existing sessions may have `health` at a later number if it was added after launch.

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
mission
```

or:

```bash
tmux attach -t mission-control
```
