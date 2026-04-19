# world_models/lib/world_models/spec/ — ReadmeAI

## Purpose

Supporting modules for `WorldModels.Spec` — topology representation (graph of nodes + edges the canvas renders) and per-node schema metadata (what parameters each block accepts + validation).

## Contents

| File | Module | Purpose |
|---|---|---|
| [`topology.ex`](topology.ex) | `WorldModels.Spec.Topology` | Graph: nodes + edges; used by the builder canvas and the block catalogue |
| [`block_schema.ex`](block_schema.ex) | `WorldModels.Spec.BlockSchema` | Node-type metadata + per-param validation |

## Public API

| Module | Function | Arity | Purpose |
|---|---|---|---|
| `Topology` | `node_types/0` | 0 | Every registered node type (powers `/guide/blocks`) |
| `Topology` | `validate/1` | 1 | Check a topology for structural issues |
| `BlockSchema` | `schema_for/1` | 1 | Schema for a given node type |
| `BlockSchema` | `validate_params/2` | 2 | Parameter validation for a node instance |

(Exact arities confirmed by reading the source; see files directly for latest.)

## Verification status

- `:verified` — used by Builder tests at [`../../../../../workbench_web/test/live/builder_live_test.exs`](../../../../../workbench_web/test/live/builder_live_test.exs).

## Related

- Canvas consumer: [`../../../../../workbench_web/lib/workbench_web/live/builder_live/compose.ex`](../../../../../workbench_web/lib/workbench_web/live/builder_live/compose.ex)
- Block catalogue: [`../../../../../workbench_web/lib/workbench_web/live/guide_live/blocks.ex`](../../../../../workbench_web/lib/workbench_web/live/guide_live/blocks.ex)
- ADR: [`../../../../../../docs/decisions/canvas-library.md`](../../../../../../docs/decisions/canvas-library.md)
