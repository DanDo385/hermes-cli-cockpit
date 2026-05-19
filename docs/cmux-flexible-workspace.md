# CMUX Flexible Workspace Foundation

> For Hermes: this document captures the deeper workspace design inspired by native cmux, Kickstart Neovim, agent-deck, and the terminal workspace screenshot Dan provided.

## Objective

Build a terminal-native workspace that can start from either:

1. a project, or
2. a Hermes/OpenClaw conversation/session,

then reshape the visible panes around that context: editor, coding agent, Hermes bridge, browser testing, Discord API, Obsidian vault, GitHub/PR review, and scratch terminals.

This is not just a tmux layout. It is a workspace model.

## Screenshot analysis

The reference image shows a native cmux-style terminal workspace with these primitives:

```text
left rail       selected workspace/project/session card
center top      tabs/surfaces within that selected workspace
center body     live AI coding agent terminal
input row       direct prompt/command loop
large blank     output runway for long-running agent work
right/top icons workspace utilities and notifications
```

Important design insight:

The left column is not decoration. It is the outer selector. Once a project/session is selected, the center can expose different tabs/surfaces for agents, files, browser state, logs, or commands.

That means our foundation should not be "one tmux window per chore" forever. It should be:

```text
workspace card -> context router -> center surface(s) -> nearby scratch/action panes
```

## Research takeaways

### Native cmux

Docs: https://cmux.com/docs/getting-started

Native cmux is a macOS terminal built on Ghostty for managing AI coding agents. It provides:

- vertical tab sidebar
- notification panel
- socket-based control API
- restored layout/metadata/cwd/browser URL/history
- no guaranteed live process restore after app restart

Implication for this repo:

- scripts must be idempotent and rebuildable
- cwd and metadata matter
- long-running agents should have resume commands
- notifications and browser panes should become first-class once native cmux is available

### Kickstart Neovim

Repo: https://github.com/nvim-lua/kickstart.nvim

Kickstart is not a distribution. It is a readable launch point for a personal Neovim config.

Implication:

- Neovim should be the center editing surface, not the whole cockpit
- tmux/cmux should orchestrate context around Neovim
- agent-edit safety requires `autoread` and `checktime`
- LSP, fuzzy finding, Git UI, diagnostics, test output, and quickfix should stay inside Neovim where possible

### agent-deck

Repo: https://github.com/asheshgoplani/agent-deck

agent-deck is a TUI command center for many AI coding agents using tmux. Useful concepts:

- all agents visible in one board
- grouped sessions per project/profile
- worktree-backed parallel agents
- fork/resume sessions
- MCP and skills management
- status detection: running, waiting, failed, done
- cost/dashboard/remote/sandbox concepts

Implication:

cmux should not try to hide agent multiplicity. It should expose it safely with visible slots, one-agent-one-worktree rules, and explicit handoff/review gates.

## Implemented tmux-backed deck

The current `bin/cmux` implementation is still tmux-backed, but now uses the same nouns as the native target.

```text
0 hub       left rail + workspace overview + scratch
1 editor    Neovim center surface + command runway + full-height learning rail
2 project   cwd/project router + scratch
3 browser   frontend/browser test surface + scratch
4 agents    live Agent Deck inventory + command card + empty worktree agent slots
5 hermes    Hermes/OpenClaw bridge + scratch
6 github    PR/discussion workflow + scratch
7 obsidian  vault notes + scratch
8 discord   Discord API/dry-run workflow + scratch
9 scratch   free terminal grid
```

Run:

```bash
cmux --reset
```

Verify without attaching:

```bash
cmux --no-attach
```

Two-session companion mode:

```bash
cmux --two-sessions --reset
```

This creates:

```text
cmux              coding workbench
cmux-hermes       companion Hermes bridge session
```

If a custom session name is used, the companion is `<session>-hermes`.

## Directory-aware context routing

`bin/cctx` is the workspace context router. It resolves the current path, classifies it, writes a small state file, and prints exact launch commands.

```bash
cctx
cctx /Users/openclaw/Code/hermes-cli-cockpit
cctx /Users/openclaw/Code/openclaw
cctx ~/.hermes/workspace/projects/hermes-cli-cockpit
```

State file:

```text
~/.cache/hermes-cli-cockpit/cctx.env
```

Tracked state:

```text
CMUX_CONTEXT_PATH
CMUX_CONTEXT_KIND
CMUX_CONTEXT_NAME
CMUX_REPO_DIR
CMUX_BROWSER_URL
CMUX_MISSION_HINT
OBSIDIAN_VAULT_PATH
```

`bin/cmux` parses that state on launch by default. `bin/cmux-pane` rereads it on each status-pane refresh. This means the cockpit can repaint around a new context without destroying live shells.

Security boundary: `cmux` parses only a whitelist of expected keys from the state file. It does not execute/source the state file internally. Use `CMUX_USE_CCTX_STATE=0` to ignore saved state on launch, or `CMUX_DYNAMIC_CONTEXT=0` to stop live status panes from repainting from the state file.

