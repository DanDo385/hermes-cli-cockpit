#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP="$(mktemp -d)"
STATE="$TMP/danos.sqlite3"
export DANOS_STATE="$STATE"
trap 'rm -rf "$TMP"' EXIT

assert_contains() {
  local haystack="$1" needle="$2"
  if ! grep -Fq "$needle" <<<"$haystack"; then
    printf 'Expected output to contain: %s\n' "$needle" >&2
    printf 'Actual output:\n%s\n' "$haystack" >&2
    exit 1
  fi
}

printf '== schema is valid JSON ==\n'
python3 -m json.tool "$ROOT/schemas/danos-action.schema.json" >/dev/null

printf '== actions schema --path ==\n'
OUT="$("$ROOT/bin/danos" actions schema --path)"
assert_contains "$OUT" "schemas/danos-action.schema.json"

printf '== actions print-examples emits valid JSON ==\n'
EXAMPLES="$("$ROOT/bin/danos" actions print-examples)"
echo "$EXAMPLES" | python3 -m json.tool >/dev/null
assert_contains "$EXAMPLES" "open_cmux_workspace"
assert_contains "$EXAMPLES" "open_obsidian_note"
assert_contains "$EXAMPLES" "capture_obsidian_text"
assert_contains "$EXAMPLES" "attach_tmux_session"
assert_contains "$EXAMPLES" "send_context_to_hermes"
assert_contains "$EXAMPLES" "close_day"

printf '== actions validate accepts canonical examples ==\n'
OUT="$(echo "$EXAMPLES" | "$ROOT/bin/danos" actions validate -)"
assert_contains "$OUT" "actions: ok"
assert_contains "$OUT" "6 envelopes"

printf '== actions validate accepts a single envelope from a file ==\n'
ENV_FILE="$TMP/single.json"
cat >"$ENV_FILE" <<'JSON'
{
  "id": "act-test-single",
  "ts": "2026-05-23T23:00:00Z",
  "source": "danos-cli",
  "action": "open_cmux_workspace",
  "target": { "kind": "cmux_workspace", "id": "home" },
  "payload": { "action_id": "danos.home" },
  "dry_run": true,
  "requires_confirmation": false
}
JSON
OUT="$("$ROOT/bin/danos" actions validate "$ENV_FILE")"
assert_contains "$OUT" "actions: ok"
assert_contains "$OUT" "open_cmux_workspace"

printf '== actions validate rejects missing required fields ==\n'
if echo '{"ts":"2026-05-23T23:00:00Z","source":"cmux","action":"open_cmux_workspace","target":{"kind":"cmux_workspace","id":"home"}}' \
  | "$ROOT/bin/danos" actions validate - 2>"$TMP/err"; then
  printf 'expected validation to fail when id is missing\n' >&2
  exit 1
fi
assert_contains "$(cat "$TMP/err")" "missing required field: id"

printf '== actions validate rejects unknown source ==\n'
if echo '{"id":"x","ts":"2026-05-23T23:00:00Z","source":"bogus","action":"open_cmux_workspace","target":{"kind":"cmux_workspace","id":"home"}}' \
  | "$ROOT/bin/danos" actions validate - 2>"$TMP/err"; then
  printf 'expected validation to fail for unknown source\n' >&2
  exit 1
fi
assert_contains "$(cat "$TMP/err")" "source: value 'bogus' not in allowed enum"

printf '== actions validate rejects bad timestamp ==\n'
if echo '{"id":"x","ts":"yesterday","source":"cmux","action":"open_cmux_workspace","target":{"kind":"cmux_workspace","id":"home"}}' \
  | "$ROOT/bin/danos" actions validate - 2>"$TMP/err"; then
  printf 'expected validation to fail for bad timestamp\n' >&2
  exit 1
fi
assert_contains "$(cat "$TMP/err")" "ts: not a valid RFC 3339 date-time"

printf '== actions validate rejects unknown top-level field ==\n'
if echo '{"id":"x","ts":"2026-05-23T23:00:00Z","source":"cmux","action":"open_cmux_workspace","target":{"kind":"cmux_workspace","id":"home"},"surprise":"nope"}' \
  | "$ROOT/bin/danos" actions validate - 2>"$TMP/err"; then
  printf 'expected validation to fail for unknown top-level field\n' >&2
  exit 1
fi
assert_contains "$(cat "$TMP/err")" "unknown top-level field: surprise"

printf '== actions validate rejects bad action verb pattern ==\n'
if echo '{"id":"x","ts":"2026-05-23T23:00:00Z","source":"cmux","action":"BAD-VERB","target":{"kind":"k","id":"i"}}' \
  | "$ROOT/bin/danos" actions validate - 2>"$TMP/err"; then
  printf 'expected validation to fail for bad action verb\n' >&2
  exit 1
fi
assert_contains "$(cat "$TMP/err")" "action: does not match pattern"

printf '== actions validate --json reports structured result ==\n'
OUT="$(echo '{"ts":"2026-05-23T23:00:00Z","source":"cmux","action":"open_cmux_workspace","target":{"kind":"cmux_workspace","id":"home"}}' \
  | "$ROOT/bin/danos" actions validate - --json || true)"
echo "$OUT" | python3 -m json.tool >/dev/null
assert_contains "$OUT" '"ok": false'
assert_contains "$OUT" "missing required field: id"

printf 'test_danos_actions.sh: OK\n'
