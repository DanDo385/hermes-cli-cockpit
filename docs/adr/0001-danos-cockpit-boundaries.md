# ADR 0003: DanOS Cockpit boundaries

- Status: Accepted (incubating inside `hermes-cli-cockpit`)
- Date: 2026-05-23
- Owners: DanOS Cockpit operator + maintainers

## Context

This repository started as **Hermes CLI Cockpit** — a terminal-native operator
cockpit for AI-assisted development. The shape it has grown into is broader
than that name implies:

- A local SQLite registry (`bin/danos`) for projects, tasks, agents, workspaces
  and events.
- A read-only six-workspace card deck (`bin/cockpit-workspaces`).
- An iMac native cmux bootstrap (`bin/imac-cmux-bootstrap`) plus `.cmux/cmux.json`
  actions.
- Adapter commands that reach into native cmux on behalf of the operator
  (`bin/danos cmux …`, `bin/danos pr war-room …`).
- Workspace surfaces for Hermes, OpenClaw, a coding workbench, an agent deck,
  and an open-source radar — i.e. surfaces that are not purely Hermes.

The scope is now **the operator's local control plane** — what the operator
calls **DanOS Cockpit**: state, action routing, and stable interfaces between
cmux (visual), tmux (durable runtime), launchd/systemd (services),
Obsidian (memory/graph), and the agent fleet.

## Decision

We will treat this repository as the **DanOS Cockpit incubator**:

1. DanOS Core owns durable local state, action routing, and stable interfaces.
2. cmux is the **local visual client**.
3. tmux is the **durable remote/runtime process layer**.
4. **launchd/systemd** own durable gateways and daemons.
5. **Obsidian** is the visual/control/memory/graph surface — not the process
   owner. Any Obsidian plugin must request actions through DanOS instead of
   directly supervising long-running processes.
6. **Hermes CLI Cockpit** remains the historic name and the surface most
   visible to the operator today, but it is now one of several surfaces
   coordinated by DanOS.

We are **not** renaming the repo in this iteration. We are **not** creating
new GitHub repositories. We are establishing boundaries and a migration path.

## Why DanOS is broader than Hermes CLI Cockpit

- Hermes is one peer assistant/runtime surface. **OpenClaw** is its peer.
  Collapsing them into a single "agent" pane would erase a real product
  separation and is explicitly forbidden.
- Workbench, Agent Deck, and OSS Radar are operator surfaces that exist
  whether or not Hermes is the active assistant.
- Local **state** (tasks, agents, workspaces, events) is owned by DanOS, not
  by any single assistant. Hermes is a tenant of DanOS, not its parent.
- Future surfaces (web dashboard, Obsidian plugin, calendar/journal, daily
  close) are DanOS surfaces.

In short: Hermes is a tool; DanOS is the cockpit those tools live inside.

## Why the repo is not renamed yet

- A rename forces every operator script, symlink, GitHub remote, Obsidian
  link, and CI step to be updated in lockstep. We do not yet have a clean
  cut-over plan.
- Several public docs reference `hermes-cli-cockpit` already; renaming
  prematurely would break links and confuse onlookers.
- DanOS surfaces (HTTP action bus, Obsidian plugin, web dashboard) are not
  yet implemented. A repo split decision should follow the implementation,
  not lead it.
- Until DanOS has its own minimal surface (HTTP action bus + at least one
  external client beyond `bin/danos`), keeping it inside this repo lets us
  iterate on boundaries quickly.

## Ownership boundaries

```
+-----------------+   +----------------------+   +-------------------+
| cmux            |   | Obsidian plugin      |   | Web dashboard     |
| (visual client) |   | (memory/graph UI)    |   | (read-mostly)     |
+--------+--------+   +-----------+----------+   +---------+---------+
         |                        |                        |
         |  DanOS Action Envelope (CLI / file / HTTP)      |
         v                        v                        v
              +-------------------------------------+
              |  DanOS Core                         |
              |  - SQLite registry                  |
              |  - action router / vocabulary       |
              |  - audit log                        |
              |  - dry-run + confirm policy         |
              +-------------------------------------+
                |            |             |
                v            v             v
           tmux runtime   launchd       agent fleet
           (durable)      (services)    (cmux/Obs/cli)
```

