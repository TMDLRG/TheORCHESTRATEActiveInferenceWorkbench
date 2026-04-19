# world_models/test/ — ReadmeAI

## Purpose

Tests for the event store, spec registry, agent registry, PubSub bus, and archetype catalogue. Uses `WorldModels.MnesiaCase` for isolated Mnesia per test.

## Contents

| File | Scope |
|---|---|
| [`event_log_test.exs`](event_log_test.exs) | `append/1`, `query/1`, `snapshot_at/2` round-trips on Mnesia |
| [`agent_registry_test.exs`](agent_registry_test.exs) | Spec register/fetch; live-agent register/fetch; `live_for_spec` lookup |
| [`archetypes_test.exs`](archetypes_test.exs) | `all/0`, `fetch/1`, `enabled/0`, `seed_topology/1` for POMDP maze |
| [`bus_test.exs`](bus_test.exs) | Phoenix.PubSub topic routing: global, agent, world, spec |
| [`mnesia_case_test.exs`](mnesia_case_test.exs) | Meta-test: `MnesiaCase` gives each test an isolated Mnesia |
| [`support/mnesia_case.ex`](support/mnesia_case.ex) | `use WorldModels.MnesiaCase` helper |
| [`test_helper.exs`](test_helper.exs) | `ExUnit.start()` |

## Conventions

- `WorldModels.MnesiaCase` sets `async: false` (required for Mnesia schema isolation)
- `:world_models, :auto_start_event_log` is `false` in tests (see [`../../../config/test.exs:11`](../../../config/test.exs))
- `on_exit` cleans up each test's tmp Mnesia dir

## Verification status

- `:verified` — Mnesia round-trip + durability; durability also proven by [`../../../scripts/phase8_observe.exs`](../../../scripts/phase8_observe.exs).

## Related

- App docs: [`../ReadmeAI.MD`](../ReadmeAI.MD)
- Test helper: [`support/mnesia_case.ex`](support/mnesia_case.ex)
