# world_plane/lib/ — ReadmeAI

## Purpose

Source tree for the generative process. One sub-package (`world_plane/`).

## Contents

| File | Module | Purpose |
|---|---|---|
| [`world_plane.ex`](world_plane.ex) | `WorldPlane` | Root delegator |
| [`world_plane/application.ex`](world_plane/application.ex) | `WorldPlane.Application` | OTP app |
| [`world_plane/engine.ex`](world_plane/engine.ex) | `WorldPlane.Engine` | GenServer episode runner |
| [`world_plane/maze.ex`](world_plane/maze.ex) | `WorldPlane.Maze` | Pure maze struct + movement |
| [`world_plane/worlds.ex`](world_plane/worlds.ex) | `WorldPlane.Worlds` | Registered mazes |
| [`world_plane/world.ex`](world_plane/world.ex) | `WorldPlane.World` | World struct |
| [`world_plane/observation_encoder.ex`](world_plane/observation_encoder.ex) | `WorldPlane.ObservationEncoder` | Engine state → `ObservationPacket` |

See [`../ReadmeAI.MD`](../ReadmeAI.MD) for public API + types.
