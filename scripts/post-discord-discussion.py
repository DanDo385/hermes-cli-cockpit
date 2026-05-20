#!/usr/bin/env python3
"""Dry-run-first Discord discussion poster for cmux.

Default behavior prints the payload summary and exits. It posts only when --send is
provided. Token is read from DISCORD_BOT_TOKEN so secrets do not enter shell
history.
"""
from __future__ import annotations

import argparse
import json
import os
import sys
import urllib.error
import urllib.request
from pathlib import Path

API_BASE = "https://discord.com/api/v10"
MAX_CONTENT = 1900


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Post a discussion starter to a Discord channel, dry-run first.")
    parser.add_argument("--channel-id", default=os.environ.get("DISCORD_CHANNEL_ID", ""), help="Discord channel/thread ID. Defaults to DISCORD_CHANNEL_ID.")
    parser.add_argument("--file", help="Markdown/text file to post.")
    parser.add_argument("--text", help="Literal text to post.")
    parser.add_argument("--dry-run", action="store_true", help="Preview only. This is the default; kept for explicit command cards.")
    parser.add_argument("--send", action="store_true", help="Actually send to Discord. Without this, dry-run only.")
    return parser.parse_args()


def load_content(args: argparse.Namespace) -> str:
    if args.file and args.text:
        raise SystemExit("Use --file or --text, not both.")
    if args.file:
        return Path(args.file).read_text(encoding="utf-8")
    if args.text:
        return args.text
    return sys.stdin.read()


def truncate(content: str) -> str:
    content = content.strip()
    if len(content) <= MAX_CONTENT:
        return content
    return content[: MAX_CONTENT - 80].rstrip() + "\n\n[truncated by cmux Discord helper before posting]"


def post(channel_id: str, token: str, content: str) -> dict:
    url = f"{API_BASE}/channels/{channel_id}/messages"
    payload = json.dumps({"content": content}).encode("utf-8")
    request = urllib.request.Request(
        url,
        data=payload,
        headers={
            "Authorization": f"Bot {token}",
            "Content-Type": "application/json",
            "User-Agent": "cmux-discord-helper/0.1",
        },
        method="POST",
    )
    try:
        with urllib.request.urlopen(request, timeout=20) as response:
            return json.loads(response.read().decode("utf-8"))
    except urllib.error.HTTPError as exc:
        body = exc.read().decode("utf-8", errors="replace")
        raise SystemExit(f"Discord API error {exc.code}: {body}") from exc


def main() -> int:
    args = parse_args()
    content = truncate(load_content(args))
    if not args.channel_id:
        raise SystemExit("Missing --channel-id or DISCORD_CHANNEL_ID.")

    print("Discord discussion payload")
    print(f"  channel_id: {args.channel_id}")
    print(f"  chars:      {len(content)}")
    print(f"  mode:       {'send' if args.send else 'dry-run'}")
    print("\nPreview:\n")
    print(content)

    if not args.send:
        print("\nDry-run only. Re-run with --send to post.")
        return 0

    token = os.environ.get("DISCORD_BOT_TOKEN", "")
    if not token:
        raise SystemExit("Missing DISCORD_BOT_TOKEN; refusing to send.")
    result = post(args.channel_id, token, content)
    print("\nPosted.")
    print(f"  message_id: {result.get('id')}")
    print(f"  channel_id: {result.get('channel_id')}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
