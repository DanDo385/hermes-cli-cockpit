# CMUX AI Assistant Workspace Design Recommendations

> For Hermes: this is the target product/design artifact. It translates cmux research into concrete workspace recommendations for Hermes, OpenClaw, Obsidian, browser testing, GitHub/Discord surfaces, and agent-deck orchestration.

Checked: 2026-05-14 17:30 EDT

## Goal

Design the optimal cmux-based operating workflow for AI assistants like Hermes and OpenClaw.

The final product is not merely a terminal layout. It is a CLI-native mission control system that exposes what the application can do through shell commands, tmux/cmux workspaces, persistent logs, session search, cron visibility, gateway/runtime health, browser testing, GitHub/PR status, Discord/community surfaces, Obsidian project context, and multi-agent orchestration tools.

## Source-backed cmux capabilities to design around

Current cmux docs and changelog confirm these primitives:

- Native macOS terminal app built with Swift/AppKit on libghostty.
- Vertical sidebar workspaces/tabs with metadata such as cwd, git branch, PRs, ports, and notification text.
- Split panes and pane-level surfaces, where surfaces can be terminal or browser panels.
- CLI plus Unix socket API for windows, workspaces, panes, surfaces, text input, screen reading, notifications, and browser control.
- Environment context inside cmux terminals: `CMUX_WORKSPACE_ID`, `CMUX_SURFACE_ID`, `CMUX_SOCKET_PATH`.
- `cmux ssh` remote workspaces, with browser panes routed through the remote workspace network.
- `cmux notify` plus OSC notification escape sequences for local rings/sidebar notifications from terminal processes.
- Browser panes with scriptable actions: navigate, inspect/snapshot, click, type/fill, screenshot, console/errors, and developer tools.
- Session restore currently restores layout/metadata/cwd/browser state better than live process state. tmux remains the process persistence layer.
- Hermes Agent hook support is present in recent cmux changelog entries.

Design implication: cmux should be treated as the local visual/control client. tmux, launchd/systemd, Hermes cron, and agent-deck remain runtime/process owners.

## The three planes

### Plane 1: Mission control / runtime operations

Purpose: answer "Is the assistant system healthy and what can I operate from the CLI?"

This plane owns visibility into:

- `mission-hermes` tmux session on the MBP/remote host.
- `mission-openclaw` tmux session on the MBP/remote host.
- Hermes gateway status and logs.
- OpenClaw normal gateway status plus dev/loopback lab commands for debugging.
- Hermes cron registry, latest outputs, routes, failures, and no-agent watchdog jobs.
- Session store and session-search/export workflows.
- Obsidian vault navigation and project notes.
- 1Password/SSH/Tailscale readiness, without exposing secrets.
- Gateway errors, stale provider/quota errors, Discord 429/503 cooldown state, and launchd ownership.
- CLI instructions for everything the application can do without requiring a web UI.

Best surface:

```text
Native cmux workspace 1: Hermes Ops
├── cmux ssh MBP/remote
│   └── tmux attach -t mission-hermes
└── browser surface: Obsidian vault / Hermes static page

Native cmux workspace 2: OpenClaw Ops
├── cmux ssh MBP/remote
│   └── tmux attach -t mission-openclaw
└── browser surface: Obsidian project notes / OpenClaw page or gateway UI
```

Keep these as separate workspaces. Do not merge them into the coding workbench. Mission cockpits should be boring, stable, and runtime-focused. OpenClaw should support the normal gateway path (`openclaw gateway status/run/start/install`) when Dan wants to use OpenClaw; dev/loopback mode remains the debugging lab, not the only operating model.

Recommended windows/cards inside each tmux mission cockpit:

```text
0 chat/overview    active assistant chat + compact health map
1 gateway          launchd/systemd status, gateway log, gateway errors
2 cron             job registry, latest output, route/model info, mutation labels
3 sessions         sessions list, export commands, stale session cleanup guidance
4 obsidian         vault map, project links, note commands
5 tools            toolsets, MCP, providers, browser/discord readiness
6 logs             structured logs, error filters, recent failures
7 network          Tailscale, SSH, ports, remote reachability
8 security         1Password/SSH readiness only, no raw secrets
9 scratch          safe shell runway
```

Design rule: this plane may show commands that mutate runtime, but should not run production gateway start/stop/restart automatically. launchd/systemd owns services.

### Plane 2: Coding workbench / application cockpit

Purpose: answer "Can I edit, test, inspect, discuss, and ship this project safely?"

This plane owns:

- Neovim/Kickstart editing.
- Repo status, diffs, tests, lint, build, and port registry.
- Browser panes for local app previews and runtime smoke tests.
- GitHub auth, branch, PR checks, review comments, and issue/PR discussion drafts.
- Obsidian project notes and sanitized repo docs side by side.
- Discord/community discussion draft/preview/send workflow.
- Application CLI capability map: exact commands to do what a JS mission-control app would otherwise expose as buttons.
- Session logging for coding agents and command outcomes.

