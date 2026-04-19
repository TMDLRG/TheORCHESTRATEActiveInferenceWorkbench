# apps/world_models/ — ReadmeAI

## Purpose

The **unified event store, spec registry, and Phoenix.PubSub bus**. Every cross-plane event flows through `Bus` → `EventLog` (Mnesia-durable). Every composition spec is content-addressed via BLAKE2b and stored in Mnesia. Live agent registry maps `agent_id → pid` in RAM.

## Contents

| Path | Role |
|---|---|
| [`lib/world_models/application.ex`](lib/world_models/application.ex) | OTP Application (PubSub + EventLog.Janitor + Seeds task) |
| [`lib/world_models/bus.ex`](lib/world_models/bus.ex) | Phoenix.PubSub facade (topics: `events:global`, `events:agent:<id>`, `events:world:<id>`, `events:spec:<id>`) |
| [`lib/world_models/event.ex`](lib/world_models/event.ex) | Versioned event envelope with provenance |
| [`lib/world_models/event_log.ex`](lib/world_models/event_log.ex) | Mnesia append-only log |
| [`lib/world_models/event_log/`](lib/world_models/event_log/) | Setup + Janitor — [subtree README](lib/world_models/event_log/ReadmeAI.MD) |
| [`lib/world_models/agent_registry.ex`](lib/world_models/agent_registry.ex) | Live agent map + spec registration |
| [`lib/world_models/spec.ex`](lib/world_models/spec.ex) | Content-addressed spec (BLAKE2b) |
| [`lib/world_models/spec/`](lib/world_models/spec/) | Topology + BlockSchema — [subtree README](lib/world_models/spec/ReadmeAI.MD) |
| [`lib/world_models/archetypes.ex`](lib/world_models/archetypes.ex) | Canvas templates (POMDP maze, etc.) |
| [`lib/world_models/seeds/`](lib/world_models/seeds/) | Boot-time seeding — [subtree README](lib/world_models/seeds/ReadmeAI.MD) |
| [`test/`](test/) | Event log + registry + bus tests — [`test/ReadmeAI.MD`](test/ReadmeAI.MD) |

## Public API surface

| Module | Function | Arity | Purpose |
|---|---|---|---|
| `WorldModels.Bus` | `subscribe_global/0` | 0 | Subscribe to `events:global` topic |
| `WorldModels.Bus` | `subscribe_agent/1` | 1 | Subscribe to `events:agent:<id>` |
| `WorldModels.Bus` | `subscribe_world/1` | 1 | Subscribe to `events:world:<id>` |
| `WorldModels.Bus` | `subscribe_spec/1` | 1 | Subscribe to `events:spec:<id>` |
| `WorldModels.Bus` | `broadcast/1` | 1 | Publish an `Event.t` to all matching topics |
| `WorldModels.Bus` | `running?/0` | 0 | Check PubSub alive |
| `WorldModels.Event` | `new/1` | 1 | Construct envelope; auto-generates `:id` + `:ts_usec` |
| `WorldModels.EventLog` | `append/1` | 1 | Mnesia transaction append |
| `WorldModels.EventLog` | `query/1` | 1 | Filter by agent_id, type, time window |
| `WorldModels.EventLog` | `snapshot_at/2` | 2 | Time-scrub replay |
| `WorldModels.AgentRegistry` | `register_spec/1` | 1 | Persist `Spec.t` to `:world_models_specs` |
| `WorldModels.AgentRegistry` | `fetch_spec/1` | 1 | Load by `:id` |
| `WorldModels.AgentRegistry` | `register_live/3` | 3 | `agent_id + spec_id + pid` → `:world_models_live_agents` |
| `WorldModels.AgentRegistry` | `fetch_live/1` | 1 | `agent_id → {spec_id, pid, started_at}` |
| `WorldModels.AgentRegistry` | `live_for_spec/1` | 1 | `spec_id → [agent_id]` |
| `WorldModels.Spec` | `new/1` | 1 | Build struct + compute content hash |
| `WorldModels.Spec` | `canonical_form/1` | 1 | Deterministic byte sequence |
| `WorldModels.Spec` | `provenance_hash/1` | 1 | BLAKE2b over canonical form |
| `WorldModels.Archetypes` | `all/0` | 0 | All canvas archetypes |
| `WorldModels.Archetypes` | `fetch/1` | 1 | By `:id` |
| `WorldModels.Archetypes` | `enabled/0` | 0 | Subset with `disabled?: false` |
| `WorldModels.Archetypes` | `seed_topology/1` | 1 | Canvas scaffold for a given archetype |
| `WorldModels.EventLog.Setup` | `ensure_schema!/0` | 0 | Create Mnesia schema + tables if missing |
| `WorldModels.EventLog.Setup` | `table/0` \| `attributes/0` \| `specs_table/0` \| `live_agents_table/0` | 0 | Schema constants |

