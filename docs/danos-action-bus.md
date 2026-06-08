# DanOS action bus

This document explains why DanOS Core needs an action bus, what shape it
should take, and how cmux and an Obsidian plugin should both use it.

Cross-references:

- Boundaries: [`docs/adr/0003-danos-cockpit-boundaries.md`](adr/0003-danos-cockpit-boundaries.md)
- Plan: [`docs/plans/danos-cockpit-integration-plan.md`](plans/danos-cockpit-integration-plan.md)
- Envelope: [`schemas/danos-action.schema.json`](../schemas/danos-action.schema.json)

## Why an action bus

DanOS Cockpit has more than one client today — cmux buttons, the `bin/danos`
CLI, agent worktrees, and (soon) an Obsidian plugin and a small web
dashboard. Each of these wants to "do something local": open a workspace,
attach a tmux session, capture a note, send context to Hermes, close the
day.

Without a bus, each client invents its own shell incantation, owns its own
audit, and decides for itself whether to dry-run. That gives:

- Inconsistent behavior between cmux button, plugin, and CLI.
- Multiple places that touch SQLite, Obsidian, and `cmux` directly.
- No single place to enforce "no surprise side effects" or
  "this needs operator confirmation".
- No single audit log.

A small, opinionated **action bus** owned by DanOS Core fixes this:

1. Every client builds the same envelope shape
   (`schemas/danos-action.schema.json`) and submits it to DanOS.
2. DanOS Core resolves the envelope into a concrete plan, applies dry-run
   and confirmation policy, performs the local effect, and records the
   request + result in `events`.
3. Clients become **dumb terminals** for the operator's intent. They render
   state and ship envelopes. They do not own state.

This is the same pattern that makes `git`, `kubectl`, and `systemctl`
debuggable: a single call site for side effects.

## Transport options

We deliberately keep the transport boring. Three reasonable shapes:

### A. CLI / Markdown-first (recommended start)

- Clients shell out to `bin/danos` (e.g. `bin/danos actions validate`,
  future `bin/danos actions submit`).
- Stateful effects: SQLite + filesystem (Markdown notes, capture files).
- Inputs/outputs: JSON on stdin/stdout, plus optional Markdown that DanOS
  can render in a dashboard or Obsidian.
- Pros: zero new ports, no daemon, trivial to audit, works inside tmux,
  works inside cmux, works inside an Obsidian plugin's child process.
- Cons: per-call fork/exec cost, harder for in-Obsidian UIs that prefer
  HTTP.

### B. HTTP (loopback only)

- A small `bin/danos serve` exposes `POST /v1/actions` and a few read-only
  GETs.
- Clients send JSON with the envelope; the server validates and routes to
  the same `route_action()` used by the CLI.
- Pros: native fit for Obsidian plugins, web dashboards, mobile-over-Tailscale.
- Cons: one more local port, must be loopback-only by default, must refuse
  unknown sources.

### C. File queue

- Clients drop envelope JSON files into a directory; a long-running DanOS
  worker (launchd) consumes them.
- Pros: brutally simple, works across machines via shared filesystem.
- Cons: latency, ordering, requires a worker, harder for synchronous UI.

## Recommended order

1. **CLI / Markdown first.**
   - Ship `bin/danos actions validate` and `bin/danos actions print-examples`
     now. They give us a real schema, real examples, and a real CLI surface
     that other clients can call without us writing a daemon.
   - Add `bin/danos obsidian open` / `bin/danos obsidian capture` as the
     first concrete action verbs (Phase 2 of the integration plan). They
     are pure local effects and trivially auditable.
2. **HTTP next.**
   - Add `bin/danos serve` (Phase 3) using stdlib `http.server`.
   - Bind 127.0.0.1 only by default. Reject non-loopback binds unless an
     explicit `--allow-non-loopback` flag is set.
   - The HTTP layer MUST call the same `route_action()` the CLI calls. No
     parallel implementation.
3. **Plugin third.**
   - Build the Obsidian plugin (Phase 4) on top of the HTTP bus. The plugin
     is a renderer + envelope sender. It does not start processes.
4. **File queue last, only if needed.**
   - Add a queue dir (e.g. `~/.local/state/hermes-cli-cockpit/queue/`) only
     once we have a use case (offline capture, cross-machine drops). Keep
     CLI/HTTP as primary.

## Security model

Local-first, paranoid by default.

- **Loopback only.** HTTP server binds 127.0.0.1; file queue lives in
  `~/.local/state/`. No public listeners, ever. No reverse proxies in
  this repo.
- **Allowlisted sources.** The `source` field is enum-constrained
  (`danos-cli`, `cmux`, `obsidian-plugin`, `tmux`, `agent`,
  `web-dashboard`, `file-queue`, `test`). Unknown sources are rejected.
