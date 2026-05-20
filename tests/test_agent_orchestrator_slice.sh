#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

assert_contains() {
  local haystack="$1"
  local needle="$2"
  if ! grep -Fq "$needle" <<<"$haystack"; then
    printf 'Expected output to contain: %s\n' "$needle" >&2
    printf 'Actual output:\n%s\n' "$haystack" >&2
    exit 1
  fi
}

assert_not_contains() {
  local haystack="$1"
  local needle="$2"
  if grep -Fq "$needle" <<<"$haystack"; then
    printf 'Expected output not to contain: %s\n' "$needle" >&2
    printf 'Actual output:\n%s\n' "$haystack" >&2
    exit 1
  fi
}

printf '== setup temp git repo ==\n'
BASE="$TMP/base"
WTROOT="$TMP/worktrees"
mkdir -p "$BASE" "$WTROOT"
git -C "$BASE" init -q -b main
git -C "$BASE" config user.email smoke@example.invalid
git -C "$BASE" config user.name 'Smoke Test'
git -C "$BASE" config commit.gpgsign false
git -C "$BASE" config tag.gpgsign false
printf 'hello\n' >"$BASE/README.md"
git -C "$BASE" add README.md
git -C "$BASE" commit -q -m init

printf '== agent-worktree list empty ==\n'
OUT="$($ROOT/bin/agent-worktree --repo "$BASE" --root "$WTROOT" list)"
printf '%s\n' "$OUT"
assert_contains "$OUT" 'Agent worktree slots'
assert_contains "$OUT" 'base  main'

printf '== agent-worktree create no launch ==\n'
OUT="$($ROOT/bin/agent-worktree --repo "$BASE" --root "$WTROOT" create --slug smoke-task --agent codex --no-launch)"
printf '%s\n' "$OUT"
assert_contains "$OUT" 'created'
assert_contains "$OUT" 'agent/smoke-task'
test -e "$WTROOT/base-smoke-task/.git"

printf '== agent-worktree json inventory ==\n'
OUT="$($ROOT/bin/agent-worktree --repo "$BASE" --root "$WTROOT" list --json)"
printf '%s\n' "$OUT"
python3 - "$OUT" <<'PY'
import json, sys
payload = json.loads(sys.argv[1])
assert payload['policy']['branch_prefix'] == 'agent/'
assert any(w['branch'] == 'agent/smoke-task' for w in payload['worktrees'])
PY

printf '== a2a agent card ==\n'
OUT="$($ROOT/bin/a2a-bridge --repo "$BASE" --root "$WTROOT" agent-card)"
printf '%s\n' "$OUT"
python3 - "$OUT" <<'PY'
import json, sys
card = json.loads(sys.argv[1])
assert card['name'] == 'Hermes cmux Agent Orchestrator'
assert any(skill['id'] == 'worktree_orchestration' for skill in card['skills'])
assert 'https://google.github.io/A2A/' in card.get('protocol_docs', '')
PY

printf '== a2a json-rpc list ==\n'
REQ='{"jsonrpc":"2.0","id":"smoke-1","method":"agent.listWorktrees","params":{}}'
OUT="$(printf '%s' "$REQ" | $ROOT/bin/a2a-bridge --repo "$BASE" --root "$WTROOT" rpc)"
printf '%s\n' "$OUT"
python3 - "$OUT" <<'PY'
import json, sys
resp = json.loads(sys.argv[1])
assert resp['jsonrpc'] == '2.0'
assert resp['id'] == 'smoke-1'
assert resp['result']['policy']['one_agent_per_worktree'] is True
assert any(w['branch'] == 'agent/smoke-task' for w in resp['result']['worktrees'])
PY

printf '== a2a json-rpc invalid request ==\n'
OUT="$(printf '[]' | $ROOT/bin/a2a-bridge --repo "$BASE" --root "$WTROOT" rpc)"
printf '%s\n' "$OUT"
python3 - "$OUT" <<'PY'
import json, sys
resp = json.loads(sys.argv[1])
assert resp['jsonrpc'] == '2.0'
assert resp['id'] is None
assert resp['error']['code'] == -32600
assert 'must be an object' in resp['error']['message']
PY

printf '== a2a json-rpc invalid params ==\n'
REQ='{"jsonrpc":"2.0","id":"bad-params","method":"agent.listWorktrees","params":[]}'
OUT="$(printf '%s' "$REQ" | $ROOT/bin/a2a-bridge --repo "$BASE" --root "$WTROOT" rpc)"
printf '%s\n' "$OUT"
python3 - "$OUT" <<'PY'
import json, sys
resp = json.loads(sys.argv[1])
assert resp['jsonrpc'] == '2.0'
assert resp['id'] == 'bad-params'
assert resp['error']['code'] == -32602
assert 'params must be an object' in resp['error']['message']
PY

printf '== agent-worktree invalid repo error ==\n'
if OUT="$($ROOT/bin/agent-worktree --repo "$TMP/missing-repo" --root "$WTROOT" list 2>&1)"; then
  printf 'Expected invalid repo to fail\n' >&2
  exit 1
fi
printf '%s\n' "$OUT"
assert_contains "$OUT" 'git failed'
assert_not_contains "$OUT" 'Traceback'

printf '== agent-worktree bad base error ==\n'
if OUT="$($ROOT/bin/agent-worktree --repo "$BASE" --root "$WTROOT" create --slug bad-base --base missing-ref --no-launch 2>&1)"; then
  printf 'Expected bad base to fail\n' >&2
  exit 1
fi
printf '%s\n' "$OUT"
assert_contains "$OUT" 'git failed'
assert_not_contains "$OUT" 'Traceback'

printf '== agent-worktree existing branch error ==\n'
git -C "$BASE" branch agent/existing-branch
if OUT="$($ROOT/bin/agent-worktree --repo "$BASE" --root "$WTROOT" create --slug existing-branch --no-launch 2>&1)"; then
  printf 'Expected existing branch to fail\n' >&2
  exit 1
fi
printf '%s\n' "$OUT"
assert_contains "$OUT" 'git failed'
assert_not_contains "$OUT" 'Traceback'

printf '== browser-smoke temp web ==\n'
mkdir -p "$TMP/web/hermes" "$TMP/web/openclaw"
printf '<!doctype html><title>Hermes Mission Control</title><h1>Hermes</h1>' >"$TMP/web/hermes/index.html"
printf '<!doctype html><title>OpenClaw Mission Control</title><h1>OpenClaw</h1>' >"$TMP/web/openclaw/index.html"
OUT="$($ROOT/bin/browser-smoke --directory "$TMP/web" --path /hermes/ --expect 'Hermes Mission Control' --path /openclaw/ --expect 'OpenClaw Mission Control')"
printf '%s\n' "$OUT"
assert_contains "$OUT" 'PASS /hermes/'
assert_contains "$OUT" 'PASS /openclaw/'
assert_contains "$OUT" 'browser smoke passed'
