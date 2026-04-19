# world_plane/test/ — ReadmeAI

## Purpose

Tests for the generative process. Maze solvability (BFS sanity), engine contract, and plane-separation invariant.

## Contents

| File | Scope |
|---|---|
| [`maze_test.exs`](maze_test.exs) | Maze construction from rows; tile lookups; every registered maze is solvable via BFS |
| [`engine_test.exs`](engine_test.exs) | `Engine.start_link` / `apply_action` / `reset` / `stop`; terminal detection; wall-hit reporting |
| [`plane_separation_test.exs`](plane_separation_test.exs) | `world_plane` has **no** compiled reference to `agent_plane` or `active_inference_core` modules; `mix.exs` does not depend on them |
| [`test_helper.exs`](test_helper.exs) | `ExUnit.start()` |

## Conventions

`ExUnit.Case, async: true`. 8 tests total.

## Verification status

- `:verified` — full coverage of the engine contract; plane-separation is provable by compile-time introspection, not just by convention.

## Related

- App docs: [`../ReadmeAI.MD`](../ReadmeAI.MD)
