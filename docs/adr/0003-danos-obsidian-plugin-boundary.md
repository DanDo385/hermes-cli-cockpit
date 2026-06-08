# ADR 0003: DanOS Obsidian plugin boundary and cmux control model

- Status: Proposed (skeleton not yet implemented)
- Date: 2026-05-23
- Owners: DanOS Cockpit operator + maintainers
- Scope: Obsidian as a DanOS surface; cmux as a separate visual client that
  controls Obsidian externally, not by hosting plugins.

## Context

DanOS Cockpit is the local operator/control layer that connects cmux, tmux,
launchd/systemd, Obsidian, and the agent fleet. Obsidian is the operator's
memory/graph surface. There has been understandable temptation to either
(a) drive Obsidian from cmux as if cmux were an Obsidian host, or
(b) push long-running orchestration responsibilities into an Obsidian
plugin.

Both directions are wrong, for different reasons:

- cmux is a **terminal and visual surface**, not an Obsidian extension host.
  It does not load `.obsidian/plugins/...` and does not embed Electron's
  Obsidian renderer.
- Obsidian plugins live inside the Obsidian process. They restart when
  Obsidian reloads, they share a single event loop with the rest of
  Obsidian, and they have no durable supervision story. They are good UI;
  they are bad daemons.

This ADR fixes the boundary so that cmux, the future Obsidian plugin, and
DanOS Core each stay in their lane.

## How Obsidian plugins fit into DanOS

Obsidian is a **client surface** of DanOS, peer to cmux, the future web
dashboard, and `bin/danos`. The Obsidian plugin's role is:

1. Render DanOS state inside Obsidian (workspace cards, agent slots, today's
   tasks, action history) so the operator does not have to leave the vault
   to see the cockpit.
2. Capture text and selections from notes into DanOS as structured
   actions.
3. Submit DanOS action envelopes (see `schemas/danos-action.schema.json`)
   to DanOS Core via the action bus
   (see `docs/danos-action-bus.md`).
4. Open canonical notes (project, daily, dashboard) on demand, including
   notes whose locations are computed by DanOS rather than memorized by
   the operator.

Obsidian plugins are **stateless renderers + envelope senders**. Anything
durable lives behind DanOS Core (and ultimately launchd/systemd).

## cmux does not run Obsidian plugins directly

State for the record:

- **cmux does not host, load, install, build, or sandbox Obsidian plugins.**
- A DanOS Obsidian plugin runs inside the Obsidian application, on the
  same machine, in Obsidian's renderer process. It is invisible to cmux.
- cmux must not bundle plugin assets, must not write to a vault's
  `.obsidian/plugins/` directory as part of normal operation, and must not
  attempt to drive a plugin's command palette in-process.

When a cmux button "opens an Obsidian view," what it actually does is
ask the Obsidian application — externally — to do something.

## How cmux can control Obsidian externally

cmux is allowed to influence Obsidian only through these external,
loosely-coupled mechanisms:

- **`obsidian://` URI links.** Open a vault, a note, a search, or a plugin
  command from a shell or browser. Example shapes (sanitized):
  - `obsidian://open?vault=<vault-alias>`
  - `obsidian://open?vault=<vault-alias>&file=<vault-relative-path>`
  - `obsidian://advanced-uri?vault=<vault-alias>&commandid=<plugin-command-id>`
  cmux invokes these via `open` (macOS) / `xdg-open` (Linux). DanOS Core is
  the canonical builder of these URIs so cmux and the plugin agree on
  shape.
- **Official Obsidian CLI commands.** Where the local Obsidian binary
  exposes a CLI surface (e.g. opening a vault, reloading workspace),
  cmux/DanOS may invoke it. cmux must not invent CLI flags Obsidian does
  not document; if functionality is missing, fall back to URI links or to
  the plugin.
- **Loading Obsidian workspaces.** Obsidian workspace `.json` definitions
  are owned by the operator's vault. cmux/DanOS may request a workspace
  switch via the URI/command surface (e.g. an Advanced URI command id), but
  must not edit the workspace files directly except through explicit
  operator-initiated DanOS actions.
- **Opening localhost dashboard URLs.** When DanOS Core serves a local
  dashboard (HTTP, loopback only — see `docs/danos-action-bus.md`), cmux
  may open `http://127.0.0.1:<port>/...` in a browser pane. This is the
  preferred way to surface DanOS read views inside cmux without coupling
  cmux to Obsidian.

That list is exhaustive. cmux does not get any other control channel into
Obsidian.

## What a DanOS Obsidian plugin can do

