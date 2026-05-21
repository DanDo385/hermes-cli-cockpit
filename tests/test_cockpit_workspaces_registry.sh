#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

printf '== registry verify ==\n'
"$ROOT/bin/cockpit-workspaces" verify

printf '== five workspaces listed ==\n'
OUT="$("$ROOT/bin/cockpit-workspaces" list)"
assert_count() {
  local n
  n="$(grep -c '^  [1-5]\.' <<<"$OUT" || true)"
  if [[ "$n" -ne 5 ]]; then
    printf 'Expected 5 workspace lines, got %s\n' "$n" >&2
    printf '%s\n' "$OUT" >&2
    exit 1
  fi
}
assert_count
grep -Fq 'Hermes Tool / Hermes CLI Mission Control' <<<"$OUT"
grep -Fq 'OpenClaw Tool / OpenClaw CLI Mission Control' <<<"$OUT"
grep -Fq 'Open Source Radar / Community' <<<"$OUT"

printf 'test_cockpit_workspaces_registry.sh: OK\n'
