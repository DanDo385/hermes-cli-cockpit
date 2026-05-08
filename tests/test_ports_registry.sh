#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
mkdir -p "$TMP/bin"

cat >"$TMP/bin/lsof" <<'SH'
#!/usr/bin/env bash
set -euo pipefail
cat <<'OUT'
COMMAND   PID USER   FD   TYPE DEVICE SIZE/OFF NODE NAME
node    11111 dan   20u  IPv6 0xabc      0t0  TCP *:3000 (LISTEN)
postgres 222 dan    7u  IPv4 0xdef      0t0  TCP 127.0.0.1:5432 (LISTEN)
OUT
SH
chmod +x "$TMP/bin/lsof"

cat >"$TMP/ports.toml" <<'TOML'
[portfolio-site]
host = "dev-host"
frontend = 3000

[postgres-local]
host = "control-host"
database = 5432
TOML

OUT="$(PATH="$TMP/bin:/usr/bin:/bin" "$ROOT/bin/ports" --registry "$TMP/ports.toml")"
printf '%s\n' "$OUT"

for expected in \
  'REGISTERED' \
  'portfolio-site' \
  'frontend' \
  'postgres-local' \
  'database'; do
  if ! grep -Fq "$expected" <<<"$OUT"; then
    echo "missing expected output: $expected" >&2
    exit 1
  fi
done

if grep -Fq 'UNKNOWN' <<<"$OUT"; then
  echo 'did not expect unknown listeners in registry test' >&2
  exit 1
fi
