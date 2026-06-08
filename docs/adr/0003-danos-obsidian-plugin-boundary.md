# ADR 0003: DanOS Obsidian plugin boundary

Status: accepted
Date: 2026-05-23

## Context

Obsidian can become a rich DanOS cockpit surface through custom views, commands, workspace layouts, Web Viewer panes, note metadata, backlinks, and graph context.

But Obsidian should not become the process supervisor. It is an Electron app with plugins. It is excellent for control, memory, and context. It is not the durable runtime spine.

## Decision

A DanOS Obsidian plugin may render state and request actions through DanOS Core. It must not own long-running shell processes, tmux sessions, gateways, or external side effects.

cmux does not run Obsidian plugins directly. cmux controls Obsidian externally.

## cmux control paths

cmux may control Obsidian through:

- `obsidian://` URI links
- official Obsidian CLI commands, when available
- loading saved Obsidian workspaces
- opening localhost dashboard URLs in Obsidian Web Viewer or browser panes
- DanOS action requests that route to Obsidian adapters

Example URI:

```bash
open 'obsidian://open?vault=hermes&file=agent-hermes/notes/danos-dashboard'
```

Example future command:

```bash
obsidian command id=danos:open-control-surface
```

## Plugin responsibilities

The DanOS Obsidian plugin may:

- create custom views
- register commands
- render DanOS state
- capture selected text
- send action requests to DanOS Core
- open project, daily, dashboard, and inbox notes
- display dry-run results
- show current workspace, agents, tasks, and daily priorities

The plugin must not:

- own long-running shell processes
- supervise tmux sessions
- run gateways
- store raw secrets
- mutate external services without confirmation
- bypass DanOS Core for mutating actions

## Recommended plugin commands

- `danos:open-control-surface`
- `danos:capture-selection`
- `danos:send-selection-to-hermes`
- `danos:open-cmux-workspace`
- `danos:refresh-state`
- `danos:close-day`

## Recommended plugin directory

Initial monorepo/incubator path:

```text
packages/obsidian-plugin/
```

Future split candidate:

```text
danos-obsidian
```

Split only after the schema/API stabilizes and the plugin has an independent build/release loop.

## DanOS Control Surface view

A future view should show:

- current cmux workspace
- linked Obsidian project/daily note
- active tmux sessions
- active agents
- task inbox
- daily priorities
- recent DanOS events
- dry-run action buttons

Buttons should create DanOS action envelopes first. Live mutation comes later.

## Selection/context bridge

One high-value command is `danos:send-selection-to-hermes`.

It should package:

- vault name
- note path
- heading
- selected text
- tags/properties
- relevant backlinks when safe
- target workspace/project metadata

Then it should request a DanOS action such as `send_context_to_hermes`.

Hermes receives context through DanOS/tmux routing, not through the plugin directly owning a Hermes process.

## Acceptance criteria for plugin skeleton

A first plugin skeleton is acceptable when:

1. it builds locally without touching the live vault automatically
2. it registers the recommended commands
3. it creates a DanOS Control Surface view
4. its buttons emit dry-run action envelopes only
5. it does not start shells, tmux, gateways, or external posts
6. it documents install/uninstall steps
7. it references `schemas/danos-action.schema.json`

## Rollback

Rollback should be simple:

- disable the plugin in Obsidian
- remove `packages/obsidian-plugin/`
- keep DanOS CLI/schema/docs intact

No rollback should require changing tmux runtime sessions or cmux registry files.

## Consequences

Good:

- Obsidian becomes a powerful cockpit and memory surface
- cmux can still orchestrate Obsidian from outside
- DanOS Core remains the safe execution boundary
- the plugin is testable and removable

Tradeoff:

- actions travel through one more layer

That layer is the safety rail. Worth it.

## See also

- `docs/adr/0001-danos-cockpit-boundaries.md`
- `docs/adr/0002-danos-action-bus.md`
- `docs/danos-action-bus.md`
- `schemas/danos-action.schema.json`
