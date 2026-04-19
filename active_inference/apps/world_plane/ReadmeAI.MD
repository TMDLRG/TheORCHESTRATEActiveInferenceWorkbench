# apps/world_plane/ — ReadmeAI

## Purpose

The **generative process**. Owns the world (map topology, goal, collisions, rewards, terminal conditions). Never reads agent state; only accepts `SharedContracts.ActionPacket` and emits `SharedContracts.ObservationPacket`. **Does not depend on `agent_plane` or `active_inference_core`** — enforced by [`test/plane_separation_test.exs`](test/plane_separation_test.exs).

## Contents

| Path | Role |
|---|---|
| [`lib/world_plane.ex`](lib/world_plane.ex) | Root module delegating to Worlds + Engine |
| [`lib/world_plane/application.ex`](lib/world_plane/application.ex) | OTP Application |
| [`lib/world_plane/engine.ex`](lib/world_plane/engine.ex) | GenServer running one episode |
| [`lib/world_plane/maze.ex`](lib/world_plane/maze.ex) | Pure maze structure + movement logic |
| [`lib/world_plane/worlds.ex`](lib/world_plane/worlds.ex) | Registry of prebuilt mazes |
| [`lib/world_plane/world.ex`](lib/world_plane/world.ex) | World struct |
| [`lib/world_plane/observation_encoder.ex`](lib/world_plane/observation_encoder.ex) | Converts engine state → `ObservationPacket` through the blanket |
| [`mix.exs`](mix.exs) | Depends only on `:shared_contracts` (in-umbrella) |
| [`test/`](test/) | 8 tests — [`test/ReadmeAI.MD`](test/ReadmeAI.MD) |

## Public API surface

| Module | Function | Arity | Purpose |
|---|---|---|---|
| `WorldPlane` | `list_worlds/0` | 0 | All registered mazes |
| `WorldPlane` | `fetch_world/1` | 1 | Fetch maze by id |
| `WorldPlane` | `start_run/1` | 1 | Start a new Engine GenServer |
| `WorldPlane` | `peek/1` | 1 | Read-only snapshot of engine state |
| `WorldPlane.Engine` | `start_link/1` | 1 | Spawn engine; requires `:maze`, `:blanket` |
| `WorldPlane.Engine` | `current_observation/1` | 1 | Return current `ObservationPacket` |
| `WorldPlane.Engine` | `apply_action/2` | 2 | Accept `ActionPacket`; advance; emit next `ObservationPacket` |
| `WorldPlane.Engine` | `peek/1` | 1 | Snapshot |
| `WorldPlane.Engine` | `reset/1` | 1 | Reset to `run_id`-fresh state |
| `WorldPlane.Engine` | `stop/1` | 1 | Terminate engine |
| `WorldPlane.Maze` | `from_rows/4` | 4 | Construct maze from row-string list |
| `WorldPlane.Maze` | `tile_at/2` | 2 | Tile lookup |
| `WorldPlane.Worlds` | `all/0` | 0 | All registered mazes |
| `WorldPlane.Worlds` | `fetch/1` | 1 | Fetch by id |

## Data types & schemas

| Type | File:Line | Shape |
|---|---|---|
| `Engine.t/0` | [engine.ex:31](lib/world_plane/engine.ex) | `:maze`, `:pos :: Maze.coord`, `:t :: non_neg_integer`, `:blanket :: Blanket.t`, `:run_id :: String.t`, `:terminal? :: boolean`, `:last_action_blocked? :: boolean`, `:history :: list` |
| `Maze.t/0` | [maze.ex:19](lib/world_plane/maze.ex) | `:id :: String.t`, `:name :: String.t`, `:width`, `:height`, `:grid :: %{coord => tile}`, `:start :: coord`, `:goal :: coord`, `:description :: String.t` |
| `Maze.tile/0` | [maze.ex:15](lib/world_plane/maze.ex) | `:empty \| :wall \| :start \| :goal` |
| `Maze.coord/0` | [maze.ex:16](lib/world_plane/maze.ex) | `{col, row}`; origin at top-left |
| `Maze.action/0` | [maze.ex:17](lib/world_plane/maze.ex) | `:move_north \| :move_south \| :move_east \| :move_west` |

## Constants & config keys

None at runtime (all mazes are defined in [worlds.ex](lib/world_plane/worlds.ex) as literals).

## Telemetry / signals / events emitted here

None directly. The engine returns packets; `WorkbenchWeb.Episode` publishes `world.observation` and `world.terminal` events to `WorldModels.Bus` when it runs episodes.

## Dependencies

- **Inbound**: [`../agent_plane/`](../agent_plane/), [`../workbench_web/`](../workbench_web/), [`../composition_runtime/`](../composition_runtime/), [`../../scripts/`](../../scripts/).
- **Outbound (Hex)**: none.
- **Outbound (umbrella)**: `:shared_contracts`.

## Verification status

- `:verified` — 8 tests: mazes solvable via BFS (sanity), engine contract (`apply_action`, `reset`, `terminal?`), plane-separation.
- `:verified` — engine never reads agent state (tested by plane-separation).

## Related

- Blanket contract: [`../shared_contracts/ReadmeAI.MD`](../shared_contracts/ReadmeAI.MD)
- Orchestrator that pairs agents with engines: [`../workbench_web/lib/workbench_web/episode.ex`](../workbench_web/lib/workbench_web/episode.ex)