A DanOS plugin running inside Obsidian may:

- **Create custom views** in Obsidian's right-side / left-side panes (a
  "DanOS Control Surface" view, "DanOS Agents" view, "DanOS Today" view).
- **Register Obsidian commands** that show in the command palette and can
  be hot-keyed by the operator.
- **Render DanOS state** — workspaces, tasks, agents, recent action log —
  by querying DanOS Core (CLI shell-out for the Phase 1 bridge, HTTP once
  the action bus is up).
- **Capture selected text** from the active note into a DanOS action (e.g.
  `capture_obsidian_text`) so the operator can grab a paragraph and route
  it into the inbox without leaving the vault.
- **Send action requests to DanOS Core** as DanOS action envelopes
  conforming to `schemas/danos-action.schema.json`. Verbs include
  `open_cmux_workspace`, `open_obsidian_note`, `capture_obsidian_text`,
  `attach_tmux_session`, `send_context_to_hermes`, `close_day`.
- **Open project / daily / dashboard notes** by asking DanOS Core for the
  current canonical path and then opening it in Obsidian. This decouples
  the plugin from path conventions.

Everything above is read-mostly + envelope-out. The plugin owns no durable
state.

## What the plugin must not do

The plugin is forbidden from:

- **Owning long-running shell processes.** No persistent `child_process`,
  no shells held open across plugin reloads. Short-lived shell-outs are
  acceptable only as a transport for DanOS action submission, and only
  with a hard timeout.
- **Supervising tmux sessions.** Attaching, creating, restarting, or
  watching tmux sessions is DanOS Core's job (and ultimately the
  operator's terminal). The plugin may *request* `attach_tmux_session`
  via an envelope; it does not run `tmux` itself.
- **Running gateways.** No HTTP servers, no Hermes/OpenClaw gateway
  processes, no agent runners. launchd/systemd own gateway lifecycle.
- **Storing raw secrets.** No API keys, tokens, or 1Password item values
  in plugin settings, plugin localStorage, plugin notes, or sync metadata.
  The plugin may store references (vault aliases, workspace ids, 1Password
  item ids), never raw values.
- **Mutating external services without confirmation.** Any envelope that
  would post to GitHub, Discord, Hermes, OpenClaw, or any other external
  surface must be sent with `requires_confirmation: true` (or explicitly
  marked as `dry_run: true`). The plugin must never bypass DanOS Core's
  confirmation policy.

If the plugin needs to do anything else durable, the answer is "add a verb
to DanOS Core" — not "do it inside the plugin."

## Recommended plugin commands

The plugin should expose these commands in Obsidian's command palette
(stable ids — operator-visible). Each maps to one or more DanOS action
envelopes:

| Command id | Purpose | Action verbs (envelope) |
| --- | --- | --- |
| `danos:open-control-surface` | Open / focus the DanOS Control Surface view | (UI only; no envelope) |
| `danos:capture-selection` | Capture the current selection into the DanOS inbox note | `capture_obsidian_text` |
| `danos:send-selection-to-hermes` | Send the current selection as context to Hermes mission control | `send_context_to_hermes` (with `requires_confirmation: true`) |
| `danos:open-cmux-workspace` | Pick a cockpit workspace and open it via cmux | `open_cmux_workspace` |
| `danos:refresh-state` | Re-fetch workspaces / tasks / agents from DanOS Core | (read-only; no envelope) |
| `danos:close-day` | Run the daily close routine through DanOS Core | `close_day` (with `requires_confirmation: true`) |

All command ids use the `danos:` namespace so they are obvious in the
palette and easy to bind to hotkeys.

## Recommended plugin directory (later)

When the plugin skeleton is built, it should live at:

```
packages/obsidian-plugin/
  manifest.json
  main.ts            (or main.js — TS optional, no required toolchain)
  styles.css
  README.md          (install path, settings, why it talks to DanOS Core)
  src/
    danosClient.ts   (envelope builder + transport: CLI now, HTTP later)
    views/
      controlSurface.ts
      agents.ts
      today.ts
    commands/
      capture.ts
      sendToHermes.ts
      openWorkspace.ts
      closeDay.ts
```

Rationale:

- `packages/` reserves room for additional in-repo packages
  (`packages/web-dashboard/`, `packages/danos-core/`) without forcing a
  monorepo tool yet.
- The plugin is intentionally not at the repo root; it is one client among
  several.
- A repo split (see ADR 0003 boundaries / future split-decision ADR) can
  later promote `packages/obsidian-plugin/` to its own repo with no
  internal restructuring.

## Future view design — DanOS Control Surface

