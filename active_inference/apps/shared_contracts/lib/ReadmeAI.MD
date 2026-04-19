# shared_contracts/lib/ — ReadmeAI

## Purpose

Source tree for the Markov-blanket packet types. Three modules; no sub-packages.

## Contents

| File | Module | Purpose |
|---|---|---|
| [`shared_contracts.ex`](shared_contracts.ex) | `SharedContracts` | Root |
| [`shared_contracts/blanket.ex`](shared_contracts/blanket.ex) | `SharedContracts.Blanket` | Declarative spec |
| [`shared_contracts/action_packet.ex`](shared_contracts/action_packet.ex) | `SharedContracts.ActionPacket` | Agent → world |
| [`shared_contracts/observation_packet.ex`](shared_contracts/observation_packet.ex) | `SharedContracts.ObservationPacket` | World → agent |

See [`../ReadmeAI.MD`](../ReadmeAI.MD) for the full public API.