Best surface:

```text
Native cmux workspace 3: Code Workbench / Project Card
├── terminal pane: tmux attach -t cockpit-workbench
├── terminal pane: Neovim + CLI coding agents
├── browser pane: JS/React/Next local app preview routed through remote network
├── browser pane: GitHub PR/status/community thread when active
└── scratch/action pane: tests, builds, ports, smoke checks
```

Current tmux-backed repo helper already approximates this:

```text
0 hub       project/session rail + overview + scratch
1 editor    Neovim + guide + scratch
2 project   cwd router, ports, docs, commands
3 browser   app preview and smoke-test commands
4 agents    coding CLIs and orchestration readiness
5 hermes    Hermes/OpenClaw bridge commands
6 github    gh/PR/discussion workflow
7 obsidian  vault/project notes
8 discord   dry-run Discord/community posting workflow
9 scratch   free shell grid
```

Design rule: the workbench is allowed to be dynamic and project-aware. It should use the cwd/context router (`cctx`) to repaint metadata, recommended commands, browser URL, Obsidian target note, and agent slots. It should not casually mutate gateways.

### Plane 3: Agent orchestration / social-community layer

Purpose: answer "Which agents are working, which need input, what did they cost, what should be escalated to humans/community, and what is the next orchestration action?"

This plane owns:

- agent-deck TUI and optional web UI.
- agent-deck conductor sessions.
- Worktree-backed parallel sessions.
- Fork/resume workflows.
- MCP and skills/session grouping.
- Status detection: running, waiting, failed, done.
- Cost dashboard and session output search.
- Hermes Kanban / durable board visibility.
- Discord components, buttons, select menus, and modals for interactive community/project workflows.
- Open-source project chatter: GitHub discussions, Discord threads, PR status, maintainer feedback.

Best surface:

```text
Native cmux workspace 4: Agent Deck
├── terminal pane: agent-deck on its own tmux socket/server
├── terminal pane: worktree conductor / Hermes Kanban/status summary
├── browser pane: GitHub PR/discussion/community page
├── browser pane or CLI pane: Discord bot/component preview/dev logs
└── scratch pane: operator escalation/action shell
```

Design rule: do not reimplement agent-deck. Wrap it. The cockpit should surface agent-deck status and launch commands, while agent-deck owns its own tmux socket/server and session lifecycle. Use git worktrees as the safety primitive: one agent, one branch, one worktree; the operator reviews diffs before merge. Open-source tracking, GitHub discussions, and Discord workflows usually belong here, unless the active work is a single repo implementation loop better handled in Code Workbench.

## Recommended top-level cmux architecture

Use one local native cmux window on the iMac with four focused vertical workspaces. Each workspace reaches the MBP through SSH/Tailscale and uses tmux or agent-deck for process persistence:

```text
Local iMac cmux window: AI Cockpit
├── Workspace 1: Hermes Ops      -> cmux ssh MBP -> tmux mission-hermes + Obsidian browser surface
├── Workspace 2: OpenClaw Ops    -> cmux ssh MBP -> tmux mission-openclaw + OpenClaw/vault browser surface
├── Workspace 3: Code Workbench  -> cmux ssh MBP -> tmux cockpit-workbench + JS/React/Next browser testing
└── Workspace 4: Agent Deck      -> cmux ssh MBP -> agent-deck/worktrees + GitHub/Discord/community surfaces
```

Browser Lab and Community Lab are not separate default workspaces anymore. They are built into Code Workbench and Agent Deck, because that keeps the sidebar smaller and matches the actual operator flow: browser testing belongs beside code, and open-source/community tracking belongs beside agent orchestration.

This preserves different failure domains:

- Ops can stay running while workbench layouts are rebuilt.
- Coding experiments cannot accidentally kill gateway panes.
- agent-deck can crash/restart without taking mission cockpits with it.
- Browser/community surfaces can be closed without affecting live agent/runtime sessions.

## Alternative architectures

### Option A: One mega-workspace

One cmux workspace contains ops, coding, browser, GitHub, Discord, and agent-deck panes.

Verdict: bad default. It looks impressive but becomes cockpit soup. Use only for demos or a focused single-project incident room.

### Option B: Three separate cmux windows

One macOS window each for Ops, Coding, and Agent Deck.

Verdict: useful on a large monitor. Worse on laptop screens because macOS window management becomes the new tax.

### Option C: One cmux window, many vertical workspaces

Verdict: recommended. It matches cmux strengths: sidebar cards, notifications, PR/port metadata, browser panes, and keyboard workspace switching.

### Option D: Native cmux only, no tmux

Verdict: not yet. cmux restores layout/metadata, not all live process state. Persistent agents, gateways, Neovim sessions, and logs still need tmux plus launchd/systemd.

## Workflow recommendation

### Normal daily loop