| Layer | Owns | Does NOT own |
| --- | --- | --- |
| cmux | local windowing, visual surfaces, browser panes, hotkeys | durable state, secrets, gateway lifecycle |
| tmux | durable terminal sessions, runtime panes, agent shells | windowing decisions, secret values |
| launchd / systemd | gateway and daemon lifecycle, log files | tmux session shape, action routing |
| Obsidian | notes, graph, captures, dashboards, plugin UI | starting/stopping long-running processes |
| Obsidian plugins | calling DanOS actions, rendering local state | spawning shells, holding secrets, owning ports |
| DanOS Core | local state, vocabulary, action routing, audit | rendering UI, owning a process supervisor |
| Hermes / OpenClaw CLIs | their own model/session/tool surfaces | each other's surfaces, DanOS state |

## Why Obsidian plugin surfaces should call DanOS instead of owning shells

- Plugins should be **stateless renderers + action requesters**. Anything
  durable (timers, watchers, gateways) belongs in launchd/systemd and is
  exposed to plugins through DanOS Core.
- Obsidian processes restart whenever the app reloads. Long-running shells
  hosted inside a plugin are fragile and can leak processes.
- A plugin running a shell directly bypasses DanOS audit, dry-run, and
  confirmation. That undermines the operator's safety posture.
- A plugin that calls DanOS instead gets:
  - A controlled vocabulary (`open_obsidian_note`, `attach_tmux_session`,
    `capture_obsidian_text`, etc.).
  - Free dry-run/confirmation handling.
  - A free audit trail in the DanOS event log.
  - Forward-compat with cmux, web dashboard, and CLI surfaces.

The action envelope (see `schemas/danos-action.schema.json`) is the contract.

## Future repo split criteria

We will split DanOS out of this repo only when **all** of the following hold:

1. `bin/danos` has a stable action vocabulary (post-Phase 3 of the integration
   plan) — vocabulary changes are no longer weekly.
2. There is at least one external client beyond `bin/danos` itself (HTTP
   client, Obsidian plugin, web dashboard) consuming the same envelope.
3. The action bus has a passing dry-run validator and a CI smoke test.
4. We can clearly state what stays in `hermes-cli-cockpit` (Hermes-specific
   tmux helpers, `mission-hermes` UX) versus what goes into a `danos-core`
   repo (registry, action router, schema, web/Obsidian glue).
5. Operator's day-to-day muscle memory is unblocked by the move (no
   regressions in the six workspace surfaces).

When those hold, candidate split:

- `danos-core` — registry, action schema, HTTP/CLI bus, web dashboard.
- `danos-obsidian-plugin` — Obsidian plugin that calls `danos-core`.
- `hermes-cli-cockpit` — Hermes-specific cockpit surfaces and `mission-hermes`.
- `hermes-tmux-workspaces` — already split: durable MBP runtime tmux pages.

Until then, prefer to grow inside this repo behind the DanOS namespace.

## Security rule (applies to all DanOS docs)

**Public docs in this repository must never contain raw secrets, hostnames,
account names, machine identifiers, IP addresses, file paths under operator
home directories, or raw operational logs.**

Specifically:

- No `mbp-runtime`, `imac-cockpit`, or any other private SSH alias in public
  docs. Use `mbp-runtime-host` or `<operator-host>` placeholders.
- No `/Users/<name>/...` paths in public docs. Use `$HOME/...` or
  `<vault-root>` placeholders.
- No raw 1Password item ids, vault contents, or session tokens.
- No raw stack traces or daemon logs.
- Examples in `schemas/` MUST use sanitized identifiers
  (`mission-hermes`, `cockpit-workbench`, `journal/YYYY-MM-DD.md`).

The operator's actual cmux config (`.cmux/cmux.json`) and TOML registry
already reference some hostnames and `$HOME` paths. Those files predate this
ADR and represent local operator configuration; new public docs and schemas
introduced after this ADR follow the rule above. Existing files will be
sanitized opportunistically as they are touched, not in a single sweep.

## Consequences

- All new operator-facing local control flows are designed as DanOS actions
  first, with cmux/Obsidian/CLI as transports.
- Obsidian plugin work is deferred until the action bus exists.
- The `bin/danos` CLI stays the canonical entry point during the incubation
  phase; everything else (HTTP, plugin, dashboard) speaks to it through the
  action envelope.
- A repo split becomes a paperwork exercise once the integration plan's
  Phase 6 acceptance criteria are met — not before.
