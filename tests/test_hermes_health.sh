#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

mkdir -p "$TMP/bin" "$TMP/home/.hermes/logs" "$TMP/home/.hermes/cron"

cat >"$TMP/bin/hermes" <<'SH'
#!/usr/bin/env bash
set -euo pipefail
case "${1:-} ${2:-}" in
  "gateway status")
    cat <<'OUT'
✓ Gateway service is loaded
{
  "PID" = 12345;
};
OUT
    ;;
  "cron status")
    cat <<'OUT'
✓ Gateway is running — cron jobs will fire automatically
OUT
    ;;
  *)
    echo "unexpected hermes args: $*" >&2
    exit 2
    ;;
esac
SH
chmod +x "$TMP/bin/hermes"

cat >"$TMP/bin/op" <<'SH'
#!/usr/bin/env bash
set -euo pipefail
cat <<'OUT'
User Type: SERVICE_ACCOUNT
OUT
SH
chmod +x "$TMP/bin/op"

cat >"$TMP/bin/ssh-add" <<'SH'
#!/usr/bin/env bash
set -euo pipefail
echo 'The agent has no identities.'
exit 1
SH
chmod +x "$TMP/bin/ssh-add"

cat >"$TMP/bin/lsof" <<'SH'
#!/usr/bin/env bash
set -euo pipefail
cat <<'OUT'
COMMAND   PID USER   FD   TYPE DEVICE SIZE/OFF NODE NAME
Python  12345 dan    3u  IPv4 0xabc      0t0  TCP *:8080 (LISTEN)
OUT
SH
chmod +x "$TMP/bin/lsof"

cat >"$TMP/home/.hermes/cron/jobs.json" <<'JSON'
{
  "jobs": [
    {
      "id": "daily",
      "name": "daily",
      "enabled": true,
      "model": "gpt-5.5",
      "provider": "openai-codex"
    },
    {
      "id": "inherit",
      "name": "inherit default",
      "enabled": true,
      "model": null,
      "provider": null
    }
  ]
}
JSON

cat >"$TMP/home/.hermes/logs/gateway.error.log" <<'LOG'
RuntimeError: HTTP 429: Gemini HTTP 429 (RESOURCE_EXHAUSTED): Quota exceeded for model gemini-2.5-pro
LOG

OUT="$(
  HOME="$TMP/home" \
  HERMES_HOME="$TMP/home/.hermes" \
  PATH="$TMP/bin:/usr/bin:/bin" \
  SSH_AUTH_SOCK="$TMP/agent.sock" \
  "$ROOT/bin/hermes-health"
)"

printf '%s\n' "$OUT"

if ! grep -Fq 'cron models:' <<<"$OUT"; then
  echo 'expected cron models row' >&2
  exit 1
fi

if ! grep -Fq 'no active Gemini cron overrides' <<<"$OUT"; then
  echo 'expected active Gemini cron overrides to be clear' >&2
  exit 1
fi

if grep -Fq 'gemini:            ❌' <<<"$OUT"; then
  echo 'stale Gemini log produced red failure' >&2
  exit 1
fi

if ! grep -Fq 'historical Gemini quota errors remain in logs' <<<"$OUT"; then
  echo 'expected historical Gemini warning' >&2
  exit 1
fi
