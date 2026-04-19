# Studio Plan — Flexible Lab + Agent Lifecycle

## Context

The current `/labs` couples agent creation to world creation: clicking **Create agent + world** always spawns a fresh `{agent, world}` pair. This means:

1. A user who `Instantiate`d an agent from the Builder (or spawned one another way) can't attach it to a world.
2. There is no concept of lifecycle (stop / archive / trash) for long-lived agents.
3. Future work — a custom World Builder — will need a flexible substrate that accepts **any agent** running against **any world**.

Goal: **add** a new `/studio` subsystem that complements `/labs`, keeping `/labs` unchanged for stability. `/studio` accepts existing agents, supports a full lifecycle, and is ready for the custom-world-builder work that comes later. Everything stays native Jido on the BEAM.

## Goals

1. Leave `/labs` alone. It is the stable current-state feature.
2. New `/studio` routes that:
   - Attach an existing running agent to any world.
   - Instantiate a new agent from a saved spec or cookbook recipe and run it.
   - Expose a live agent dashboard with start / stop / archive / trash / restore / empty-trash.
3. Formalise a `WorldPlane.WorldBehaviour` contract so the future custom-world builder has a target.
4. Preflight compatibility check: agent bundle dims (n_states, n_obs) must match world.
5. Persistent lifecycle state survives Phoenix restarts (Mnesia, matches existing state-storage pattern).
6. Honest state badges: every agent displays `live | stopped | archived | trashed`.

## Non-goals

- Custom world builder UI (deferred to a follow-up; this plan only lays the contract).
- Multi-tenant isolation (single local user for now).
- Undeletable system agents (admin-only; not in scope).

---

## Design

### D1. Agent lifecycle state machine

```
              ┌──────┐  archive    ┌─────────┐  restart  ┌──────┐
   start ───▶ │ live │ ──────────▶ │archived │ ─────────▶│ live │
              └──┬───┘             └────┬────┘           └──────┘
                 │ stop                  │ trash
                 ▼                       ▼
              ┌────────┐   trash   ┌─────────┐  restore  ┌────────┐
              │stopped │ ─────────▶│ trashed │ ─────────▶│stopped │
              └────┬───┘           └────┬────┘           └────────┘
                   │ trash                │ empty_trash
                   ▼                     ▼
                                       GONE (permanent)
```

States:

- **`:live`** — `Jido.AgentServer` process is running.
- **`:stopped`** — process is terminated; metadata preserved; can restart.
- **`:archived`** — stopped + hidden from default lists; appears under "Archive" tab.
- **`:trashed`** — stopped + soft-deleted; appears only in `/studio/trash`.

### D2. Persistence model

Extend `WorldModels.AgentRegistry` (already Mnesia-backed) with an `instances` table:

```elixir
%AgentPlane.Instance{
  agent_id:     "agent-builder-3bapBg",       # stable external id
  spec_id:      "example-l3-sophisticated-planner",
  source:       :builder | :studio | :labs | :cookbook,
  recipe_slug:  "sophisticated-plan-tree-search" | nil,
  pid:          #PID<0.123.0> | nil,           # nil when not :live
  state:        :live | :stopped | :archived | :trashed,
  started_at:   ~U[2026-04-19 17:30:00Z],
  updated_at:   ~U[2026-04-19 17:35:00Z],
  name:         "my-tree-search-run"           # user-editable display name
}
```

Persistence rule: every lifecycle transition writes to Mnesia synchronously. Process monitors handle `:live -> :stopped` on unexpected exit.

### D3. WorldBehaviour contract

Formalise the world-plane contract so the future custom-world builder has a target:

```elixir
defmodule WorldPlane.WorldBehaviour do
  @callback id() :: atom()
  @callback name() :: String.t()
  @callback blanket() :: SharedContracts.Blanket.t()
  @callback obs_dims() :: %{n_obs: pos_integer(), ...}
  @callback state_dims() :: %{n_states: pos_integer(), ...}
  @callback boot(keyword()) :: {:ok, pid()} | {:error, term()}
  @callback step(pid(), SharedContracts.ActionPacket.t()) ::
              {:ok, SharedContracts.ObservationPacket.t()} | {:error, term()}
  @callback terminal?(pid()) :: boolean()
  @callback reset(pid()) :: :ok
end
```

