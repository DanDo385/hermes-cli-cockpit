#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
STATE="$ROOT/.tmp-keystroke-mentor-test.json"
export KEYSTROKE_MENTOR_STATE="$STATE"
rm -f "$STATE"

assert_contains() {
  local haystack="$1" needle="$2"
  if ! grep -Fq "$needle" <<<"$haystack"; then
    printf 'Expected output to contain: %s\n' "$needle" >&2
    exit 1
  fi
}

assert_not_contains() {
  local haystack="$1" needle="$2"
  if grep -Fq "$needle" <<<"$haystack"; then
    printf 'Expected output not to contain: %s\n' "$needle" >&2
    exit 1
  fi
}

printf '== list-contexts ==\n'
OUT="$("$ROOT/bin/keystroke-mentor" list-contexts)"
assert_contains "$OUT" "nvim"
assert_contains "$OUT" "openclaw"

printf '== nvim context ==\n'
OUT="$("$ROOT/bin/keystroke-mentor" --context nvim --limit 8)"
assert_contains "$OUT" "nvim.save"
assert_contains "$OUT" ":w"
assert_not_contains "$OUT" "Traceback"

printf '== tmux context ==\n'
OUT="$("$ROOT/bin/keystroke-mentor" --context tmux --limit 5)"
assert_contains "$OUT" "Ctrl-b w"
assert_contains "$OUT" "tmux.zoom"

printf '== boost ==\n'
"$ROOT/bin/keystroke-mentor" boost nvim.save >/dev/null
OUT="$("$ROOT/bin/keystroke-mentor" --context nvim --limit 3)"
assert_contains "$OUT" "nvim.save"

printf '== invalid context ==\n'
if OUT="$("$ROOT/bin/keystroke-mentor" --context not-a-context 2>&1)"; then
  printf 'Expected invalid context to fail\n' >&2
  exit 1
fi
assert_contains "$OUT" "unknown context"
assert_not_contains "$OUT" "Traceback"

printf '== invalid boost ==\n'
if OUT="$("$ROOT/bin/keystroke-mentor" boost no.such.action 2>&1)"; then
  printf 'Expected invalid boost to fail\n' >&2
  exit 1
fi
assert_contains "$OUT" "unknown action"
assert_not_contains "$OUT" "Traceback"

printf 'test_keystroke_mentor.sh: OK\n'
