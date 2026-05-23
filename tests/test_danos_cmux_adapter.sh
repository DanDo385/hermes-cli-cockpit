#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP="$(mktemp -d)"
STATE="$TMP/danos.sqlite3"
LOG="$TMP/cmux.log"
export DANOS_STATE="$STATE"
export CMUX_FAKE_LOG="$LOG"
trap 'rm -rf "$TMP"' EXIT

mkdir -p "$TMP/bin"
cat >"$TMP/bin/cmux" <<'SH'
#!/usr/bin/env bash
printf '%s\n' "$*" >>"${CMUX_FAKE_LOG:?}"
case "$1" in
  list-workspaces)
    printf '[{"id":"ws-home","title":"DanOS Home"}]\n'
    ;;
  notify)
    printf 'notified\n'
    ;;
  browser)
    printf 'browser ok\n'
    ;;
  action)
    printf 'action ok\n'
    ;;
  send)
    printf 'send ok\n'
    ;;
  *)
    printf 'fake cmux: %s\n' "$*"
    ;;
esac
SH
chmod +x "$TMP/bin/cmux"

assert_contains() {
  local haystack="$1" needle="$2"
  if ! grep -Fq "$needle" <<<"$haystack"; then
    printf 'Expected output to contain: %s\n' "$needle" >&2
    printf 'Actual output:\n%s\n' "$haystack" >&2
    exit 1
  fi
}

assert_log_contains() {
  local needle="$1"
  if ! grep -Fq "$needle" "$LOG"; then
    printf 'Expected fake cmux log to contain: %s\n' "$needle" >&2
    printf 'Actual log:\n' >&2
    cat "$LOG" >&2 || true
    exit 1
  fi
}

PATH="$TMP/bin:/usr/bin:/bin" "$ROOT/bin/danos" init --seed-workspaces >/dev/null

printf '== cmux workspace adapter ==\n'
OUT="$(PATH="$TMP/bin:/usr/bin:/bin" "$ROOT/bin/danos" cmux workspaces)"
assert_contains "$OUT" "DanOS cmux workspace adapter"
assert_contains "$OUT" "home"
assert_contains "$OUT" "danos.home"
assert_contains "$OUT" "bin/danos home"

printf '== cmux open-home ==\n'
OUT="$(PATH="$TMP/bin:/usr/bin:/bin" "$ROOT/bin/danos" cmux open-home)"
assert_contains "$OUT" "opened DanOS Home via cmux action danos.home"
assert_log_contains "action run danos.home"

printf '== cmux notify ==\n'
OUT="$(PATH="$TMP/bin:/usr/bin:/bin" "$ROOT/bin/danos" cmux notify --title 'DanOS' --body 'PR room ready')"
assert_contains "$OUT" "notified"
assert_log_contains "notify --title DanOS --body PR room ready"

printf '== cmux open-browser ==\n'
OUT="$(PATH="$TMP/bin:/usr/bin:/bin" "$ROOT/bin/danos" cmux open-browser 'https://github.com/manaflow-ai/cmux/pull/123')"
assert_contains "$OUT" "opened browser surface"
assert_log_contains "browser open https://github.com/manaflow-ai/cmux/pull/123"

printf '== cmux send ==\n'
OUT="$(PATH="$TMP/bin:/usr/bin:/bin" "$ROOT/bin/danos" cmux send surface:2 'Review this PR')"
assert_contains "$OUT" "sent text to surface:2"
assert_log_contains "send surface:2 Review this PR"

printf '== pr war-room dry run ==\n'
OUT="$(PATH="$TMP/bin:/usr/bin:/bin" "$ROOT/bin/danos" pr war-room 123 --repo manaflow-ai/cmux --dry-run)"
assert_contains "$OUT" "DanOS PR War Room"
assert_contains "$OUT" "PR: https://github.com/manaflow-ai/cmux/pull/123"
assert_contains "$OUT" "cmux browser open https://github.com/manaflow-ai/cmux/pull/123"
assert_contains "$OUT" "cmux notify --title 'DanOS PR War Room' --body 'Ready: manaflow-ai/cmux#123'"

printf '== pr war-room live adapter ==\n'
OUT="$(PATH="$TMP/bin:/usr/bin:/bin" "$ROOT/bin/danos" pr war-room 124 --repo manaflow-ai/cmux)"
assert_contains "$OUT" "opened PR War Room for manaflow-ai/cmux#124"
assert_log_contains "browser open https://github.com/manaflow-ai/cmux/pull/124"
assert_log_contains "notify --title DanOS PR War Room --body Ready: manaflow-ai/cmux#124"

printf 'test_danos_cmux_adapter.sh: OK\n'
