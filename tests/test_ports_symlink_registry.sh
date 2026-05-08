#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
mkdir -p "$TMP/bin" "$TMP/install"

cat >"$TMP/bin/lsof" <<'SH'
#!/usr/bin/env bash
set -euo pipefail
cat <<'OUT'
COMMAND   PID USER   FD   TYPE DEVICE SIZE/OFF NODE NAME
Python  11111 dan   20u  IPv4 0xabc      0t0  TCP 127.0.0.1:4000 (LISTEN)
OUT
SH
chmod +x "$TMP/bin/lsof"

ln -s "$ROOT/bin/ports" "$TMP/install/ports"

OUT="$(PATH="$TMP/bin:/usr/bin:/bin" HOME="$TMP/home" "$TMP/install/ports")"
printf '%s\n' "$OUT"

if ! grep -Fq "Registry: $ROOT/config/ports.toml" <<<"$OUT"; then
  echo 'symlinked ports did not discover repo config/ports.toml' >&2
  exit 1
fi

if ! grep -Fq 'REGISTERED' <<<"$OUT" || ! grep -Fq 'litellm-proxy' <<<"$OUT"; then
  echo 'symlinked ports did not classify port 4000 using repo registry' >&2
  exit 1
fi
