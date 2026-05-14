# CMUX Agent Workbench

`cmux` is the coding workbench layer that sits beside the operational mission cockpits.

```text
mission-hermes      Hermes operations/control plane
mission-openclaw    OpenClaw dev/sandbox operations/control plane
cmux                repo editing, review, test, browser, GitHub, Discord, Obsidian plane
```

The deeper design note lives at:

```text
docs/cmux-flexible-workspace.md
```

## Why separate cmux from mission-hermes?

Mission cockpits answer: is the agent runtime healthy?

CMUX answers: can we safely edit, review, test, discuss, and ship a project?

That split prevents cockpit soup. Gateway/cron/log health stays in `mission-*`; code, diffs, browser smoke tests, PRs, notes, and external discussions stay in `cmux`.

## Command

```bash
bin/cmux --no-attach
bin/cmux
bin/cmux --reset
```

Two-session companion mode:

```bash
bin/cmux --two-sessions --reset
```

Project-specific launch:

```bash
bin/cmux --project=/path/to/repo --reset
bin/cctx /path/to/repo
```

Local install target:

```text
~/.local/bin/cmux -> ~/Code/hermes-cli-cockpit/bin/cmux
```

## Workspace model

Inspired by native cmux and the reference screenshot:

```text
left rail       project/session cards
center          active surface: editor, agent, browser, PR, vault, API
right/bottom    contextual scratch terminals near command lists
ops bridge      Hermes/OpenClaw mission sessions remain reachable
```

The current implementation is tmux-backed, but the nouns intentionally match the future native cmux adapter target.

## Windows

```text
0 hub       left rail + workspace overview + scratch terminal
1 editor    Neovim center surface using CMUX_NVIM_APPNAME, default nvim
2 project   cwd/project router, ports, docs, and directory-aware commands
3 browser   browser/test URLs and smoke-test commands
4 agents    Codex, Claude, OpenCode, Hermes, OpenClaw, agent-deck readiness
5 hermes    Hermes/OpenClaw session bridge and spawn/resume commands
6 github    gh auth/repo/PR status and architecture discussion drafts
7 obsidian  vault/project notes and quick open commands
8 discord   Discord API readiness and discussion payload workflow
9 scratch   free terminals for build/test/recovery
```

Most command-heavy pages include a right scratch terminal. The hub includes a left rail and a bottom scratch terminal. The scratch window provides a free terminal grid.

## One-session vs two-session

### One-session model

```bash
cmux --reset
```

Use this when one operator wants coding agent + Hermes bridge inside one workbench.

### Two-session model

```bash
cmux --two-sessions --reset
```

Use this when the coding workbench and Hermes bridge should persist separately.

```text
cmux              coding workbench
cmux-hermes       companion Hermes/OpenClaw bridge
```

## Neovim and Kickstart

This MBP currently uses a Kickstart-style Neovim config at:

```text
~/.config/nvim/init.lua
```

`cmux` starts Neovim with:

```bash
NVIM_APPNAME=${CMUX_NVIM_APPNAME:-nvim} nvim .
```

To try a separate Kickstart sandbox later:

```bash
git clone https://github.com/nvim-lua/kickstart.nvim ~/.config/nvim-kickstart
CMUX_NVIM_APPNAME=nvim-kickstart cmux --reset
```

Required agent-edit safety:

```lua
vim.o.autoread = true
vim.api.nvim_create_autocmd({ 'BufEnter', 'CursorHold', 'CursorHoldI', 'FocusGained' }, {
  command = "if mode() != 'c' | checktime | endif",
  pattern = { '*' },
})
```

This lets Neovim notice files changed by Hermes/OpenClaw/Codex/Claude/OpenCode.

## Project/CWD router

The `project` page is the manual cockpit view for the context router.

Current behavior separates the active project from the cockpit helper repo:

```bash
cd "$CMUX_REPO_DIR"                         # active project/repo
pwd
git status --short --branch
nvim .

# cockpit helpers remain anchored to the cockpit repo, not arbitrary --project roots
"${CMUX_COCKPIT_BIN_DIR:-/Users/openclaw/Code/hermes-cli-cockpit/bin}/ports" \
  --registry "${CMUX_COCKPIT_ROOT:-/Users/openclaw/Code/hermes-cli-cockpit}/config/ports.toml"
```

Current helper:

