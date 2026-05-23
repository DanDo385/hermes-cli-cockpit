#!/usr/bin/env bash
# MBP split repo (hermes-tmux-workspaces) must stay a strict subset of iMac registry (6 surfaces, no home on MBP).
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMUX_WS="${HERMES_TMUX_WORKSPACES:-$HOME/Code/hermes-tmux-workspaces}"

if [[ ! -f "$TMUX_WS/config/cockpit-workspaces.toml" ]]; then
  printf 'skip: hermes-tmux-workspaces not found at %s\n' "$TMUX_WS"
  exit 0
fi

printf '== iMac registry (6 workspaces) ==\n'
"$ROOT/bin/cockpit-workspaces" verify

printf '== MBP registry (5 remote workspaces) ==\n'
"$TMUX_WS/bin/cockpit-workspaces" verify 2>/dev/null || {
  # Older split verify may expect 5 workspaces only.
  OUT="$("$TMUX_WS/bin/cockpit-workspaces" list)"
  n="$(grep -cE '^  [1-5]\.' <<<"$OUT" || true)"
  [[ "$n" -eq 5 ]] || { echo "Expected 5 MBP workspace lines, got $n" >&2; exit 1; }
}

MBP_IDS="$("$TMUX_WS/bin/cockpit-workspaces" list | sed -n 's/.* id=\([^ ]*\) .*/\1/p')"
for id in hermes openclaw coding-workbench agent-deck open-source-radar; do
  grep -qx "$id" <<<"$MBP_IDS" || {
    echo "MBP registry missing workspace id: $id" >&2
    exit 1
  }
done

grep -Fq 'home' <<<"$MBP_IDS" && {
  echo "MBP registry must not include home (iMac-local only)" >&2
  exit 1
}

printf 'test_registry_cross_repo.sh: OK\n'
