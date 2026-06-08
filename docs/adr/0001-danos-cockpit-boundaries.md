# ADR 0001: DanOS Cockpit boundaries

Status: accepted
Date: 2026-05-23

## Context

Hermes CLI Cockpit is becoming the incubator for DanOS Cockpit: a local operating layer that connects cmux, tmux, Obsidian, Hermes/OpenClaw, coding agents, tasks, projects, and dashboards.

The danger is architectural blur. If every surface starts owning processes, state, notes, and side effects, the cockpit becomes a haunted mega-app. Fascinating. Bad.

## Decision

Keep DanOS as a set of explicit layers with clear ownership.

```text
cmux       visual desktop client and workspace switcher

tmux       durable terminal/session/process runtime

launchd    durable gateway/service owner on macOS

DanOS Core state, registry, action validation, and routing

Obsidian   memory, graph, daily loop, control surface

Hermes     AI assistant/runtime surface

OpenClaw   peer AI assistant/runtime surface where configured
```

DanOS Core owns state and action routing. cmux, Obsidian plugins, local dashboards, and agent surfaces request actions through DanOS Core instead of directly supervising every other layer.

## Boundaries

### cmux

cmux is the local visual cockpit. It may open windows, URLs, terminal surfaces, Obsidian URIs, and workspace layouts. It does not own durable state and should not become the system database.

### tmux

tmux owns long-lived shell/process sessions. It is the durable runtime spine for Hermes, OpenClaw, coding workbenches, agent decks, test loops, and scratch terminals.

### launchd/systemd

Service managers own durable gateways and daemons. cmux and Obsidian may show controls or health, but they should not pretend to be service supervisors.

### DanOS Core

DanOS Core owns:

- workspace/project/task/agent registry
- local action envelope validation
- dry-run behavior
- confirmation rules
- routing to cmux, tmux, Obsidian, Hermes/OpenClaw, or future adapters
- sanitized state views for public docs/demos

### Obsidian

Obsidian owns memory and context:

- daily notes
- capture inbox
- project notes
- backlinks/graph/canvas/bases
- dashboards rendered from local state
- operator review loops

Obsidian does not own long-running processes.

### Obsidian plugins

Obsidian plugins may render DanOS state and request DanOS actions. They must not directly supervise tmux sessions, gateways, or coding agents.

### Hermes and OpenClaw

Hermes and OpenClaw remain peer assistant/runtime surfaces. Do not collapse them into one generic assistant pane. If OpenClaw lacks a Hermes-equivalent capability, the cockpit should show `unsupported/not configured` rather than delete the surface.

## Workspace surfaces preserved

DanOS Cockpit preserves these top-level surfaces:

1. DanOS Home / Cockpit Overview
2. Hermes Tool / Hermes CLI Mission Control
3. OpenClaw Tool / OpenClaw CLI Mission Control
4. Coding Workbench
5. Agent Deck
6. Open Source Radar / Community

## Repository decision

Do not rename `hermes-cli-cockpit` yet. It remains the incubator while interfaces are changing.

A future rename or split is justified only when:

- DanOS Core has stable CLI/API/schema contracts
- the Obsidian plugin has its own build/release loop
- cmux adapters can consume published schemas
- public docs are sanitized
- setup works on a fresh machine without Dan-private paths

Likely future repos:

- `danos-core`
- `danos-cockpit`
- `danos-obsidian`
- `danos-cmux`
- `hermes-tmux-workspaces`

## Security rules

- No raw secrets in docs, panes, logs, schemas, or generated examples.
- Public docs must not include private hostnames, account details, raw logs, or credentials.
- Mutating actions require confirmation unless explicitly safe.
- External posting/sending must never happen as a surprise side effect.
- Dry-run behavior comes before live execution.

## Consequences

Good:

- surfaces can evolve independently
- Obsidian becomes a powerful cockpit without becoming a fragile process owner
- cmux stays a visual shell
- tmux remains durable
- DanOS gains a stable action layer

Tradeoff:

- more explicit contracts up front
- slightly slower than wiring every button directly to shell commands

That tradeoff is worth it. Direct wiring is fast until the first invisible side effect bites.

## See also

- `docs/adr/0002-danos-action-bus.md`
- `docs/adr/0003-danos-obsidian-plugin-boundary.md`
- `docs/danos-action-bus.md`
- `docs/plans/danos-cockpit-integration-plan.md`