```bash
cctx
cctx /Users/openclaw/Code/hermes-cli-cockpit
cctx ~/.hermes/workspace/projects/hermes-cli-cockpit
```

Optional zsh hook for directory-aware context updates:

```bash
source /Users/openclaw/Code/hermes-cli-cockpit/bin/cctx-hook.zsh
cctx-on       # every cd refreshes ~/.cache/hermes-cli-cockpit/cctx.env
cctx-off      # disable the hook in this shell
cctx-refresh  # manually refresh the current cwd
```

The hook is intentionally opt-in. The repo does not edit `~/.zshrc` automatically.

Future target:

```text
You stay in the terminal.
Changing directories changes the workspace context around you.
```

`cctx` is the first safe version of this: it resolves cwd, detects context kind, writes `~/.cache/hermes-cli-cockpit/cctx.env`, and prints exact `cmux` commands. `cmux` and its status panes now reread that state file, so changing context can repaint project cards, browser URLs, Obsidian targets, and recommended commands without killing live panes.

Safety note: `cmux` parses only whitelisted keys from the `cctx.env` state file. It does not execute/source the file internally. Escape hatches:

```bash
CMUX_USE_CCTX_STATE=0 cmux --reset   # ignore saved cctx state on launch
CMUX_DYNAMIC_CONTEXT=0               # keep existing panes from repainting from cctx.env
```

Scratch shells are deliberately not teleported when context changes. They remain command runways beside instructions so a running process, editor, or half-typed command is not destroyed.

Guide panes can be removed once keyboard muscle memory improves:

```bash
CMUX_GUIDE_MODE=off cmux --reset
```

## Browser testing

Default target:

```bash
CMUX_BROWSER_URL=http://127.0.0.1:4173/
```

Useful commands:

```bash
open "$CMUX_BROWSER_URL"
curl -I "$CMUX_BROWSER_URL"
python3 -m http.server 4175 --directory web
CMUX_BROWSER_URL=http://127.0.0.1:4175/hermes/ cmux --reset
```

Rule: build/test passing is not the same as browser runtime verified.

Native cmux future target:

```bash
cmux browser open-split "$CMUX_BROWSER_URL"
cmux browser screenshot --out /tmp/cmux-frontend.png
```

## Agent orchestration

CMUX detects these tools when present:

```text
codex
claude
opencode
hermes
openclaw
agent-deck
```

Agent-deck ideas adopted into the design:

- visible board for many AI sessions
- groups per project/session
- worktree-backed parallel agents
- fork/resume workflows
- MCP/skills/cost/status dashboards
- status detection: running, waiting, failed, done

Safety model:

1. Inspect diff before delegating.
2. Prefer one agent per git worktree for parallel edits.
3. Never let two agents patch the same files blindly.
4. Run tests before commit.
5. Do not paste secrets into agent prompts or visible tmux panes.

## GitHub architecture discussion

The `github` page shows auth/repo/PR state via `gh` when authenticated and includes a starter discussion draft:

```text
Title: CMUX flexible workspace foundation: project cards, agent surfaces, and Hermes/OpenClaw bridge

- The left rail should model project/session cards.
- Center surfaces should change by context: editor, agent, browser, PR, vault, API.
- Scratch terminals belong beside command lists.
- mission-hermes / mission-openclaw remain operational control surfaces.
- cmux is the code/review/test/discussion workbench.
- Browser, GitHub, Obsidian, and Discord panes make feedback loops visible.
- Agent orchestration uses worktrees, diff gates, and explicit handoffs.
```

## Obsidian vault

CMUX defaults to Dan's canonical vault:

```text
~/.hermes/workspace
```

The `obsidian` page links the repo to:

```text
projects/hermes-cli-cockpit
agent-hermes/notes/next-steps.md
agent-hermes/notes/open-items.md
resources/docs
resources/links
```

Private material stays in Obsidian. Public repo docs must stay sanitized.

## Discord API discussions

The Discord pane is dry-run-first. The helper script will not post unless `--send` is supplied.

Dry run:

```bash
scripts/post-discord-discussion.py --channel-id "$DISCORD_CHANNEL_ID" --file docs/cmux.md
```

Send only after explicitly choosing the destination and reviewing the preview:

```bash
scripts/post-discord-discussion.py --channel-id "$DISCORD_CHANNEL_ID" --file docs/cmux.md --send
```

The token is read from `DISCORD_BOT_TOKEN`; do not paste tokens into visible panes or shell history.