Existing `WorldPlane.Engine` gets a thin adapter that implements this. `WorldPlane.ContinuousWorlds` gets its own adapter. The custom world builder will implement the same behaviour.

### D4. Episode refactor (non-breaking)

`WorkbenchWeb.Episode` currently owns agent + world creation. Split into two entry points:

- **`Episode.start(spec_id, world_id, opts)`** — today's behaviour. `/labs` calls this. Unchanged.
- **`Episode.attach(agent_id, world_id, opts)`** — new. Accepts an already-running agent; compatible with `WorldBehaviour`. `/studio` calls this.

Both return `{:ok, session_id, pid}`. Internally, `attach/3` skips the agent boot and subscribes the existing agent's signal stream into the same episode loop.

Compatibility preflight:

```elixir
Episode.check_compatibility(agent_id, world_id) ::
  :ok
  | {:error, {:dims, %{agent: ..., world: ...}}}
  | {:error, {:blanket, :unsupported_channels, [atom()]}}
```

### D5. Routes

Namespaced so `/labs` is untouched:

| Route | LiveView | Purpose |
|---|---|---|
| `/studio` | `StudioLive.Index` | Dashboard: live agents, stopped, archived, trash count, "Start new run" |
| `/studio/new` | `StudioLive.New` | Three-flow picker: Attach existing · Instantiate from spec · Build from recipe |
| `/studio/run/:session_id` | `StudioLive.Run` | Live maze + beliefs + policy + "View in Glass" link |
| `/studio/agents/:agent_id` | `StudioLive.Agent` | Per-agent lifecycle panel (Stop / Archive / Trash / Rename / Runs history) |
| `/studio/trash` | `StudioLive.Trash` | Trashed agents · Restore · Permanent delete · Empty trash |
| `/guide/studio` | `GuideLive.Studio` | How-to page (part of the honest user guide) |

`/labs` **remains exactly as it is today**. No UI or behaviour change.

### D6. Cookbook integration

Cookbook recipe page gets a third run button:

| Button | Route | Agent behaviour |
|---|---|---|
| **Run in Builder** | `/builder/new?recipe=...` | Hydrates canvas with closest seeded spec; Save+Instantiate spawns a free agent (Glass only) |
| **Run in Labs** | `/labs?recipe=...&world=...` | Today's behaviour: fresh `{agent, world}` pair, unchanged |
| **Run in Studio** *(new)* | `/studio/new?recipe=...&world=...` | Instantiates a tracked agent in Mnesia, shows dashboard, user attaches to world explicitly |

All three remain valid; the choice is documented in `/guide/cookbook` and `/guide/studio`.

---

## Workstreams

### S — Studio subsystem (new; non-breaking)

