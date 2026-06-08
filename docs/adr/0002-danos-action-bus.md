# ADR 0002: DanOS Action Bus

Status: accepted
Date: 2026-05-23

## Context

DanOS needs multiple surfaces to request the same operations:

- cmux buttons and workspace actions
- Obsidian plugin commands and views
- local web dashboards
- Hermes/OpenClaw assistant surfaces
- future coding-agent workflows
- shell users calling `bin/danos`

Without a shared action contract, each surface will grow bespoke shell glue. That path creates duplicated permissions, inconsistent dry-runs, and surprise side effects.

## Decision

DanOS will use an explicit local Action Bus.

DanOS Core owns:

- action envelope validation
- routing
- dry-run execution
- confirmation policy
- audit-friendly output
- adapter boundaries

Surfaces submit action requests. DanOS Core decides whether and how to execute them.

## Action envelope

The canonical action shape is defined in:

```text
schemas/danos-action.schema.json
```

Required fields:

- `id`
- `ts`
- `source`
- `action`
- `target`
- `payload`
- `dry_run`
- `requires_confirmation`

Example actions:

- `open_cmux_workspace`
- `open_obsidian_note`
- `capture_obsidian_text`
- `attach_tmux_session`
- `send_context_to_hermes`
- `close_day`

## Transport options

### CLI commands

Example:

```bash
bin/danos actions dry-run action.json
```

Pros:

- simple
- testable
- shell-native
- easy for cmux buttons
- works before a daemon exists

Cons:

- less interactive for live dashboards
- process startup overhead

Use first.

### Local HTTP API

Example:

```text
POST http://127.0.0.1:4180/api/actions/dry-run
```

Pros:

- good for Obsidian plugins and web dashboards
- shared by cmux browser panes
- live state refresh

Cons:

- port/auth/lifecycle concerns
- must bind loopback by default

Use after CLI and schema stabilize.

### File-backed JSONL queue

Example:

```text
~/.hermes/workspace/agent-hermes/runtime/danos-actions.jsonl
```

Pros:

- inspectable
- durable
- offline-friendly
- Obsidian-friendly

Cons:

- locking/deduplication required
- slower feedback loop

Use as optional fallback, not the primary first implementation.

## Implementation order

1. CLI + Markdown/vault loop
2. JSON schema/action envelope
3. dry-run action executor
4. local HTTP API on `127.0.0.1`
5. Obsidian plugin commands/views
6. optional file-backed queue

## Security policy

- Bind local services to `127.0.0.1` by default.
- Implement dry-run before live mutation.
- Never display or store raw secrets.
- Never post/send externally without explicit confirmation.
- Require confirmation for mutating actions unless the action is explicitly safe.
- Public docs and examples must be sanitized.

## Acceptance criteria

A slice that claims to implement the Action Bus must prove:

1. example actions validate against the schema
2. dry-run does not mutate cmux, tmux, Obsidian, files, or external services
3. `requires_confirmation` is honored for mutating actions
4. at least two surfaces can use the same action envelope
5. local HTTP binds loopback only, when introduced
6. the six cockpit workspace surfaces remain unchanged

## Rollback

Each implementation slice must be removable independently:

- schema/docs rollback: delete docs/schema files
- CLI rollback: remove `actions` command family
- HTTP rollback: disable server command and remove launch hooks
- plugin rollback: remove plugin directory or disable it in Obsidian

No slice should require rewriting the tmux runtime or cmux workspace registry to roll back.

## Consequences

Good:

- one contract across many UIs
- safer dry-run and confirmation behavior
- easier testing
- easier future plugin/web integration

Tradeoff:

- some upfront structure before shiny UI work

That is acceptable. Contracts first, dashboards second. The robot approves.

## See also

- `docs/adr/0001-danos-cockpit-boundaries.md`
- `docs/adr/0003-danos-obsidian-plugin-boundary.md`
- `docs/danos-action-bus.md`
- `schemas/danos-action.schema.json`