## Data types & schemas

| Type | File:Line | Fields |
|---|---|---|
| `Event.t/0` | [event.ex:36](lib/world_models/event.ex) | `:id :: String.t`, `:ts :: DateTime.t`, `:ts_usec :: integer`, `:version :: integer`, `:type :: String.t`, `:provenance :: provenance`, `:data :: map` |
| `Event.provenance/0` | [event.ex:25](lib/world_models/event.ex) | `:agent_id`, `:spec_id`, `:bundle_id`, `:family_id`, `:world_run_id`, `:equation_id`, `:trace_id`, `:span_id` (all optional) |
| `Spec.t/0` | [spec.ex:31](lib/world_models/spec.ex) | `:id`, `:archetype_id`, `:family_id`, `:primary_equation_ids`, `:bundle_params`, `:blanket`, `:hash`, `:created_at`, `:created_by`, `:version`, `:topology` |
| `Archetypes.t/0` | [archetypes.ex:28](lib/world_models/archetypes.ex) | `:id`, `:name`, `:description`, `:family_id`, `:primary_equation_ids`, `:mvp_suitability`, `:disabled?`, `:required_types`, `:default_params` |

### Mnesia tables

| Table | Type | Copies | Key | Indices | Purpose |
|---|---|---|---|---|---|
| `:world_models_events` | `ordered_set` | `disc_copies` | `{ts_usec, id}` | `:agent_id`, `:type` | Append-only event log |
| `:world_models_specs` | `set` | `disc_copies` | `:id` | `:archetype_id`, `:family_id`, `:hash` | Spec persistence |
| `:world_models_live_agents` | `set` | `ram_copies` | `:agent_id` | `:spec_id` | Live-agent map (ephemeral) |

All defined in [`lib/world_models/event_log/setup.ex`](lib/world_models/event_log/setup.ex).

## Constants & config keys

| Key | Default | Set in |
|---|---|---|
| `:world_models, :auto_start_event_log` | `true` (dev/prod); `false` (test — [`../../config/test.exs:11`](../../config/test.exs)) | `Application.get_env/3` |
| `:mnesia, :dir` | dev `~c"priv/mnesia/dev"`; prod `~c"priv/mnesia/prod"` | [`../../config/dev.exs:14`](../../config/dev.exs), [`../../config/prod.exs:7`](../../config/prod.exs) |

## Telemetry / signals / events emitted here

None emitted directly. This app is a *sink* for events (via `Bus.broadcast/1`) and a publisher to Phoenix.PubSub topics. `EventLog.append/1` persists every broadcast.

## Dependencies

- **Inbound**: every umbrella app.
- **Outbound (Hex)**: `:phoenix_pubsub ~> 2.1`.
- **Outbound (OTP)**: `:mnesia` (extra_applications).

## Verification status

- `:verified` — event log tests cover append / query / snapshot (see [`test/event_log_test.exs`](test/event_log_test.exs)).
- `:verified` — registry tests cover spec round-trip + live-agent map.
- `:verified` — Mnesia survives restart (verified by `../../scripts/phase8_observe.exs`).

## Related

- Consumer: [`../workbench_web/`](../workbench_web/) (LiveViews subscribe to Bus and query EventLog).
- Provenance emitter: [`../agent_plane/lib/agent_plane/telemetry/bus.ex`](../agent_plane/lib/agent_plane/telemetry/bus.ex).
