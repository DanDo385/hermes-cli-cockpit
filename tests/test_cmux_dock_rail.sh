#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

assert_contains() {
  local haystack="$1" needle="$2"
  if ! grep -Fq "$needle" <<<"$haystack"; then
    printf 'Expected output to contain: %s\nActual output:\n%s\n' "$needle" "$haystack" >&2
    exit 1
  fi
}

printf '== dock configuration json ==\n'
python3 -m json.tool "$ROOT/.cmux/dock.json" >/dev/null

printf '== dock rail contexts ==\n'
for page in home hermes openclaw code agents review browser community notes; do
  out="$($ROOT/bin/cmux-dock-rail "$page")"
  assert_contains "$out" 'CMUX COMMAND DOCK'
  assert_contains "$out" 'GLOBAL CMUX'
done

printf '== page wrapper dry run ==\n'
out="$(CMUX_COCKPIT_PAGE_DRY_RUN=1 "$ROOT/bin/cmux-cockpit-page" hermes -- ssh -t mbp-runtime 'echo hello')"
assert_contains "$out" 'page=hermes'
assert_contains "$out" 'right-sidebar set dock --no-focus'
assert_contains "$out" 'ssh -t mbp-runtime'

printf '== cmux action wiring ==\n'
python3 - "$ROOT/.cmux/cmux.json" <<'PY'
import json, sys
with open(sys.argv[1]) as fh:
    cfg = json.load(fh)
workspace_pages = {
    'hermes.ops': ('Hermes Ops', 'mission-hermes'),
    'openclaw.ops': ('OpenClaw Ops', 'mission-openclaw'),
    'code.workbench': ('Code Workbench', 'cockpit-workbench'),
    'agent.deck': ('Agent Deck', 'cockpit-workbench:agents'),
    'oss.radar': ('Community / Review', 'cockpit-community'),
}
for action_id, (workspace_name, tmux_target) in workspace_pages.items():
    action = cfg['actions'][action_id]
    assert action['type'] == 'workspace', action_id
    assert action['restart'] == 'ignore', action_id
    assert action['newWorkspaceMenu'] is True, action_id
    workspace = action['workspace']
    assert workspace['name'] == workspace_name, action_id
    command = workspace['layout']['pane']['surfaces'][0]['command']
    assert 'bin/cmux-cockpit-page' in command, action_id
    assert f'tmux attach -t {tmux_target.split(":")[0]}' in command, action_id

# Browser remains a normal in-pane action until Dan explicitly redesigns Browser Lab.
assert cfg['actions']['code.browser']['type'] == 'command'
assert cfg['actions']['code.browser']['target'] == 'newTabInCurrentPane'

for action_id in {'danos.home', 'herdr.ops', 'code.browser', 'github.review', 'obsidian.notes', 'discord.workflow', 'vault.root'}:
    assert 'bin/cmux-cockpit-page' in cfg['actions'][action_id]['command'], action_id

legacy_names = {command['name'] for command in cfg['commands']}
assert not legacy_names.intersection({
    'Hermes Tool / Hermes CLI Mission Control',
    'OpenClaw Tool / OpenClaw CLI Mission Control',
    'Coding Workbench',
    'Agent Deck',
    'Open Source Radar / Community',
})
assert 'herdr.ops' in cfg['ui']['surfaceTabBar']['buttons']
PY

printf '== invalid rail page ==\n'
if "$ROOT/bin/cmux-dock-rail" nope >/dev/null 2>&1; then
  printf 'Expected invalid rail page to fail\n' >&2
  exit 1
fi

printf 'test_cmux_dock_rail.sh: OK\n'