```text
1. Start in Hermes Ops.
   Check gateway, cron, session state, and recent errors.

2. Jump to Code Workbench.
   Pick project/context with cctx, edit in Neovim, run tests/builds.

3. Use the Code Workbench browser surface.
   Verify app runtime in cmux browser, capture screenshot/snapshot, inspect console/errors.

4. Jump to Agent Deck.
   Start/fork/resume agent-deck sessions or Hermes/OpenClaw agents. Keep one agent per worktree.

5. Review GitHub/community surfaces from Agent Deck.
   Inspect PR status, discussions, Discord/community feedback. Draft first, send only after review.

6. Return to Hermes Ops.
   Check whether background cron/gateway/errors changed after the work.
```

### Keyboard/operator target

The cockpit should teach and reinforce:

```text
cmux:       Command-number workspaces, pane splits, browser focus, notification panel
remote tmux: Ctrl-b w, Ctrl-b n/p, Ctrl-b 0-9, Ctrl-b z, Ctrl-b d, Ctrl-b h/j/k/l
Neovim:     i, Esc, :w, :q, /search, n/N, :e, :Ex, Ctrl-w h/j/k/l, :checktime
CLI habit:  inspect -> dry-run -> execute -> verify -> log
```

## What the CLI mission-control layer must expose

The cockpit should eventually provide command pages or helpers for these application capabilities:

```text
assistant runtime
- start/attach/resume Hermes CLI sessions
- inspect active gateway owner
- tail gateway logs and error logs
- check toolsets and MCP servers
- inspect provider/model route state
- export/search session logs

cron and automation
- list jobs
- show latest output
- run/pause/resume/remove jobs
- classify mutating vs read-only/no-agent jobs
- open cron output/log paths

vault and project memory
- open canonical Obsidian vault
- jump to project dashboard, research, next steps, architecture
- link repo docs to vault research notes
- keep public/private boundary visible

coding
- open Neovim in project
- run tests/build/lint
- show git branch/diff/status
- start dev server
- detect/list ports
- run browser smoke test

github/community
- show gh auth/repo/PR status
- open PR/check URLs in cmux browser
- prepare GitHub discussion/issue/PR comments
- preview Discord posts/components
- require explicit send/post flag for external actions

orchestration
- open agent-deck
- show agent-deck sessions/groups/status/cost
- show Hermes Kanban/status
- create one-agent-one-worktree sessions
- fork/resume sessions
- summarize waiting/failed/done agents
```

## Discord/community design

Discord's current platform docs support message components and modals: buttons, select menus, text inputs, and form-like modal overlays.

Design implication: Discord should not just be a log sink. It can become a lightweight remote control surface for approved cockpit actions:

- Button: rerun smoke test.
- Select menu: choose project/workspace.
- Modal: submit bug report or task brief.
- Button: request agent status summary.
- Button: approve a prepared GitHub/Discord post after preview.

Safety boundary: the CLI cockpit remains canonical. Discord components are remote-control affordances, not the only source of truth. External posting and mutating actions stay explicit and auditable.

## Native cmux adapter target

After the repo helper is renamed away from `cmux`, build a native adapter that maps cockpit concepts to real cmux primitives:

```text
cockpit plane       -> cmux workspace
project/session card -> workspace title/sidebar metadata
scratch shell       -> new pane or surface
app preview         -> browser pane
PR/community page   -> browser pane
agent notification  -> cmux notify
agent status board  -> terminal pane running agent-deck or status helper
context update      -> cmux CLI/socket API using captured JSON IDs
```

Implementation rules:

- Use official `/usr/local/bin/cmux` only after renaming this repo's helper.
- Capture workspace/surface IDs from `cmux --json` output. Never hard-code surface IDs.
- Store transient native adapter state under `.cmux/state/` or `~/.cache/hermes-cli-cockpit/`.
- Keep cmux socket mode at default/process-only unless a specific automation need requires otherwise.
- Use `cmux notify` first and OSC 777 fallback second.
- Treat browser IDs as ephemeral and discover them dynamically before every smoke test.

## Recommendation summary

The optimal workflow is one local iMac cmux window with four specialized workspaces:

```text
Hermes Ops       = stable Hermes runtime, cron, sessions, vault/browser context
OpenClaw Ops     = normal OpenClaw gateway-capable cockpit, with dev/lab fallback
Code Workbench   = Neovim + CLI agents + JS/React/Next browser testing + GitHub/Obsidian
Agent Deck       = agent-deck + git worktrees + open-source/GitHub/Discord tracking
```

Use native cmux for local visual organization, browser panes, notifications, SSH workspaces, and automation. Use remote tmux for persistence. Use launchd/systemd for gateways. Use agent-deck for multi-agent orchestration. Use Obsidian for durable private context. Use the repo for sanitized, reproducible CLI tooling.

That separation is the product: a CLI mission control system with enough GUI affordance from cmux to make many agents and many contexts legible without turning the terminal into soup.