- **Allowlisted verbs.** The `action` field MUST appear in the DanOS
  controlled vocabulary. Unknown verbs are rejected before any side effect.
- **No raw secrets in the envelope.** Secrets are referenced by id (1Password
  item id, vault alias, env var name). Never inline.
- **No raw hostnames or `/Users/...` paths in shared examples.** Operator
  config files (`.cmux/cmux.json`, `config/cockpit-workspaces.toml`) may
  reference local paths because they are operator-private; new public docs
  and schemas in this repo follow the sanitization rule from ADR 0003.
- **Audit everything.** Every accepted envelope (and its dry-run result) is
  appended to the `events` table with the source, verb, target id, and
  truncated payload.
- **No automatic posting.** Verbs that touch GitHub or Discord MUST set
  `requires_confirmation: true` and MUST NOT bypass the existing
  draft-first rule documented in `config/cockpit-workspaces.toml`.
- **No raw shell from envelope.** There is no `exec` verb. The vocabulary
  only contains intent verbs that DanOS Core knows how to map to safe local
  effects.

## Dry-run behavior

Dry-run is a first-class flag on every envelope.

- `dry_run: true` MUST cause Core to:
  - Validate the envelope.
  - Resolve the verb (e.g. `attach_tmux_session` -> the exact tmux command
    it would run).
  - Return the resolved plan as JSON.
  - Append a `dry-run` audit row.
  - **Not** spawn `cmux`, `tmux`, `obsidian://` URIs, gateways, or HTTP
    requests with side effects.
- The CLI should default to `dry_run: false` for read-only verbs and
  `dry_run: true` for mutating verbs unless the operator opts in.
- Tests rely on `dry_run: true` to assert behavior without touching the
  user's actual cmux / tmux / vault.

## How cmux and the Obsidian plugin both talk to DanOS Core

Both surfaces are **clients** of DanOS Core. They never talk to each other
directly.

```
cmux button click                        Obsidian plugin command
  |                                            |
  |  builds envelope                           |  builds envelope
  v                                            v
+----------------------------+         +----------------------------+
| bin/danos actions submit   |  or  -> | POST /v1/actions           |
| (CLI / shell-out)          |         | (HTTP, loopback only)      |
+--------------+-------------+         +-------------+--------------+
               \\                                   //
                \\                                 //
                 v                                v
             +-----------------------------------------+
             |  DanOS Core: route_action(envelope)     |
             |  - schema validation                    |
             |  - source/verb allowlist                |
             |  - dry-run + confirmation policy        |
             |  - effect: cmux / tmux / vault / db     |
             |  - audit append                         |
             +-----------------------------------------+
                              |
                              v
                       result JSON
```

Concretely:

- A cmux button that "opens DanOS Home" today calls
  `bin/danos cmux open-home`. After Phase 1 it builds an envelope:

  ```json
  {
    "id": "act-...",
    "ts": "2026-05-23T23:00:00Z",
    "source": "cmux",
    "action": "open_cmux_workspace",
    "target": { "kind": "cmux_workspace", "id": "home" },
    "payload": { "action_id": "danos.home" }
  }
  ```

  …and submits it. The user-visible behavior is unchanged; the call path
  becomes uniform.

- An Obsidian plugin command "Capture to inbox" builds:

  ```json
  {
    "id": "act-...",
    "ts": "2026-05-23T23:01:00Z",
    "source": "obsidian-plugin",
    "action": "capture_obsidian_text",
    "target": { "kind": "obsidian_note", "id": "inbox/captures.md" },
    "payload": { "vault_alias": "hermes", "heading": "Captures",
                 "text": "..." }
  }
  ```

  …and submits it via HTTP. DanOS Core writes to the vault file. The plugin
  does not own the file watcher; DanOS does.

## Failure modes and what to do about them

- **Envelope rejected (schema):** Core returns `400` (HTTP) or non-zero
  exit (CLI) with a JSON list of validation errors. Clients show the error
  inline; no audit row beyond the rejection.
- **Verb unknown:** Same as schema rejection, plus a hint pointing to the
  vocabulary list.
- **Effect failure (cmux/tmux/vault unavailable):** Core returns the
  partial result, marks the audit row `failed`, and surfaces the error to
  the client. Operator decides whether to retry.
- **Confirmation required but not provided:** Core returns `412 Precondition
  Required` (HTTP) / non-zero exit (CLI) with a one-line summary. Client
  prompts and re-submits with `requires_confirmation: false`.

## Non-goals

- The action bus is **not** a remote RPC system.
- It is **not** a process supervisor (launchd/systemd own daemons).
- It is **not** a secrets store (1Password owns secrets).
- It is **not** a queue with retries (Phase-6 file queue is optional and
  intentionally minimal).
