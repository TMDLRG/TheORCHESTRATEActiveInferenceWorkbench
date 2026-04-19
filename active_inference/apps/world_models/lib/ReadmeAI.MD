# world_models/lib/ — ReadmeAI

## Purpose

Source tree for the event store, spec registry, agent registry, bus, and archetype catalogue.

## Contents

| File | Module | Purpose |
|---|---|---|
| [`world_models/application.ex`](world_models/application.ex) | `WorldModels.Application` | OTP app |
| [`world_models/bus.ex`](world_models/bus.ex) | `WorldModels.Bus` | Phoenix.PubSub facade |
| [`world_models/event.ex`](world_models/event.ex) | `WorldModels.Event` | Envelope + provenance |
| [`world_models/event_log.ex`](world_models/event_log.ex) | `WorldModels.EventLog` | Mnesia append-only log |
| [`world_models/agent_registry.ex`](world_models/agent_registry.ex) | `WorldModels.AgentRegistry` | Spec + live-agent tables |
| [`world_models/spec.ex`](world_models/spec.ex) | `WorldModels.Spec` | Content-addressed spec |
| [`world_models/archetypes.ex`](world_models/archetypes.ex) | `WorldModels.Archetypes` | Canvas templates |

### Subtrees

| Subtree | Modules | README |
|---|---|---|
| [`world_models/event_log/`](world_models/event_log/) | `Setup`, `Janitor` | [subtree README](world_models/event_log/ReadmeAI.MD) |
| [`world_models/spec/`](world_models/spec/) | `Topology`, `BlockSchema` | [subtree README](world_models/spec/ReadmeAI.MD) |
| [`world_models/seeds/`](world_models/seeds/) | `Examples` | [subtree README](world_models/seeds/ReadmeAI.MD) |

See [`../ReadmeAI.MD`](../ReadmeAI.MD) for consolidated public API + Mnesia table schema.