| # | Ticket | DONE |
|---|---|---|
| **S1** | Formalise `WorldPlane.WorldBehaviour` (D3). Make `WorldPlane.Engine` + `WorldPlane.ContinuousWorlds` implement it via thin adapters. | Behaviour defined; both adapters pass dialyzer; 2 ExUnit tests (one per adapter). |
| **S2** | Add `AgentPlane.Instance` Mnesia table + `AgentPlane.Instances` module with `create/1`, `get/1`, `list/1` (filter by state), `transition/2`, `empty_trash/0`. | Module exists; lifecycle transitions persist and survive app restart; tests cover all 9 transitions + `empty_trash`. |
| **S3** | Refactor `WorkbenchWeb.Episode` — keep `start/3` unchanged; add `attach/3`; add `check_compatibility/2`. | `Episode.attach/3` boots an episode loop against an existing agent; `/labs` still compiles+tests pass; compatibility check rejects mismatched bundles. |
| **S4** | Extend `AgentPlane.Runtime` with `stop/1`, `archive/1`, `trash/1`, `restore/1`. Each writes to `AgentPlane.Instances` and terminates/revives the `Jido.AgentServer` as needed. | 4 new functions; each is idempotent; tests cover all transitions. |
| **S5** | Phoenix router: add `/studio/*` scope + `/guide/studio`. | Router compiles; all 6 routes return 200 on empty-state pages. |
| **S6** | `StudioLive.Index` — dashboard: cards for live / stopped / archived / trash counts, "Start new run" CTA, recent activity log. | Renders correctly in empty-state and after a few agents exist; ≤ 200-word body. |
| **S7** | `StudioLive.New` — 3-flow picker with world dropdown and compatibility preflight. | Preflight error surfaces cleanly; successful pick redirects to `/studio/run/:session_id`. |
| **S8** | `StudioLive.Run` — mirror `LabsLive.Run` UI (maze viz, belief bars, policy chart, Step/Run/Pause/Reset/Stop), but also exposes "Detach (keep agent live)" and "Stop agent" controls. | Attached agent steps through maze; stopping detaches without killing the agent; killing the agent transitions state to `:stopped` in Mnesia. |
| **S9** | `StudioLive.Agent` — per-agent detail page (name, source badge, source-recipe link, state badge, lifecycle buttons, "Open in Glass", past sessions list). | All lifecycle buttons work; Glass link opens the agent's Glass page. |
| **S10** | `StudioLive.Trash` — list trashed agents, Restore (to `:stopped`), Permanent delete (single), Empty trash (all). | Permanent delete removes from Mnesia; `:empty_trash` is confirm-guarded. |
| **S11** | `GuideLive.Studio` — how-to page under the guide, explaining the three flows + lifecycle model. | Page renders; linked from `/guide` landing. |
| **S12** | Cookbook recipe page: add **Run in Studio** button alongside existing two. | Button present on every `/cookbook/:slug` page; navigates to `/studio/new?recipe=...`. |
| **S13** | Builder post-Instantiate flash: "Agent <id> running. View in Studio →" link. | Flash renders after Save+Instantiate; link opens `/studio/agents/:agent_id`. |
| **S14** | ExUnit tests: lifecycle (9 transitions + empty_trash), attach+detach, compatibility-mismatch rejection, permanent-delete cleanup. | `mix test` passes with ≥ 8 new tests; coverage includes the happy path + 2 error paths. |
| **S15** | Update `RUN_LOCAL.md` + `CLAUDE.md` with the new routes and the Studio vs. Labs guidance. | Both files carry a "Studio vs. Labs" subsection. |

### Backwards-compat test matrix

Every release must pass:

- [x] `/labs` UI unchanged: snapshot test of the existing LabsLive.Run render.
- [x] `/labs?recipe=...&world=...` still works end-to-end.
- [x] Existing 5 example specs still render in `/labs` spec picker.
- [x] `/builder/new?recipe=...` still hydrates the canvas.
- [x] No regression in `/glass/*` routes.
- [x] `mix cookbook.validate` still reports "50 recipes, 0 errors".

---

## Critical files

**New**

- `active_inference/apps/world_plane/lib/world_plane/world_behaviour.ex`
- `active_inference/apps/agent_plane/lib/agent_plane/instance.ex`
- `active_inference/apps/agent_plane/lib/agent_plane/instances.ex`
- `active_inference/apps/workbench_web/lib/workbench_web/live/studio_live/{index,new,run,agent,trash}.ex`
- `active_inference/apps/workbench_web/lib/workbench_web/live/guide_live/studio.ex`
- `active_inference/apps/agent_plane/test/instances_test.exs`
- `active_inference/apps/workbench_web/test/live/studio_live_test.exs`

**Edited (minimal)**

