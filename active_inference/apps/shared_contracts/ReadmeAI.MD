# apps/shared_contracts/ — ReadmeAI

## Purpose

The **Markov blanket**. Only types in this app may cross the agent↔world boundary — everything else stays in its own plane. Zero logic, zero dependencies; pure data validation.

## Contents

| Path | Role |
|---|---|
| [`lib/shared_contracts.ex`](lib/shared_contracts.ex) | Umbrella root; re-exports |
| [`lib/shared_contracts/action_packet.ex`](lib/shared_contracts/action_packet.ex) | Atomic packet agent → world |
| [`lib/shared_contracts/observation_packet.ex`](lib/shared_contracts/observation_packet.ex) | Atomic packet world → agent |
| [`lib/shared_contracts/blanket.ex`](lib/shared_contracts/blanket.ex) | Markov-blanket declarative spec (observation channels + action vocabulary) |
| [`mix.exs`](mix.exs) | No Hex deps; no umbrella deps |
| [`test/`](test/) | 4 tests — [`test/ReadmeAI.MD`](test/ReadmeAI.MD) |
| [`lib/ReadmeAI.MD`](lib/ReadmeAI.MD) | Lib subtree map |

## Public API surface

| Module | Function | Arity | Purpose |
|---|---|---|---|
| `SharedContracts.ActionPacket` | `new/1` | 1 | Construct packet; validates `action ∈ blanket.action_vocabulary` |
| `SharedContracts.ObservationPacket` | `new/1` | 1 | Construct packet; validates `channels ⊆ blanket.observation_channels` |
| `SharedContracts.Blanket` | `maze_default/0` | 0 | Canonical maze blanket (6 obs channels + 4 cardinal actions) |
| `SharedContracts.Blanket` | `with_observation_channels/2` | 2 | Immutable update |
| `SharedContracts.Blanket` | `with_action_vocabulary/2` | 2 | Immutable update |

## Data types & schemas

| Type | File:Line | Fields |
|---|---|---|
| `ActionPacket.t/0` | [action_packet.ex:18](lib/shared_contracts/action_packet.ex) | `:t :: non_neg_integer`, `:action :: atom`, `:agent_id :: String.t` |
| `ObservationPacket.t/0` | [observation_packet.ex:31](lib/shared_contracts/observation_packet.ex) | `:t :: non_neg_integer`, `:channels :: map`, `:world_run_id :: String.t`, `:terminal? :: boolean` |
| `Blanket.t/0` | [blanket.ex:33](lib/shared_contracts/blanket.ex) | `:observation_channels :: [atom]`, `:action_vocabulary :: [atom]`, `:channel_specs :: %{atom => channel_spec}` |
| `Blanket.channel_spec/0` | [blanket.ex:27](lib/shared_contracts/blanket.ex) | `:kind :: :categorical \| :scalar \| :bool`, `:values :: term`, optional `:description :: String.t` |

## Constants & config keys

None. `Blanket.maze_default/0` ([blanket.ex:44-97](lib/shared_contracts/blanket.ex)) encodes the canonical maze blanket (4-bit walls + goal cue + tile index + wall_hit) but is a function, not a constant.

## Telemetry / signals / events emitted here

None. Pure data validation.

## Dependencies

- **Inbound**: [`../agent_plane/`](../agent_plane/), [`../world_plane/`](../world_plane/), [`../composition_runtime/`](../composition_runtime/), [`../workbench_web/`](../workbench_web/).
- **Outbound**: none.

## Verification status

- `:verified` — 4 tests cover blanket enforcement on packet construction ([`test/blanket_test.exs`](test/blanket_test.exs)).
- `:verified` — plane-separation is enforced by this app being the *only* path between agent and world; tests in `../agent_plane/test/plane_separation_test.exs` and `../world_plane/test/plane_separation_test.exs` prove it.

## Related

- Design rationale: [`../../DELIVERABLE.md`](../../DELIVERABLE.md) §6 (ADRs, blanket contracts)
- In-app technical page: `/guide/technical/data` (renders `Blanket.channel_spec` shape)