The first non-trivial view rendered by the plugin is the **DanOS Control
Surface**. It is a single Obsidian leaf with five panels and a row of
action buttons:

```
+-------------------------------------------------------------+
| DanOS Control Surface                       [refresh] [...] |
+-------------------------------------------------------------+
| Workspaces                                                  |
|   1. DanOS Home / Cockpit Overview            [open]        |
|   2. Hermes Mission Control                   [open]        |
|   3. OpenClaw Mission Control                 [open]        |
|   4. Coding Workbench                         [open]        |
|   5. Agent Deck                               [open]        |
|   6. Open Source Radar / Community            [open]        |
+-------------------------------------------------------------+
| Agents                                                      |
|   <tool> <id>            <status>      task=<id>            |
|   ...                                                       |
+-------------------------------------------------------------+
| Tasks                                                       |
|   <id>  <state>  p<priority>  <title>                       |
|   ...                                                       |
+-------------------------------------------------------------+
| Daily priorities                                            |
|   - capture from inbox                                      |
|   - PR war room (read-only review)                          |
|   - end-of-day close                                        |
+-------------------------------------------------------------+
| Action buttons                                              |
|   [Capture selection]  [Send selection to Hermes]           |
|   [Open cmux workspace]  [Refresh]  [Close day]             |
+-------------------------------------------------------------+
```

Behavior rules for the view:

- All data comes from DanOS Core. The view never invents state.
- All buttons emit envelopes. None of them shell out directly.
- Mutating buttons surface a confirmation modal whenever the resolved
  envelope has `requires_confirmation: true`.
- Six workspace surfaces are always shown — the view never collapses
  Hermes and OpenClaw into one row, never hides Agent Deck or OSS Radar.
- Empty / unavailable data renders as "unsupported / not configured"
  rather than disappearing.

## Acceptance criteria for a later plugin skeleton

When the plugin skeleton is implemented (Phase 4 of the integration plan),
it must satisfy all of the following:

1. The plugin loads in Obsidian with `manifest.json` only — no required
   third-party toolchain (no forced TypeScript build, no esbuild, no
   webpack). A pure `main.js` is acceptable for the skeleton.
2. The plugin successfully calls DanOS Core (CLI bridge or
   `GET http://127.0.0.1:<port>/healthz`) and renders a non-empty list of
   workspaces.
3. `danos:open-control-surface` opens the Control Surface view.
4. `danos:capture-selection` produces a `capture_obsidian_text` envelope
   that DanOS Core accepts and audits; the captured text appears in the
   configured inbox note.
5. `danos:send-selection-to-hermes` produces a `send_context_to_hermes`
   envelope with `requires_confirmation: true` and surfaces a confirm
   modal in Obsidian before submission.
6. `danos:open-cmux-workspace` produces an `open_cmux_workspace` envelope;
   in dry-run mode the plugin shows the resolved plan instead of invoking
   anything.
7. `danos:refresh-state` is read-only and never mutates DanOS state.
8. `danos:close-day` produces a `close_day` envelope with
   `requires_confirmation: true` and `dry_run: true` until the operator
   explicitly opts out of dry-run for that command.
9. The plugin spawns no long-running child processes and starts no HTTP
   listeners.
10. Plugin settings store no raw secrets — only references (vault alias,
    DanOS base URL, default workspace id).
11. Tests: `python3 -m json.tool packages/obsidian-plugin/manifest.json`
    passes; a manifest schema check exists; manual smoke checklist is
    documented in `packages/obsidian-plugin/README.md`.

If any of these fail, the plugin skeleton is not accepted — fix or revert
before merging.

## Rollback notes

This ADR is documentation only and adds no executable surface. Rollback
options, in order of preference:

1. **Revert the doc.** `git restore` (or `git rm` if committed) on
   `docs/adr/0003-danos-obsidian-plugin-boundary.md`. Nothing else has to
   change because no code references this file.
2. **Supersede.** If the boundary is later refined (e.g. plugins are
   allowed to host a tiny supervised worker for offline capture), write a
   new ADR that explicitly supersedes this one and update its `Status:`
   header to `Superseded by ADR NNNN`. Do not silently edit the rules.
3. **If a plugin skeleton has already landed under
   `packages/obsidian-plugin/`** when this ADR is reverted: keep the
   skeleton in place but stop merging features that depend on the
   constraints in this ADR. The skeleton itself does not violate any
   safety property; only the long-term contract changes.

No code, schema, or test changes are introduced by this ADR. cmux,
`bin/danos`, the action schema, and the existing test suite are unaffected.
