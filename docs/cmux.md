# CMUX Agent Workbench

`cmux` is the coding workbench layer that sits beside the operational mission cockpits.

```text
mission-hermes      Hermes operations/control plane
mission-openclaw    OpenClaw dev/sandbox operations/control plane
cmux                repo editing, review, test, browser, GitHub, Discord, Obsidian plane
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

Local install target:

```text
~/.local/bin/cmux -> ~/Code/hermes-cli-cockpit/bin/cmux
```

## Windows

```text
0 ops       links to mission-hermes / mission-openclaw and live tmux topology
1 editor    Neovim in the repo using CMUX_NVIM_APPNAME, default nvim
2 diff      git status, diff, last commit, review commands
3 browser   local browser/test URLs and smoke-test commands
4 agents    Codex, Claude, OpenCode, agent-deck readiness and launch hints
5 github    gh auth/repo/PR status and architecture discussion drafts
6 obsidian  vault/project notes and quick open commands
7 discord   Discord API readiness and discussion payload workflow
8 scratch   shells for build/test/recovery
```

Every window has a bottom shortcut pane with the local navigation map.

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

## Diff and review loop

Use the `diff` page before every commit:

```bash
git status --short --branch
git diff --check
git diff
git diff --cached
git add <paths>
git commit -m "feat(scope): short summary" -m "Longer why/comments."
git push
```

If diff tools are installed, the pane points to them. Missing tools should degrade to instructions, not break cmux.

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

## Agent orchestration

CMUX detects these tools when present:

```text
codex
claude
opencode
agent-deck
```

Safety model:

1. Inspect diff before delegating.
2. Prefer one agent per git worktree for parallel edits.
3. Never let two agents patch the same files blindly.
4. Run tests before commit.
5. Do not paste secrets into agent prompts or visible tmux panes.

## GitHub architecture discussion

The `github` page shows auth/repo/PR state via `gh` when authenticated and includes a starter discussion draft:

```text
Title: CMUX workbench architecture: ops plane vs coding plane

- mission-hermes / mission-openclaw remain operational control surfaces.
- cmux is the code/review/test/discussion workbench.
- Neovim owns active editing; agents patch via git-visible diffs.
- Browser, GitHub, Obsidian, and Discord panes make feedback loops visible.
- Missing tools degrade to instructions rather than breaking the layout.
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
