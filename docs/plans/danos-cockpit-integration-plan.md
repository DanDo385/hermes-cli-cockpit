# DanOS Cockpit integration plan

This plan turns the current `hermes-cli-cockpit` repository into a coherent
**DanOS Cockpit incubator** without renaming the repo or splitting it out
prematurely. It is staged so that each phase delivers a usable, reversible
slice.

Cross-references:

- Boundaries: [`docs/adr/0003-danos-cockpit-boundaries.md`](../adr/0003-danos-cockpit-boundaries.md)
- Action envelope: [`schemas/danos-action.schema.json`](../../schemas/danos-action.schema.json)
- Action bus design: [`docs/danos-action-bus.md`](../danos-action-bus.md)

## Guiding rules

- Keep the existing command taxonomy (`mission`, `mission-hermes`,
  `mission-openclaw`, `cmux`, `cctx`, `cockpit-workspaces`, `agent-worktree`,
  `danos`, `a2a-bridge`, `browser-smoke`, etc.) intact.
- Do not collapse Hermes and OpenClaw into one generic assistant pane.
- Preserve the six cockpit surfaces:
  1. DanOS Home / Cockpit Overview
  2. Hermes Tool / Hermes CLI Mission Control
  3. OpenClaw Tool / OpenClaw CLI Mission Control
  4. Coding Workbench
  5. Agent Deck
  6. Open Source Radar / Community
- Prefer shell + Python stdlib. Do not add external dependencies unless a
  phase explicitly justifies one.
- Public docs stay sanitized: no raw secrets, hostnames, account details, or
  logs (see ADR 0003).
- Each phase ships behind a dry-run-first posture and is independently
  reversible.

## Validation baseline

Run before starting any phase. Every phase must keep these green.

```bash
python3 -m json.tool .cmux/cmux.json
python3 -m json.tool schemas/danos-action.schema.json
python3 -m py_compile bin/danos bin/cockpit-workspaces bin/agent-worktree bin/a2a-bridge
tests/test_cockpit_workspaces_registry.sh
tests/test_danos_registry.sh
tests/test_danos_cmux_adapter.sh
tests/test_keystroke_mentor.sh
git diff --check
```

## Phase 0 — Repo safety, validation, current uncommitted work

**Goal:** lock in a baseline so later phases can claim "no behavior change."

### Files to create / modify

- (none — this phase only adds the docs/schema scaffolding for later phases,
  which is delivered in this same change set)

### Tests

- `tests/test_cockpit_workspaces_registry.sh`
- `tests/test_danos_registry.sh`
- `tests/test_danos_cmux_adapter.sh`
- `tests/test_keystroke_mentor.sh`
- `tests/test_danos_obsidian_loop.sh` (only if it exists)

### Validation commands

```bash
git status --short
git diff --check
python3 -m py_compile bin/danos bin/cockpit-workspaces bin/agent-worktree bin/a2a-bridge
python3 -m json.tool .cmux/cmux.json
python3 -m json.tool schemas/danos-action.schema.json
tests/test_cockpit_workspaces_registry.sh
tests/test_danos_registry.sh
tests/test_danos_cmux_adapter.sh
tests/test_keystroke_mentor.sh
[ -x tests/test_danos_obsidian_loop.sh ] && tests/test_danos_obsidian_loop.sh || true
```

### Rollback

- Phase 0 is read-only beyond docs and the schema file. Rollback is
  `git restore` on the docs/schema files.

### Acceptance criteria

- All listed tests pass.
- `git status --short` shows only intended doc/schema/CLI-stub additions.
- ADR 0003 and this plan exist and are committed (or staged) before Phase 1
  begins.

## Phase 1 — DanOS CLI / vault bridge

**Goal:** make `bin/danos` understand the DanOS action envelope and provide
a CLI/Markdown bridge between operator surfaces (cmux, Obsidian, CLI).

### Files to create / modify

- `bin/danos`
  - Add `actions` subcommand group:
    - `bin/danos actions validate <json-file>` — validate one envelope
      against `schemas/danos-action.schema.json` using stdlib only.
    - `bin/danos actions print-examples` — emit canonical examples.
    - `bin/danos actions schema` — print the schema file path / contents
      (optional but cheap).
  - Use the schema as the source of truth: load it from
    `schemas/danos-action.schema.json` at runtime.
- `schemas/danos-action.schema.json` (already added in this change set).
- `tests/test_danos_actions.sh` — verifies validate/print-examples and
  rejects malformed envelopes.

### Tests

- `tests/test_danos_actions.sh`
- Existing tests must continue to pass.

### Validation commands

```bash
python3 -m py_compile bin/danos
python3 -m json.tool schemas/danos-action.schema.json
bin/danos actions print-examples | python3 -m json.tool >/dev/null
bin/danos actions validate <(bin/danos actions print-examples) >/dev/null
tests/test_danos_actions.sh
tests/test_danos_registry.sh
tests/test_danos_cmux_adapter.sh
```

