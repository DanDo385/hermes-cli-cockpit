# ADR 0002 — DanOS Action Bus: boundary and implementation strategy

- Status: Proposed
- Date: 2026-05-23
- Owners: DanOS Cockpit incubator
- Supersedes: none
- Related: [`docs/adr/0001-danos-cockpit-boundaries.md`](0001-danos-cockpit-boundaries.md)

> Companion files referenced by this ADR may be written by other agents or
> later changes: the action envelope at `schemas/danos-action.schema.json`,
> the phased rollout in `docs/plans/danos-cockpit-integration-plan.md`, and
> any expanded action-bus design doc under `docs/`. This ADR establishes the
> decision and the contract; those companions implement it.

## Context

ADR 0001 established that the cockpit is being incubated into **DanOS Cockpit**
shape, with explicit ownership boundaries between cmux (visual client), tmux
(durable runtime), launchd/systemd (services), Obsidian (memory and control
surface), and **DanOS Core** (local state and action routing).

The cockpit today has many surfaces that all want to perform "a local thing":

- Native cmux buttons defined in `.cmux/cmux.json`.
- Mission tmux sessions (`mission-hermes`, `mission-openclaw`,
  `cockpit-workbench`, `cockpit-community`, agent-deck).
- The existing `bin/danos` CLI and its `cmux …` adapter family.
- Hermes and OpenClaw CLI mission controls.
- A future Obsidian plugin and a future loopback web dashboard.
- Agent worktrees that occasionally need to nudge the visual surface.

Without an explicit, named contract for "how do these surfaces tell DanOS Core
to do something", each surface invents its own pattern. That leaks raw shell
commands into config files, defeats dry-run, fragments the audit trail, and
makes it impossible to swap surfaces later (for example, replacing a cmux
button with an Obsidian plugin command) without rewriting glue code.

This ADR records the decision to introduce a single named contract — the
**DanOS Action Bus** — and the implementation strategy for landing it
without disrupting existing flows.

## Decision

DanOS will expose **one local action bus**, with one envelope shape, that all
operator surfaces use to request local effects. The contract has the
following properties:

1. **DanOS Core owns action validation and routing.** No surface executes a
   DanOS action directly; surfaces build an action envelope and submit it to
   Core. Core validates against `schemas/danos-action.schema.json`, applies
   policy (dry-run, confirmation, source-trust), routes to the matching
   handler, and records the result in the audit log.
2. **cmux is a visual client, not the state owner.** cmux buttons produce
   envelopes (today: by calling `bin/danos …`; future: by writing to a file
   queue or POSTing to the HTTP bus). cmux never holds durable state,
   secrets, or process supervision responsibilities.
3. **tmux owns durable process/session runtime.** Long-running terminal
   workspaces, scrollback, agent shells, and gateway-adjacent panes live in
   tmux. The action bus can ask tmux to attach a session or send keys; it
   does not replace tmux as the session store.
4. **Obsidian and Obsidian plugins are control and memory surfaces, not
   process supervisors.** Plugins render notes, capture text, surface state
   pulled from Core, and **submit envelopes**. They must not spawn or
   supervise daemons; per ADR 0001, anything durable belongs in
   launchd/systemd, owned by Core's policy.
5. **Hermes and OpenClaw CLIs are peer assistants.** They receive context
   *through* the bus (`send_context_to_hermes`); they do not co-own DanOS
   state or each other's mission surfaces.
6. **The bus is local by construction.** It is a single-operator, local
   cockpit. Networked transports are out of scope; remote access goes
   through SSH/Tailscale tunnels, not a public bind.

The envelope shape is normative and defined in
`schemas/danos-action.schema.json` (separate file, separate owner). This ADR
does not redefine the envelope; it records *that* there is one and *why*.

## Why DanOS needs an explicit action bus

An explicit bus solves five concrete failure modes that occur when each
surface improvises its own shellouts:

