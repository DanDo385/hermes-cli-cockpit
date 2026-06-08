# DanOS Cockpit integration plan

This plan turns Hermes CLI Cockpit into the DanOS Cockpit incubator without prematurely renaming the repo or splitting GitHub projects.

## Constraints

- Do not rename `hermes-cli-cockpit` yet.
- Do not create new GitHub repositories yet.
- Keep public docs sanitized.
- Preserve the six cockpit workspace surfaces.
- Keep Hermes and OpenClaw as peer surfaces.
- Obsidian is a memory/control/graph surface, not a process supervisor.
- tmux owns durable runtime sessions.
- cmux owns visual workspace orchestration.
- DanOS Core owns state, validation, and action routing.

## Phase 0: repo safety

Files:

- `README.md`
- `docs/architecture.md`
- `docs/adr/`
- `docs/plans/`
- `schemas/`

Tasks:

- inspect `git status --short --untracked-files=all`
- preserve uncommitted work
- avoid broad agent edits in one shared worktree
- use git worktrees for parallel agents

Validation:

```bash
git status --short --untracked-files=all
git diff --check
```

Acceptance:

- no accidental repo rename
- no accidental GitHub repo creation
- no overwritten uncommitted work

Rollback:

- restore docs/schema files from git or remove untracked files

## Phase 1: CLI + Obsidian vault loop

Files:

- `bin/danos`
- `tests/test_danos_obsidian_loop.sh`
- `README.md`

Commands:

```bash
bin/danos obsidian today
bin/danos obsidian capture 'Raw input'
bin/danos obsidian log 'Meaningful action completed'
bin/danos obsidian close-day --summary 'What changed'
bin/danos obsidian dashboard
```

Acceptance:

- default vault resolves to `~/.hermes/workspace`
- daily note, capture inbox, and dashboard note are generated
- tests pass without requiring native Obsidian app launch

Validation:

```bash
tests/test_danos_obsidian_loop.sh
python3 -m py_compile bin/danos
git diff --check
```

Rollback:

- revert `bin/danos` changes and remove the test

## Phase 2: schema and action envelope

Files:

- `schemas/danos-action.schema.json`
- `docs/danos-action-bus.md`
- `docs/adr/0002-danos-action-bus.md`

Acceptance:

- schema is valid JSON
- examples use dry-run by default
- actions include source, target, payload, dry-run, and confirmation fields

Validation:

```bash
python3 -m json.tool schemas/danos-action.schema.json >/dev/null
```

Rollback:

- delete the schema/doc files

## Phase 3: dry-run action executor

Files:

- `bin/danos`
- `tests/test_danos_actions.sh`

Future commands:

```bash
bin/danos actions examples
bin/danos actions validate action.json
bin/danos actions dry-run action.json
```

Acceptance:

- validates required fields with Python stdlib only
- dry-run never mutates files/apps/tmux/external services
- missing fields fail clearly
- `requires_confirmation` is displayed and honored

Validation:

```bash
tests/test_danos_actions.sh
python3 -m py_compile bin/danos
git diff --check
```

Rollback:

- remove the `actions` command family and test

## Phase 4: local HTTP API

Files:

- `bin/danos` or `bin/danos-server`
- `docs/danos-local-api.md`
- `tests/test_danos_local_api.sh`

Endpoints:

```text
GET  /health
GET  /api/state
GET  /api/actions/examples
POST /api/actions/dry-run
```

Acceptance:

- binds `127.0.0.1` by default
- no mutating endpoints in first slice
- tests start and stop the server cleanly

Validation:

```bash
tests/test_danos_local_api.sh
git diff --check
```

Rollback:

- remove server command and docs/test

## Phase 5: Obsidian plugin skeleton

Files:

- `packages/obsidian-plugin/manifest.json`
- `packages/obsidian-plugin/package.json`
- `packages/obsidian-plugin/tsconfig.json`
- `packages/obsidian-plugin/src/main.ts`
- `packages/obsidian-plugin/README.md`
- `docs/obsidian-plugin.md`

Commands:

- `danos:open-control-surface`
- `danos:capture-selection`
- `danos:send-selection-to-hermes`
- `danos:open-cmux-workspace`
- `danos:refresh-state`
- `danos:close-day`

Acceptance:

- builds locally
- does not install into live vault automatically
- emits dry-run action envelopes only
- starts no shell/tmux/gateway process

Validation:

```bash
cd packages/obsidian-plugin
npm install
npm run build
```

Rollback:

- remove `packages/obsidian-plugin/` and docs

## Phase 6: shared web dashboard

Files:

- `web/danos-dashboard/` or equivalent later path
- `docs/danos-dashboard.md`

Acceptance:

- reads state through DanOS API
- can be displayed in browser, cmux pane, or Obsidian Web Viewer
- no direct process supervision

Rollback:

- remove dashboard directory and route

## Phase 7: repo split decision

Do not split until:

- DanOS Core has stable CLI/API/schema contracts
- plugin has an independent build/release loop
- cmux adapter consumes published schemas
- tests pass on a fresh machine
- public docs are sanitized

Possible future repos:

- `danos-core`
- `danos-cockpit`
- `danos-obsidian`
- `danos-cmux`

## Global validation set

Run before any serious commit:

```bash
python3 -m py_compile bin/danos bin/cockpit-workspaces bin/agent-worktree bin/a2a-bridge
python3 -m json.tool .cmux/cmux.json >/dev/null
python3 -m json.tool schemas/danos-action.schema.json >/dev/null
tests/test_cockpit_workspaces_registry.sh
tests/test_danos_registry.sh
tests/test_danos_cmux_adapter.sh
tests/test_danos_obsidian_loop.sh
tests/test_keystroke_mentor.sh
git diff --check
```
