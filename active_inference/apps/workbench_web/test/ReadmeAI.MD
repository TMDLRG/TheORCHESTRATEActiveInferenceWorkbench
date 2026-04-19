# workbench_web/test/ — ReadmeAI

## Purpose

Tests for the Phoenix LiveView UI, the episode orchestrator, the spec compiler, and end-to-end MVP scenarios. Groups: top-level (smoke + MVP + compiler), `live/`, `integration/`, `uat/`.

## Contents

| File | Scope |
|---|---|
| [`smoke_test.exs`](smoke_test.exs) | Basic endpoint / route health |
| [`mvp_maze_test.exs`](mvp_maze_test.exs) | MVP: agent reaches goal on tiny_open_goal (pure struct mode) |
| [`mvp_golden_test.exs`](mvp_golden_test.exs) | Golden-path snapshot for MVP trajectory |
| [`spec_compiler_test.exs`](spec_compiler_test.exs) | `SpecCompiler.compile/3` across all seeded examples × all mazes → runnable bundles |
| [`support/conn_case.ex`](support/conn_case.ex) | `use WorkbenchWeb.ConnCase` helper |
| [`test_helper.exs`](test_helper.exs) | `ExUnit.start()` |

### `live/` — LiveView tests

| File | Scope |
|---|---|
| [`live/builder_live_test.exs`](live/builder_live_test.exs) | Builder: mount, palette, topology round-trip, Save, Instantiate |
| [`live/glass_live_test.exs`](live/glass_live_test.exs) | Glass: live + historic listing, event filtering, timeline scrub |
| [`live/world_live_test.exs`](live/world_live_test.exs) | World: maze selection, episode create, step, auto-run, reset, stop |

### `integration/` — cross-plane integration

| File | Scope |
|---|---|
| [`integration/episode_publishing_test.exs`](integration/episode_publishing_test.exs) | Episode publishes to `WorldModels.Bus` → persisted by `EventLog` |
| [`integration/equation_telemetry_test.exs`](integration/equation_telemetry_test.exs) | `[:active_inference_core, :discrete_time, :call]` span → `equation.evaluated` event |
| [`integration/mvp_maze_supervised_test.exs`](integration/mvp_maze_supervised_test.exs) | MVP under supervised Jido.AgentServer (not struct mode) |

### `uat/` — user-acceptance

| File | Scope |
|---|---|
| [`uat/uat_test.exs`](uat/uat_test.exs) | Six UAT scenarios (extraction → registry → runtime → glass → builder → labs) with class-A observed evidence |

## Conventions

- `ExUnit.Case, async: true` for pure tests; `async: false` for Mnesia-touching integration
- No `Process.sleep/1` — use `render_async`, `Phoenix.LiveViewTest` helpers, or `Jido.await/2`
- HTTP port 4002 in tests (`server: false`); LiveView tests use `Phoenix.LiveViewTest` rather than a live socket

## Verification status

- `:verified` — all 1 MVP test + LiveView + integration + spec compiler + uat tests pass.

## Related

- App docs: [`../ReadmeAI.MD`](../ReadmeAI.MD)
- Phase D will add `live/guide_technical_test.exs` (smoke-test `/guide/technical/*`) and `docs/api_catalog_test.exs` (enforce `@doc` coverage guarantee).