- **Crash blast radius.** An Obsidian plugin that owns a shell takes the
  shell down when Obsidian reloads. A bus owned by Core decouples surface
  lifetime from effect lifetime.
- **Inconsistent dry-run.** `bin/danos pr war-room` already defaults to
  dry-run; cmux buttons that shell out directly do not. The operator cannot
  reason about safety unless every surface goes through the same gate.
- **Audit gaps.** Today only `bin/danos` records events. cmux button
  presses, tmux key bindings, and ad-hoc plugin shellouts vanish. The bus
  gives every action an envelope id, a timestamp, a declared source, and a
  recorded effect.
- **Vocabulary drift.** Each surface invents its own verbs ("open notes",
  "openNotes", "obsidian-open"). With a bus, the controlled vocabulary
  is one snake-case set shared across every surface.
- **Secret leakage.** The bus is the one chokepoint where secret-handling
  policy lives. Surfaces never see raw secrets; envelopes carry references
  (vault paths, 1Password item ids) which Core resolves at execution time
  and never logs.

The bus is the durable interface DanOS Core exposes. Surfaces are
replaceable; the bus is the contract.

## Transport options

The same envelope flows over three transports. Each has trade-offs.

### 1. CLI commands

A surface invokes `bin/danos` (or a sibling) with the envelope as an
argument, stdin, or a file path.

- **Pros:** No new daemon. No new port to defend. Trivial to inspect
  (`cat envelope.json | bin/danos actions validate -`). Works inside
  Markdown code blocks. Composes with `cmux`/`tmux` key bindings that
  already shell out.
- **Cons:** Process startup cost per envelope. Awkward for in-process
  plugin contexts (Obsidian, browser dashboard). Requires the surface to
  shell out.
- **Use when:** the operator is at a terminal, a cmux button needs an
  effect, or an automation already pipes JSON.

### 2. Local HTTP API on 127.0.0.1

DanOS exposes a small JSON-over-HTTP endpoint bound to loopback only.

- **Pros:** In-process clients (Obsidian plugin, web dashboard) call it
  with one `fetch`. No process spawn per envelope. Natural place for a
  read-mostly listing API (`GET /v1/workspaces`, `GET /v1/tasks`).
- **Cons:** Adds a daemon. Adds a port to defend. Requires a supervised
  process (`launchd`/`systemd`).
- **Use when:** a non-shell surface (plugin, dashboard) needs to request
  actions, or when polling read endpoints is useful.

### 3. File-backed JSONL queue

DanOS Core watches a vault-relative `actions/` directory (or a similar
operator-owned path) and drains envelopes from it.

- **Pros:** Works from contexts where neither shelling out nor HTTP is
  convenient (a templated Obsidian snippet, a journal automation). Naturally
  durable — the file is the evidence.
- **Cons:** Adds a watcher to defend. Race conditions if multiple writers
  drop envelopes simultaneously. Latency depends on poll interval / inotify.
- **Use when:** an offline or template-driven workflow needs to enqueue an
  envelope without an active DanOS process to call.

## Recommended implementation order

The bus must be landed without breaking existing flows. Each step must keep
prior validation green (see `docs/plans/danos-cockpit-integration-plan.md`
Phase 0 baseline).

1. **CLI + Markdown/vault loop.**
   - Operator pastes/edits envelopes in Markdown or stdin and runs
     `bin/danos` to validate and route them.
   - No daemons, no ports, no plugins. Provides immediate audit/dry-run.
2. **JSON schema / action envelope.**
   - The envelope shape is pinned in `schemas/danos-action.schema.json`.
     Validation is a separate concern from execution.
   - Adding a verb means adding it to the schema vocabulary and to Core's
     router — never to a surface's ad-hoc shellout.
3. **Dry-run action executor.**
   - Core routes envelopes to handlers. Every mutating handler must respect
     `dry_run: true` (returning a resolved plan, recording a dry-run audit
     row, performing no side effect) and `requires_confirmation: true`
     (prompting the operator on CLI / overlay / modal before proceeding).