### Rollback

- Remove the `actions` subparser block in `bin/danos`.
- Delete `tests/test_danos_actions.sh`.
- The schema file can stay; it is data, not code.

### Acceptance criteria

- `bin/danos actions validate` accepts each canonical example and rejects
  envelopes missing `id`, `ts`, `source`, `action`, or `target`.
- `bin/danos actions print-examples` outputs valid JSON containing all six
  required example actions.
- No new third-party dependencies added.

## Phase 2 — cmux workspace -> Obsidian URI actions

**Goal:** make every cockpit workspace's Obsidian links go through DanOS as
an action, so cmux buttons and a future Obsidian plugin both speak the same
vocabulary.

### Files to create / modify

- `bin/danos`
  - Add `bin/danos obsidian open <vault-relative-path>` and
    `bin/danos obsidian capture <heading> --text "..."` commands.
  - Internally, both build a `danos-action` envelope (`open_obsidian_note`,
    `capture_obsidian_text`) and route through a single
    `route_action(envelope)` function. With `--dry-run` the envelope is
    printed; without it, the local effect is performed via
    `obsidian://` URIs (`open` action) or by appending to a vault-relative
    Markdown file (`capture` action).
- `.cmux/cmux.json`
  - Re-point `obsidian.notes` and any vault button to call
    `bin/danos obsidian open …` instead of attaching a tmux window. Keep the
    tmux window button as a separate `code.obsidian.tmux` action so the
    operator can still attach to the tmux notes pane.
- `config/cockpit-workspaces.toml`
  - Add explicit `obsidian_uri` fields for workspaces where they make sense.
- `docs/architecture.md`
  - Note that Obsidian opens are routed through DanOS actions.

### Tests

- Extend `tests/test_danos_cmux_adapter.sh` (or new
  `tests/test_danos_obsidian_uri.sh`) to assert dry-run output for
  `bin/danos obsidian open` matches the expected `obsidian://` URI shape.
- Test capture into a temp vault: confirm the file is created/appended and
  no other path is touched.

### Validation commands

```bash
python3 -m py_compile bin/danos
python3 -m json.tool .cmux/cmux.json
python3 -m json.tool schemas/danos-action.schema.json
bin/danos obsidian open 'projects/danos-cockpit/cli-mission-control-master-page.md' --dry-run
bin/danos obsidian capture 'Captures' --text 'phase-2 smoke' --vault hermes --dry-run
tests/test_danos_cmux_adapter.sh
tests/test_danos_registry.sh
```

### Rollback

- Revert `.cmux/cmux.json` to the previous `obsidian.notes` action.
- Remove `bin/danos obsidian` subparser block.
- Restore `config/cockpit-workspaces.toml`.

### Acceptance criteria

- All Obsidian opens from cmux pass through a DanOS action envelope.
- Dry-run prints the envelope JSON; live mode opens the URI / appends the
  capture file.
- The six cockpit workspaces remain present and unchanged in
  `bin/cockpit-workspaces verify`.

## Phase 3 — Local DanOS HTTP API / action bus

**Goal:** expose the same action vocabulary over a localhost HTTP endpoint
so non-shell clients (Obsidian plugin, web dashboard) can call DanOS without
shelling out.

### Files to create / modify

- `bin/danos`
  - Add `bin/danos serve --port 4180 --bind 127.0.0.1` using stdlib
    `http.server` only.
  - Endpoints (all read/append only by default):
    - `GET  /healthz`
    - `GET  /v1/workspaces`
    - `GET  /v1/tasks`
    - `GET  /v1/agents`
    - `POST /v1/actions` — accepts a single envelope; calls
      `route_action(envelope)`; returns the resolved plan, audit row id,
      and effect summary.
    - `GET  /v1/actions/examples`
- `config/danos-serve.example.toml`
  - Default loopback-only port, allowed sources, dry-run-default flag.
- `scripts/com.danos.serve.example.plist` — optional launchd template.
- `docs/danos-action-bus.md` (already added in this change set; updated to
  reference the live endpoint shape).
- `tests/test_danos_serve.sh` — boots the server on a random port, hits
  `/healthz` and `/v1/actions` with a dry-run envelope, asserts the
  response.

### Tests

- `tests/test_danos_serve.sh`

### Validation commands

```bash
python3 -m py_compile bin/danos
bin/danos serve --port 0 --bind 127.0.0.1 --probe   # one-shot health probe
tests/test_danos_serve.sh
```

### Rollback

- Remove `serve` subparser, `tests/test_danos_serve.sh`, and the launchd
  template. SQLite state is unaffected.

### Acceptance criteria

- Server binds 127.0.0.1 only by default; refuses non-loopback binds without
  an explicit `--allow-non-loopback` flag.
- Posting an envelope with `dry_run: true` does not mutate the SQLite store
  beyond the audit row that records the request.
- All six example envelopes from the schema validate and are routed.