Optional zsh hook:

```bash
source /Users/openclaw/Code/hermes-cli-cockpit/bin/cctx-hook.zsh
cctx-on
```

After that, every `cd` in that shell refreshes the context card. Use `cctx-off` to disable it.

Safety boundary:

- status/guide panes can repaint automatically
- scratch shells remain stable and disposable
- no session rebuild happens unless the operator runs `cmux --reset`
- no gateway or production process is started/stopped by `cctx`

Guide-mode control:

```bash
CMUX_GUIDE_MODE=off cmux --reset
```

Use that after the tmux/navigation scaffolding becomes annoying instead of helpful.

## One-session vs two-session design

### A. One session: coding agent + Hermes bridge

Use when one operator is steering everything.

```bash
cmux --reset
```

Recommended workflow:

```text
window 1 editor   edit/review in Neovim
window 4 agents   coding CLIs and orchestration
window 5 hermes   Hermes/OpenClaw bridge
window 3 browser  frontend runtime checks
window 6 github   PR/discussion
window 7 obsidian notes
window 8 discord  dry-run/send after approval
```

### B. Two sessions: coding workbench + Hermes companion

Use when Hermes should persist separately from a coding-agent experiment.

```bash
cmux --two-sessions --reset
```

Recommended workflow:

```text
cmux          code, editor, diff, browser, PRs
cmux-hermes   Hermes/OpenClaw bridge, session resume, mission links
```

## Scratch terminal rule

Dan explicitly wanted scratch terminals where command lists appear.

Implemented pattern:

- hub has a bottom scratch terminal
- editor has a command runway below Neovim and a full-height learning rail on the right
- command-heavy pages have a right scratch terminal
- scratch page has a free terminal grid

Purpose:

```text
instructions nearby -> copy/edit/run immediately -> no context switching tax
```

## Browser testing as a first-class loop

The browser page treats UI validation as separate from tests/builds.

Examples:

```bash
python3 -m http.server 4175 --directory web
open "$CMUX_BROWSER_URL"
curl -I "$CMUX_BROWSER_URL"
```

Native cmux future target:

```bash
cmux browser open-split "$CMUX_BROWSER_URL"
cmux browser screenshot --out /tmp/cmux-frontend.png
```

Acceptance principle:

Build/test passing is not browser runtime verified.

## Discord and Obsidian integration

Discord:

- dry-run-first helper lives at `scripts/post-discord-discussion.py`
- token comes from `DISCORD_BOT_TOKEN`
- channel comes from `DISCORD_CHANNEL_ID`
- no posting without explicit `--send`

Obsidian:

- canonical vault defaults to `~/.hermes/workspace`
- project notes stay private unless sanitized
- repo docs stay public-safe

## Current: cwd-aware context router seed

The next design jump is a shell-aware context router. The first safe seed is now `bin/cctx`.

Concept:

```bash
cctx ~/Code/hermes-cli-cockpit
cctx ~/.hermes/workspace/projects/hermes-cli-cockpit
cctx ~/.hermes/hermes-agent
```

What `cctx` does today:

- resolves the target path
- classifies the context, for example `git-project`, `obsidian-vault`, `hermes-agent-source`, or `openclaw`
- writes `~/.cache/hermes-cli-cockpit/cctx.env`
- updates tmux environment when called inside tmux
- prints exact `cmux --project=...` and mission attach commands
- does not rebuild sessions, kill panes, post Discord messages, or mutate gateways

Each directory can eventually refresh:

- left rail project card
- recommended commands
- browser URL
- Obsidian note
- active agent slots
- worktree list
- Hermes/OpenClaw session target

The big idea:

```text
You stay in the terminal.
Changing directories changes the workspace context around you.
```

That is the real flexible foundation.

## Native cmux adapter target

When the native cmux app/CLI is installed and we decide to target it directly, the tmux functions should map to native primitives:

```text
tmux window       -> cmux workspace/card or surface group
tmux pane         -> cmux pane/surface
tmux pane title   -> cmux tab/surface title
tmux scratch      -> cmux new tab/split in current pane
tmux right pane   -> cmux Dock/control/sidebar
open browser      -> cmux browser surface
terminal alerts   -> cmux notify
```

Do not hard-code surface IDs long-term. Native cmux automation should capture workspace/surface IDs from CLI JSON and store transient state under `.cmux/state/`.

## Safety model

- no raw secrets in repo docs or panes
- Discord posts are dry-run-first
- one agent, one branch, one worktree for parallel edits
- Git diff/review gates before commits
- OpenClaw Ops prefers normal gateway status/run/start/install; dev/loopback is the lab fallback
- mission-hermes / mission-openclaw remain operational control planes

## Missing input

The photo has been analyzed. No video URL or attachment was available in the current prompt. When provided, the video should be analyzed for additional interaction patterns and folded into this design.
