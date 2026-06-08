#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP="$(mktemp -d)"
STATE="$TMP/danos.sqlite3"
VAULT="$TMP/vault"
export DANOS_STATE="$STATE"
export OBSIDIAN_VAULT_PATH="$VAULT"
trap 'rm -rf "$TMP"' EXIT

assert_contains() {
  local haystack="$1" needle="$2"
  if ! grep -Fq "$needle" <<<"$haystack"; then
    printf 'Expected output to contain: %s\n' "$needle" >&2
    printf 'Actual output:\n%s\n' "$haystack" >&2
    exit 1
  fi
}

assert_file_contains() {
  local file="$1" needle="$2"
  if ! grep -Fq "$needle" "$file"; then
    printf 'Expected file %s to contain: %s\n' "$file" "$needle" >&2
    printf 'Actual file:\n' >&2
    sed -n '1,220p' "$file" >&2
    exit 1
  fi
}

TODAY="$(date +%F)"
DAILY="$VAULT/agent-hermes/daily/$TODAY.md"
INBOX="$VAULT/INBOX/danos-capture.md"
DASHBOARD="$VAULT/agent-hermes/notes/danos-dashboard.md"

printf '== obsidian today creates an operating daily note ==\n'
OUT="$("$ROOT/bin/danos" obsidian today --priority 'Ship Obsidian loop' --priority 'Review carryovers' --metric focus=7 --metric energy=6)"
assert_contains "$OUT" "DanOS Obsidian Today"
assert_contains "$OUT" "$DAILY"
assert_file_contains "$DAILY" "# $TODAY"
assert_file_contains "$DAILY" "## Current Focus"
assert_file_contains "$DAILY" "1. [ ] Ship Obsidian loop"
assert_file_contains "$DAILY" "2. [ ] Review carryovers"
assert_file_contains "$DAILY" "focus: 7"
assert_file_contains "$DAILY" "energy: 6"
assert_file_contains "$DAILY" "## Activity Log"

printf '== obsidian capture appends to inbox ==\n'
OUT="$("$ROOT/bin/danos" obsidian capture 'Turn vault into execution surface' --tag systems --tag obsidian)"
assert_contains "$OUT" "captured to"
assert_file_contains "$INBOX" "Turn vault into execution surface"
assert_file_contains "$INBOX" "tags: systems, obsidian"

printf '== obsidian log appends activity to daily note ==\n'
OUT="$("$ROOT/bin/danos" obsidian log 'Implemented first Obsidian loop test' --kind build)"
assert_contains "$OUT" "logged activity"
assert_file_contains "$DAILY" "Implemented first Obsidian loop test"
assert_file_contains "$DAILY" "kind=build"

printf '== obsidian close-day appends reflection and end metrics ==\n'
OUT="$("$ROOT/bin/danos" obsidian close-day --summary 'The vault loop is now actionable.' --metric effort=8 --metric family_time=5)"
assert_contains "$OUT" "closed day"
assert_file_contains "$DAILY" "## Close Day"
assert_file_contains "$DAILY" "The vault loop is now actionable."
assert_file_contains "$DAILY" "effort: 8"
assert_file_contains "$DAILY" "family_time: 5"

printf '== obsidian dashboard materializes a local intelligence surface ==\n'
OUT="$("$ROOT/bin/danos" obsidian dashboard)"
assert_contains "$OUT" "DanOS Obsidian Dashboard"
assert_contains "$OUT" "$DASHBOARD"
assert_file_contains "$DASHBOARD" "# DanOS Obsidian Dashboard"
assert_file_contains "$DASHBOARD" "[[agent-hermes/daily/$TODAY|Today]]"
assert_file_contains "$DASHBOARD" "[[INBOX/danos-capture|Quick Capture Inbox]]"
assert_file_contains "$DASHBOARD" "Current Focus"

printf 'test_danos_obsidian_loop.sh: OK\n'
