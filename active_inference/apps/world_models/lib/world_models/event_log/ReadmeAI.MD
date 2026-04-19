# world_models/lib/world_models/event_log/ — ReadmeAI

## Purpose

Mnesia schema bootstrap and periodic retention for the event log.

## Contents

| File | Module | Purpose |
|---|---|---|
| [`setup.ex`](setup.ex) | `WorldModels.EventLog.Setup` | Creates Mnesia schema + 3 tables + indices; exposes schema constants |
| [`janitor.ex`](janitor.ex) | `WorldModels.EventLog.Janitor` | Periodic cleanup child of `WorldModels.Application` |

## Public API

| Module | Function | Arity | Purpose |
|---|---|---|---|
| `Setup` | `ensure_schema!/0` | 0 | Idempotent schema + table create |
| `Setup` | `table/0` | 0 | `:world_models_events` |
| `Setup` | `attributes/0` | 0 | `[:key, :agent_id, :type, :spec_id, :world_run_id, :event]` |
| `Setup` | `specs_table/0` | 0 | `:world_models_specs` |
| `Setup` | `live_agents_table/0` | 0 | `:world_models_live_agents` |
| `Setup` | `child_spec/1` | 1 | Supervisor integration |
| `Janitor` | (GenServer) | — | Trims old events per retention policy |

## Mnesia tables (defined here)

See [`../../ReadmeAI.MD`](../../ReadmeAI.MD) → "Mnesia tables" for type / copies / indices per table.

## Configuration

- `:world_models, :auto_start_event_log` — `true` dev/prod; `false` test (see [`../../../../../config/test.exs:11`](../../../../../config/test.exs))
- `:mnesia, :dir` — disk location ([dev.exs:14](../../../../../config/dev.exs), [prod.exs:7](../../../../../config/prod.exs))

## Verification status

- `:verified` — round-trip + restart durability covered by [`../../../../test/event_log_test.exs`](../../../../test/event_log_test.exs) and [`../../../../../../scripts/phase8_observe.exs`](../../../../../../scripts/phase8_observe.exs).

## Related

- App docs: [`../../../ReadmeAI.MD`](../../../ReadmeAI.MD)
