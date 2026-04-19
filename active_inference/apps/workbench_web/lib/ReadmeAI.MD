# workbench_web/lib/ — ReadmeAI

## Purpose

Source tree for the Phoenix LiveView workbench.

## Contents

| File | Module | Purpose |
|---|---|---|
| [`workbench_web.ex`](workbench_web.ex) | `WorkbenchWeb` | `controller/view/live` macros |
| [`workbench_web/application.ex`](workbench_web/application.ex) | `WorkbenchWeb.Application` | OTP app; children = PubSub + Endpoint |
| [`workbench_web/endpoint.ex`](workbench_web/endpoint.ex) | `WorkbenchWeb.Endpoint` | Bandit + `/live` socket + session + static |
| [`workbench_web/router.ex`](workbench_web/router.ex) | `WorkbenchWeb.Router` | 18 routes (more coming in Phase D `/guide/technical/*`) |
| [`workbench_web/episode.ex`](workbench_web/episode.ex) | `WorkbenchWeb.Episode` | GenServer orchestrator |
| [`workbench_web/spec_compiler.ex`](workbench_web/spec_compiler.ex) | `WorkbenchWeb.SpecCompiler` | Pure Spec × Maze compiler |

### Subtrees

| Subtree | What it contains | README |
|---|---|---|
| [`workbench_web/live/`](workbench_web/live/) | 16 LiveView modules across 9 feature folders | (per-feature READMEs below) |
| [`workbench_web/components/`](workbench_web/components/) | `CoreComponents`, `Layouts`, `PolicyVisual`, `ErrorHTML` | [subtree README](workbench_web/components/ReadmeAI.MD) |

### Live feature subtrees (see app-root for route map)

| Subtree | Live modules |
|---|---|
| `live/workbench_live/` | `Index` (dashboard `/`) |
| `live/equations_live/` | `Index` (`/equations`), `Show` (`/equations/:id`) |
| `live/models_live/` | `Index` (`/models`) |
| `live/world_live/` | `Index` (`/world`) |
| `live/run_live/` | `Index` (legacy `/run`) |
| `live/glass_live/` | `Index`, `Agent`, `Signal` |
| `live/builder_live/` | `Compose` |
| `live/labs_live/` | `Run` |
| `live/guide_live/` | `Index`, `Blocks`, `Examples`, `ExampleCatalog`, `Tutorial`, **+ Phase D `Technical.*`** |

See [`../ReadmeAI.MD`](../ReadmeAI.MD) for the consolidated route map and feature list.
