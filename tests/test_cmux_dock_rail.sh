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
required = {
    'danos.home', 'hermes.ops', 'openclaw.ops', 'herdr.ops', 'code.workbench',
    'code.browser', 'agent.deck', 'oss.radar', 'github.review', 'obsidian.notes',
    'discord.workflow', 'vault.root',
}
missing = required.difference(cfg['actions'])
assert not missing, f'missing actions: {sorted(missing)}'
for action_id in required:
    assert 'bin/cmux-cockpit-page' in cfg['actions'][action_id]['command'], action_id
assert 'herdr.ops' in cfg['ui']['surfaceTabBar']['buttons']
assert all('bin/cmux-cockpit-page' in command['command'] for command in cfg['commands'])
PY

printf '== invalid rail page ==\n'
if "$ROOT/bin/cmux-dock-rail" nope >/dev/null 2>&1; then
  printf 'Expected invalid rail page to fail\n' >&2
  exit 1
fi

printf 'test_cmux_dock_rail.sh: OK\n'
