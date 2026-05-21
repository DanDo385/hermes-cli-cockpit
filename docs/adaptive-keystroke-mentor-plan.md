# Adaptive Keystroke Mentor Plan

> Coding Workbench (workspace 3) training wheels: Neovim keybinding rail, command runway, and pane-title posture that teaches without blocking flow.

Checked: 2026-05-21

## Scope

This plan applies to **Coding Workbench only**. Hermes and OpenClaw mission controls (workspaces 1–2) use tmux navigation drills; Agent Deck (4) uses worktree/review gates; OSS Radar (5) uses draft-first posting rules.

## Five cockpit surfaces (preserved)

```text
1 Hermes Tool / Hermes CLI Mission Control   mission-hermes
2 OpenClaw Tool / OpenClaw CLI Mission Control mission-openclaw
3 Coding Workbench                           cockpit-workbench
4 Agent Orchestration / Agent Deck           cockpit-workbench:agents
5 Open Source Radar / Community              cockpit-community
```

Hermes and OpenClaw are **peer** surfaces — never collapsed into one generic agent pane.

## Pane-title posture (Coding Workbench)

| Window   | Pane title                         | Mentor focus                          |
|----------|------------------------------------|---------------------------------------|
| editor   | Neovim \| i insert, Esc normal, :w save | Mode transitions, save habit       |
| editor rail | Nvim Keys \| / search, gd def, K docs | Navigation without mouse          |
| runway   | Runway \| git diff, test, build    | CLI loop beside editor                |
| review   | Review \| diff, test, then accept   | Gate before accepting agent edits     |
| git/project | Git \| status, diff, PRs         | Branch awareness                      |

## Adaptive mentor behavior

1. **Context-aware rail** — `CMUX_GUIDE_MODE=full` shows the Neovim learning rail; set `CMUX_GUIDE_MODE=off` when muscle memory is sufficient.
2. **Command runway** — scratch panes list copy/edit/run commands for the active page; main pane stays readable.
3. **Progressive disclosure** — hub/rail documents five workspaces; missions window (8) only attaches pointers to mission controls — no merged chat.
4. **Keystroke drills** — guide panes include a three-step drill: picker → scratch → zoom → detach.

## Implementation hooks

```text
bin/cmux              CMUX_GUIDE_MODE, CMUX_NVIM_APPNAME, editor-guide pane
bin/cmux-pane         show_editor_guide, show_runway, show_review
config/cockpit-workspaces.toml   workspace 3 surfaces + pane_titles
docs/navigation.md    tmux prefix model shared across workspaces
```

## Boundary rules

- Assistant **conversation** → `mission-hermes` or `mission-openclaw`.
- **OSS/community** → `cockpit-community`.
- **Coding + review** → `cockpit-workbench` windows editor/runway/review.
- OpenClaw missing features → `unsupported/not configured` in OpenClaw mission panes, not deleted.

## Verification

```bash
bin/cockpit-workspaces list
bin/cockpit-workspaces show code
bin/cockpit-workspaces show hermes
bin/cockpit-workspaces show openclaw
bin/cockpit-workspaces show oss-radar
python3 -m json.tool .cmux/cmux.json >/dev/null
git diff --check -- docs/adaptive-keystroke-mentor-plan.md
```

## Related docs

- `config/cockpit-workspaces.toml` — registry source of truth
- `docs/cmux-ai-assistant-workspace-design.md` — north-star design
- `docs/imac-native-cmux-workspaces.md` — iMac bootstrap