- `active_inference/apps/world_plane/lib/world_plane/engine.ex` (implement `WorldBehaviour`)
- `active_inference/apps/world_plane/lib/world_plane/continuous_worlds.ex` (implement `WorldBehaviour`)
- `active_inference/apps/workbench_web/lib/workbench_web/episode.ex` (add `attach/3` + `check_compatibility/2`)
- `active_inference/apps/agent_plane/lib/agent_plane/runtime.ex` (add lifecycle fns)
- `active_inference/apps/workbench_web/lib/workbench_web/router.ex` (add `/studio/*` scope)
- `active_inference/apps/workbench_web/lib/workbench_web/live/guide_live/index.ex` (link to `/guide/studio`)
- `active_inference/apps/workbench_web/lib/workbench_web/live/cookbook_live/show.ex` (add Run in Studio button)
- `active_inference/apps/workbench_web/lib/workbench_web/live/builder_live/compose.ex` (post-Instantiate flash)
- `RUN_LOCAL.md`, `CLAUDE.md`, `ARCHITECTURE.md` (describe Studio vs. Labs)

**Untouched (explicit non-regression)**

- `active_inference/apps/workbench_web/lib/workbench_web/live/labs_live/run.ex`
- `active_inference/apps/workbench_web/lib/workbench_web/episode.ex` existing `start/3` behaviour
- Every cookbook JSON file

---

## Verification — end-to-end walkthrough

After all tickets merge:

1. **Cookbook** → Open `/cookbook/sophisticated-plan-tree-search`.
2. Click **Run in Studio** → lands on `/studio/new?recipe=sophisticated-plan-tree-search`.
3. Pick world `deceptive_dead_end` → preflight passes → click **Start** → redirects to `/studio/run/:session_id`.
4. Episode runs: maze renders, agent steps, policy chart updates, trajectory overlay appears.
5. Click **Detach** → agent stays `:live` but leaves the episode. Episode closes.
6. Navigate to `/studio/agents/:agent_id` → state is `:live`, past session is in the history list.
7. Click **Stop** → state `:stopped`; process gone.
8. Click **Restart** → state `:live` again with a fresh process (same spec, fresh beliefs).
9. Click **Archive** → state `:archived`; hidden from `/studio` default; visible under "Archived" tab.
10. From archive, click **Trash** → state `:trashed`; visible only in `/studio/trash`.
11. `/studio/trash` → click **Restore** → state back to `:stopped`.
12. Re-trash → `/studio/trash` → **Empty trash** (confirm) → agent permanently removed from Mnesia.
13. Verify `/labs` unchanged: open it, pick example-l1, create agent+world, run → same behaviour as before this plan.

## Risks & mitigations

| Risk | Mitigation |
|---|---|
| Mnesia schema change breaks existing agents. | New `Instance` table is additive; no existing table is modified. |
| `Episode.attach/3` introduces coordination bugs. | Comprehensive tests (S14) + keep `start/3` path untouched for the stable flow. |
| Agent + world compatibility mismatch crashes the episode. | Preflight `check_compatibility/2` refuses to attach; surfaces a friendly error in `StudioLive.New`. |
| Empty-trash deletes something the user wanted. | Confirm dialog + 10-second "Undo" toast that cancels the delete. |
| Future custom-world builder incompatible with `WorldBehaviour`. | The behaviour is a narrow contract (4 callbacks) covering current needs + declared extension points (`obs_dims`, `state_dims`) — future worlds must implement these to plug in. |
| Process leaks from orphaned `:live` entries after Phoenix restart. | On app boot, reconcile Mnesia against live `Jido.AgentServer.list_all/0` — any `:live` entry without a matching pid transitions to `:stopped`. |

## Execution order

1. S1 + S2 (contracts + data model) — parallel, independent.
2. S3 + S4 (Episode + Runtime lifecycle) — sequential after S1, S2.
3. S5 (routes).
4. S6-S10 (Studio LiveViews) — parallelisable.
5. S11, S12, S13 (cookbook + builder + guide integrations).
6. S14 (tests) — runs alongside each LiveView ticket.
7. S15 (docs) — last.
8. Final walkthrough + acceptance matrix.

Keeps `/labs` stable, makes `/studio` flexible, and stages the runway for the future custom-world builder.
