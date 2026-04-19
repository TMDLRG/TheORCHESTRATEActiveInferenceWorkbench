# world_models/lib/world_models/seeds/ — ReadmeAI

## Purpose

Boot-time seeding: pre-registers the L1–L5 example specs and their archetypes so the Builder canvas, Labs, and `/guide/examples` all have content the moment the app starts.

## Contents

| File | Module | Purpose |
|---|---|---|
| [`examples.ex`](examples.ex) | `WorldModels.Seeds.Examples` | `seed_all!/0` — registers five example specs |

## Public API

| Module | Function | Arity | Purpose |
|---|---|---|---|
| `Examples` | `seed_all!/0` | 0 | Called as a transient `Task` child of `WorldModels.Application` on every boot |

## Seeded specs

The five examples form the L1–L5 capability gradient (from [`../../../../../README.md`](../../../../../README.md)):

| Level | `spec_id` | World | Archetype |
|---|---|---|---|
| L1 | `example-l1-hello-pomdp` | `tiny_open_goal` | `pomdp_maze` |
| L2 | `example-l2-epistemic-explorer` | `forked_paths` | `pomdp_maze` + epistemic_preference |
| L3 | `example-l3-sophisticated-planner` | `deceptive_dead_end` | `pomdp_maze` + sophisticated_planner |
| L4 | `example-l4-dirichlet-learner` | `corridor_turns` | `dirichlet_pomdp` |
| L5 | `example-l5-hierarchical-composition` | `hierarchical_maze` | (multi-agent via composition_runtime) |

## Verification status

- `:verified` — seeds run on every boot; LabsLive and BuilderLive both assume they ran (tests rely on this).
- `:scaffolded` — L5 hierarchical composition is wired at the archetype level; full multi-agent runtime not end-to-end tested.

## Related

- Consumer: [`../../../../../workbench_web/lib/workbench_web/live/labs_live/run.ex`](../../../../../workbench_web/lib/workbench_web/live/labs_live/run.ex)
- Spec compiler: [`../../../../../workbench_web/lib/workbench_web/spec_compiler.ex`](../../../../../workbench_web/lib/workbench_web/spec_compiler.ex)