## Phase 4 — Obsidian plugin skeleton

**Goal:** prove the Obsidian plugin can render DanOS state and call DanOS
actions through the HTTP bus, never owning any shell or daemon.

### Files to create / modify

- `obsidian-plugin/` (new directory)
  - `manifest.json`
  - `main.ts` (or `main.js` if we avoid the TS toolchain)
  - `README.md` — install path, settings, why it talks to DanOS Core.
  - Settings: DanOS base URL (default `http://127.0.0.1:4180`), default
    vault alias, dry-run-default toggle.
  - Commands: "DanOS: Show Home", "DanOS: Capture to inbox",
    "DanOS: Open Workspace…", "DanOS: Send selection to Hermes" — all
    issuing `POST /v1/actions` envelopes.
- `docs/danos-obsidian-plugin.md` — install / wire-up notes.
- `scripts/install-obsidian-plugin.sh` — symlink the plugin into a local
  vault for development. Operator-only.

### Tests

- Plugin code remains intentionally thin so most testing is manual. Add
  `tests/test_obsidian_plugin_manifest.sh` to validate the manifest JSON
  schema and that `main.js` exists.

### Validation commands

```bash
python3 -m json.tool obsidian-plugin/manifest.json
tests/test_obsidian_plugin_manifest.sh
```

### Rollback

- Remove the `obsidian-plugin/` directory and the install script.
- HTTP bus and CLI behavior are unaffected.

### Acceptance criteria

- Plugin loads in Obsidian and successfully calls `GET /healthz`.
- "Capture to inbox" issues a `capture_obsidian_text` envelope (visible in
  DanOS audit log).
- Plugin never spawns a child process or watches a file outside the vault.

## Phase 5 — Shared web dashboard

**Goal:** a minimal local web view that renders DanOS state and lets the
operator open workspaces / capture notes from any browser surface (cmux
browser pane, iPhone over Tailscale, etc.).

### Files to create / modify

- `web/danos/` (new directory)
  - `index.html`, `app.js`, `styles.css` — vanilla, no build tools.
  - Pages: Home, Workspaces, Tasks, Agents, Actions log.
  - Calls the HTTP bus from Phase 3 with `fetch`.
- `bin/danos serve` already serves static files from `web/danos/` when
  `--web-root web/danos` (default).
- `docs/danos-web-dashboard.md`

### Tests

- `tests/test_danos_web_smoke.sh` — boots the server, fetches `/`,
  validates that the HTML response references the expected page titles.

### Validation commands

```bash
python3 -m json.tool schemas/danos-action.schema.json
tests/test_danos_web_smoke.sh
bin/browser-smoke --directory web/danos --path / --expect 'DanOS'
```

### Rollback

- Remove `web/danos/` and the `--web-root` flag.

### Acceptance criteria

- `bin/danos serve` serves the dashboard at `http://127.0.0.1:4180/`.
- The dashboard makes only same-origin requests.
- Six cockpit surfaces are listed and clickable, each emitting a
  `open_cmux_workspace` envelope.

## Phase 6 — Packaging / repo split decision

**Goal:** decide whether to split DanOS Core into its own repository, or
keep incubating inside `hermes-cli-cockpit`.

### Files to create / modify

- `docs/adr/0004-danos-repo-split-decision.md` — capture the choice and
  the migration plan if we split.
- `Makefile` or `scripts/danos-package.sh` — package the CLI + schema +
  optional plugin/web assets into a tarball for distribution.
- If split: prepare a new repo layout under `danos-core/` inside this
  repo first, validate the move with `git filter-repo` dry-runs, then
  publish.

### Tests

- `tests/test_danos_package.sh` — produces a tarball, verifies its
  contents and that `bin/danos` runs from the extracted tree.

### Validation commands

```bash
tests/test_danos_package.sh
```

### Rollback

- Split is a one-way operation in practice; rollback is "do not push the
  new repo." If pushed, redirect with a deprecation notice and freeze.

### Acceptance criteria — split allowed only if all are true

- Phase 1–3 acceptance criteria are met and stable for ≥ 2 weeks.
- An external client of the action bus exists (Phase 4 plugin or Phase 5
  dashboard), so the contract is real.
- Hermes-specific surfaces (`mission-hermes`, Hermes-only cmux buttons) are
  cleanly identified and can stay in `hermes-cli-cockpit`.
- Operator agrees the move is worth the symlink/PATH churn.

## Implementation order delivered in this change set

This commit delivers **Phase 0 + the safe portion of Phase 1**:

- ADR 0003, this plan, action bus design doc, JSON schema, and a sanitized
  `actions validate` / `actions print-examples` CLI stub backed by the
  schema. No HTTP server, no plugin, no rename, no new GitHub repos.

The next recommended slice is the rest of Phase 2: routing the cmux
"Obsidian Notes" button through `bin/danos` so cmux and a future plugin
share the same vocabulary.
