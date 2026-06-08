# DanOS Action Bus

The DanOS Action Bus is the local contract that lets cmux, tmux, Obsidian, Hermes/OpenClaw, dashboards, and future plugins request the same actions without each surface inventing its own unsafe shell glue.

## Why this exists

DanOS needs multiple control surfaces:

- cmux buttons and workspace layouts
- Obsidian notes, commands, and future plugin views
- local web dashboards
- Hermes/OpenClaw assistant surfaces
- terminal users calling `bin/danos`

Without a bus, each surface would directly call scripts, open apps, write files, or send text to terminals. That is fast but fragile. The bus creates one boring contract for validation, dry-run, confirmation, and routing.

Boring is good here. Boring prevents surprise side effects.

## Ownership model

```text
surface -> action envelope -> DanOS Core -> adapter -> target
```

Surfaces:

- cmux
- Obsidian plugin
- local dashboard
- CLI user
- Hermes/OpenClaw

DanOS Core:

- validates action shape
- decides dry-run vs live
- enforces confirmation policy
- routes to adapters
- emits readable output

Adapters:

- cmux adapter
- tmux adapter
- Obsidian adapter
- Hermes/OpenClaw adapter
- future HTTP/file queue adapters

Targets:

- workspace
- note
- tmux session
- agent
- dashboard
- task

## Action envelope

See:

```text
schemas/danos-action.schema.json
```

Minimal example:

```json
{
  "id": "act_20260523_example",
  "ts": "2026-05-23T15:00:00Z",
  "source": "cmux",
  "action": "open_obsidian_note",
  "target": "obsidian",
  "payload": {
    "vault": "hermes",
    "file": "agent-hermes/notes/danos-dashboard.md"
  },
  "dry_run": true,
  "requires_confirmation": false
}
```

## Supported initial actions

- `open_cmux_workspace`
- `open_obsidian_note`
- `capture_obsidian_text`
- `attach_tmux_session`
- `send_context_to_hermes`
- `close_day`

## Transport options

### 1. CLI first

Use CLI commands before a daemon exists.

Future examples:

```bash
bin/danos actions examples
bin/danos actions validate action.json
bin/danos actions dry-run action.json
```

This is the first implementation target because it is easy to test and works from cmux buttons.

### 2. Local HTTP second

Later:

```text
GET  http://127.0.0.1:4180/health
GET  http://127.0.0.1:4180/api/state
POST http://127.0.0.1:4180/api/actions/dry-run
```

HTTP is useful for Obsidian plugins and browser dashboards. It must bind to `127.0.0.1` by default.

### 3. File-backed JSONL optional

Possible queue:

```text
~/.hermes/workspace/agent-hermes/runtime/danos-actions.jsonl
```

This is useful for auditability and offline operation, but it needs locking and deduplication. Treat it as optional until the CLI and HTTP paths are stable.

## Security model

Rules:

- dry-run before live execution
- loopback default for local HTTP
- no raw secrets
- no surprise external posting/sending
- confirmation required for mutating actions unless explicitly safe
- public docs/examples sanitized

Potentially mutating actions include:

- sending text to Hermes/OpenClaw/tmux sessions
- writing Obsidian notes
- opening/launching apps
- posting to external services
- changing task/project state

## Dry-run behavior

Dry-run must show:

- parsed action id
- source
- target
- action name
- intended adapter
- intended command/effect
- whether confirmation would be required

Dry-run must not:

- mutate files
- send text to tmux
- open apps
- post externally
- change database rows
- launch services

## cmux usage

cmux should request actions rather than own DanOS state.

Examples:

- open DanOS Home workspace
- open matching Obsidian note
- attach a tmux session
- open a local dashboard URL

## Obsidian plugin usage

The plugin should emit action envelopes when a user clicks a button or invokes a command.

Examples:

- capture selected text
- send selected note context to Hermes
- open cmux workspace for current project
- close the day

The plugin should not supervise tmux sessions or gateways.

## Implementation sequence

1. Keep the existing CLI/Markdown vault loop.
2. Add this schema and action examples.
3. Add `bin/danos actions validate` and `bin/danos actions dry-run`.
4. Add local HTTP dry-run endpoints.
5. Add Obsidian plugin skeleton with dry-run-only buttons.
6. Add live mutating actions one at a time with tests and confirmation rules.

## Related ADRs

- `docs/adr/0001-danos-cockpit-boundaries.md`
- `docs/adr/0002-danos-action-bus.md`
- `docs/adr/0003-danos-obsidian-plugin-boundary.md`
