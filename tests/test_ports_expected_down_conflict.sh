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
python  22222 dan   21u  IPv4 0xdef      0t0  TCP 127.0.0.1:8000 (LISTEN)
OUT
SH
chmod +x "$TMP/bin/lsof"

cat >"$TMP/ports.toml" <<'TOML'
[portfolio-site]
host = "dev-host"
frontend = 3000
preview = 3001

[api-server]
host = "dev-host"
http = 8000

[wrong-api-claim]
host = "dev-host"
http = 8000
TOML

OUT="$(PATH="$TMP/bin:/usr/bin:/bin" "$ROOT/bin/ports" --registry "$TMP/ports.toml")"
printf '%s\n' "$OUT"

for expected in \
  'REGISTERED' \
  'portfolio-site' \
  'frontend' \
  'EXPECTED_DOWN' \
  'preview' \
  '3001' \
  'CONFLICT' \
  'api-server,wrong-api-claim' \
  '8000'; do
  if ! grep -Fq "$expected" <<<"$OUT"; then
    echo "missing expected output: $expected" >&2
    exit 1
  fi
done

if grep -F 'api-server,wrong-api-claim' <<<"$OUT" | grep -Fq 'REGISTERED'; then
  echo 'duplicate registry claims must not be reported as safely registered' >&2
  exit 1
fi
