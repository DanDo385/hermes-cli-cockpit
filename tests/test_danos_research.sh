#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP="$(mktemp -d)"
STATE="$TMP/danos.sqlite3"
export DANOS_STATE="$STATE"
trap 'rm -rf "$TMP"' EXIT

assert_contains() {
  local haystack="$1" needle="$2"
  if ! grep -Fq "$needle" <<<"$haystack"; then
    printf 'Expected output to contain: %s\n' "$needle" >&2
    printf 'Actual output:\n%s\n' "$haystack" >&2
    exit 1
  fi
}

assert_not_contains() {
  local haystack="$1" needle="$2"
  if grep -Fq "$needle" <<<"$haystack"; then
    printf 'Expected output NOT to contain: %s\n' "$needle" >&2
    printf 'Actual output:\n%s\n' "$haystack" >&2
    exit 1
  fi
}

printf '== research brief emits markdown dry-run packet ==\n'
SOURCE_FILE="$TMP/source.md"
cat >"$SOURCE_FILE" <<'EOF'
Base is hiring infrastructure-focused solutions engineers. The role emphasizes crypto infrastructure, customer debugging, and clear technical communication.
EOF
OUT="$("$ROOT/bin/danos" research brief \
  --mode job \
  --topic "Base infra solutions engineer role" \
  --question "What should Dan know and say in outreach?" \
  --source "$SOURCE_FILE" \
  --dry-run)"
assert_contains "$OUT" "# Research Brief: Base infra solutions engineer role"
assert_contains "$OUT" "Mode: job"
assert_contains "$OUT" "Dry run: true"
assert_contains "$OUT" "## Claims / Evidence"
assert_contains "$OUT" "$SOURCE_FILE"
assert_contains "$OUT" "## Contradictions / Uncertainties"
assert_contains "$OUT" "## Next Actions"
assert_contains "$OUT" "No external side effects were performed."
assert_not_contains "$OUT" "Traceback"
if [ -e "$STATE" ]; then
  printf 'dry-run research brief unexpectedly created state file: %s\n' "$STATE" >&2
  exit 1
fi

printf '== research brief ignores markdown frontmatter when deriving claim preview ==\n'
FRONTMATTER_SOURCE="$TMP/frontmatter-source.md"
cat >"$FRONTMATTER_SOURCE" <<'EOF'
---
title: Test note
---

# Heading

Useful claim after frontmatter.
EOF
OUT="$("$ROOT/bin/danos" research brief \
  --mode job \
  --topic "Frontmatter source" \
  --question "What is the claim?" \
  --source "$FRONTMATTER_SOURCE" \
  --dry-run)"
assert_contains "$OUT" "Claim: Useful claim after frontmatter."
assert_not_contains "$OUT" "Claim: ---"

printf '== research brief skips source-pack metadata and tables for claim preview ==\n'
SOURCE_PACK="$TMP/source-pack.md"
cat >"$SOURCE_PACK" <<'EOF'
---
title: Test source pack
---

# Test Source Pack

Retrieval date: 2026-06-11

## Sources checked

| Source | URL |
|---|---|
| Example | https://example.com |

## Role facts

- Role: Solutions Engineer @ Helius.
- Company: Helius.
EOF
OUT="$("$ROOT/bin/danos" research brief \
  --mode job \
  --topic "Metadata source" \
  --question "What is the claim?" \
  --source "$SOURCE_PACK" \
  --dry-run)"
assert_contains "$OUT" "Claim: Role: Solutions Engineer @ Helius."
assert_not_contains "$OUT" "Claim: Retrieval date"
assert_not_contains "$OUT" "Claim: | Source"

printf '== research brief emits valid json ==\n'
JSON_OUT="$("$ROOT/bin/danos" research brief \
  --mode learn \
  --topic "Rollup mechanics" \
  --question "What should Dan learn first?" \
  --source "$SOURCE_FILE" \
  --dry-run \
  --json)"
echo "$JSON_OUT" | python3 -m json.tool >/dev/null
assert_contains "$JSON_OUT" '"mode": "learn"'
assert_contains "$JSON_OUT" '"dry_run": true'
assert_contains "$JSON_OUT" '"claims"'
assert_contains "$JSON_OUT" '"next_actions"'

printf '== research brief rejects invalid mode ==\n'
if "$ROOT/bin/danos" research brief --mode nonsense --topic X --question Y --dry-run 2>"$TMP/err"; then
  printf 'expected invalid mode to fail\n' >&2
  exit 1
fi
assert_contains "$(cat "$TMP/err")" "invalid choice"

printf 'test_danos_research.sh: OK\n'