4. **Local HTTP API.**
   - `bin/danos serve` (or sibling) on `127.0.0.1` exposes the same handler
     set via JSON-over-HTTP. Read endpoints first; `POST /v1/actions` last.
   - Non-loopback binds require an explicit operator flag and are documented
     as advanced.
5. **Obsidian plugin commands/views.**
   - Plugin opens via the HTTP bus only; never spawns a child process,
     never holds raw secrets, never watches paths outside the vault.
   - Commands map 1:1 to action verbs ("DanOS: Open Workspace…",
     "DanOS: Capture to inbox", "DanOS: Send selection to Hermes").

The file-backed JSONL queue is optional and last. It should land only if a
real workflow needs it — for example, a journal template that drops envelopes
without an active DanOS process.

## Security rules

These apply to every transport, every surface, and every envelope.

- **Loopback only by default.** The HTTP bus binds `127.0.0.1` only. A
  non-loopback bind requires an explicit operator flag (and remains out of
  scope for the default install). The CLI and file queue never expose a
  port.
- **Dry-run first.** New verbs ship with `dry_run: true` as the operator
  default until smoke-tested. Surfaces SHOULD expose a visible "Preview"
  toggle for any mutating verb, with execute off by default.
- **No raw secrets.** Envelopes never carry secret values. They carry
  references (vault paths, 1Password item ids, `op://` URIs). Core resolves
  references at handler time and MUST NOT log the resolved values. Public
  docs and example envelopes follow ADR 0001's sanitization rule.
- **No surprise external posting.** Verbs that would post to GitHub,
  Discord, or any external system are draft-first by default and require an
  explicit operator-initiated execute step. The bus never auto-publishes
  on a schedule without an explicit, named, audited verb.
- **Mutating actions require confirmation unless explicitly safe.** A verb's
  schema entry declares whether it is "explicitly safe" (read-only, idempotent
  open, local notification) or "mutating" (writes a file, attaches a session,
  sends keys, posts externally). Mutating verbs default
  `requires_confirmation: true`. CLI confirms on stdin; HTTP returns `409
  Conflict` (or equivalent) until a follow-up envelope with the same `id`
  and a `confirmed: true` payload arrives; Obsidian shows a modal.
- **Declared source.** Every envelope's `source` field is required and
  enumerated. Core applies per-source trust (for example, an
  `obsidian-plugin` source may be allowed to capture text but disallowed
  from sending keys to a tmux session).
- **Audit log is the floor, not the ceiling.** Every accepted envelope
  produces a row in the DanOS event store with envelope id, source, action,
  target, effect summary, and dry-run flag. Rejected envelopes are also
  recorded with the rejection reason.

## Example action names

The initial DanOS action vocabulary includes (snake_case verbs, mapped to
explicit handlers in Core):

- `open_cmux_workspace` — focus a named cockpit workspace inside native
  cmux. Read-mostly; safe by default.
- `open_obsidian_note` — open a vault-relative note via `obsidian://`. Safe
  by default.
- `capture_obsidian_text` — append text under a heading in a vault-relative
  Markdown file. Mutating; defaults to `requires_confirmation: false` once
  the vault and heading are validated, but the operator can re-enable
  per-capture confirmation.
- `attach_tmux_session` — attach to a named tmux session (optionally select
  a window first). Mutating only insofar as it changes pane focus; defaults
  to safe but logs every attach.
- `send_context_to_hermes` — drop a structured context blob into the Hermes
  mission session (e.g. via a tmux send-keys or a notes write). Mutating;
  defaults to `requires_confirmation: true`.
- `close_day` — perform end-of-day rollup (snapshot workspaces, archive
  completed tasks, write the daily note). Mutating; defaults to
  `requires_confirmation: true` and `dry_run: true` until the operator has
  smoke-tested it.

