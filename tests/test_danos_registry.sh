#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
STATE="$ROOT/.tmp-danos-test.sqlite3"
UNEXPECTED_STATE="$ROOT/planned"
rm -f "$STATE" "$UNEXPECTED_STATE"
export DANOS_STATE="$STATE"
trap 'rm -f "$STATE" "$UNEXPECTED_STATE"' EXIT

assert_contains() {
  local haystack="$1" needle="$2"
  if ! grep -Fq "$needle" <<<"$haystack"; then
    printf 'Expected output to contain: %s\n' "$needle" >&2
    printf 'Actual output:\n%s\n' "$haystack" >&2
    exit 1
  fi
}

printf '== init and seed ==\n'
OUT="$("$ROOT/bin/danos" init --seed-workspaces)"
assert_contains "$OUT" "DanOS registry initialized"
assert_contains "$OUT" "seeded: 6 workspaces"

printf '== status ==\n'
OUT="$("$ROOT/bin/danos" status)"
assert_contains "$OUT" "DanOS cockpit status"
assert_contains "$OUT" "workspaces  6"

printf '== workspaces include home ==\n'
OUT="$("$ROOT/bin/danos" workspaces list)"
assert_contains "$OUT" "home"
assert_contains "$OUT" "DanOS Home / Cockpit Overview"

printf '== create task ==\n'
OUT="$("$ROOT/bin/danos" tasks create --id TASK-test --title 'Review PR war room MVP' --project hermes --state planned --priority 2)"
assert_contains "$OUT" "created task TASK-test"
if [[ -e "$UNEXPECTED_STATE" ]]; then
  printf 'Unexpected repo-root SQLite state file created: %s\n' "$UNEXPECTED_STATE" >&2
  exit 1
fi
OUT="$("$ROOT/bin/danos" tasks list --state planned)"
assert_contains "$OUT" "TASK-test"
assert_contains "$OUT" "Review PR war room MVP"

printf '== register agent ==\n'
OUT="$("$ROOT/bin/danos" agents register --id agent-test --tool codex --status running --task TASK-test --workspace agent-deck --branch agent/pr-war-room)"
assert_contains "$OUT" "registered agent agent-test"
OUT="$("$ROOT/bin/danos" agents list)"
assert_contains "$OUT" "agent-test"
assert_contains "$OUT" "codex"

printf '== home overview ==\n'
OUT="$("$ROOT/bin/danos" home)"
assert_contains "$OUT" "DanOS Home"
assert_contains "$OUT" "agent-test"

printf 'test_danos_registry.sh: OK\n'