The vocabulary grows by adding verbs to the schema and a matching handler in
Core. Surfaces never introduce verbs unilaterally.

## Acceptance criteria for the future implementation

The action bus is considered "landed" when **all** of the following hold:

1. The envelope schema validates and rejects malformed inputs, with at least
   one CLI entry point that exercises validation (e.g.
   `bin/danos actions validate <file>` or an equivalent already provided
   by another agent's change).
2. Each verb in the vocabulary above has a handler in Core that respects
   `dry_run` and `requires_confirmation`, and an audit row appears in the
   DanOS event store for every accepted and rejected envelope.
3. At least two surfaces submit envelopes through Core in normal operator
   use — for example, a cmux button and a CLI workflow, or a cmux button
   and an Obsidian plugin command.
4. The HTTP bus binds `127.0.0.1` by default; a non-loopback bind requires
   an explicit flag; the bus survives a launchd/systemd restart cycle.
5. Public docs (this ADR, the action-bus design doc, the integration plan)
   contain no raw secrets, hostnames, account names, IPs, `/Users/<name>/`
   paths, or raw logs (per ADR 0001).
6. The six cockpit workspaces remain present and unchanged in
   `bin/cockpit-workspaces verify`. The existing command taxonomy
   (`mission`, `mission-hermes`, `mission-openclaw`, `cmux`, `cctx`,
   `cockpit-workspaces`, `agent-worktree`, `danos`, `a2a-bridge`,
   `browser-smoke`) is intact.

## Rollback notes

The bus is designed to land in independently reversible slices. If a slice
regresses operator flow, roll back **only that slice** rather than the
entire effort.

- **CLI (slice 1) rollback.** Remove the offending `bin/danos` subcommand
  block. The schema file can stay; it is data, not code. Operators can
  fall back to existing `bin/danos cmux …` adapter commands.
- **Schema (slice 2) rollback.** The schema file is additive. If a
  vocabulary entry is wrong, revert that entry; the envelope shape itself
  rarely needs to roll back.
- **Dry-run executor (slice 3) rollback.** If a handler misbehaves, mark
  the verb `requires_confirmation: true` in the schema and disable its
  router entry. The envelope path still validates; only the side effect
  pauses.
- **HTTP bus (slice 4) rollback.** Stop the launchd/systemd unit and
  remove its `bin/danos serve` invocation. The CLI path remains usable.
  No SQLite changes are required.
- **Obsidian plugin (slice 5) rollback.** Disable the plugin in the vault.
  The HTTP bus, CLI, and file-queue paths are unaffected. The plugin owns
  no durable state.
- **File queue (optional, last) rollback.** Stop the watcher and delete
  the queue directory. Any pending envelopes are inert files until
  re-enqueued.

The bus must never put the operator in a position where rolling back one
slice forces a broader rollback. If a slice cannot be rolled back
independently, it has been scoped wrong and must be re-sliced.

## Consequences

- DanOS Core becomes the single source of truth for "what just happened in
  the cockpit". Every surface gets a free audit trail and free dry-run
  semantics by adopting the bus.
- Surfaces (cmux config, Obsidian plugin, web dashboard, agent fleet) become
  thinner. They construct envelopes and render results; they do not perform
  effects themselves.
- Adding a new operator capability is a 1-line schema entry plus a Core
  handler, not a per-surface refactor.
- The cost is the discipline: surfaces that historically shelled out
  directly must migrate to envelope submission. This is acceptable because
  shelling out directly already violates ADR 0001 boundaries.

## See also

- [`docs/adr/0001-danos-cockpit-boundaries.md`](0001-danos-cockpit-boundaries.md) — ownership boundaries.
- `schemas/danos-action.schema.json` — normative envelope shape and vocabulary.
- `docs/plans/danos-cockpit-integration-plan.md` — phased rollout.
- `docs/architecture.md` — existing cockpit machine-role split.
- `README.md` — current command taxonomy and six workspace surfaces.
