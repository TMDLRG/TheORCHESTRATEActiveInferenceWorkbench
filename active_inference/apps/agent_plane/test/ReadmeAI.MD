# agent_plane/test/ — ReadmeAI

## Purpose

Tests for the generative model: native Jido integration, agent runtime, plane separation, equation-to-function provenance, corridor convergence sanity.

## Contents

| File | Scope |
|---|---|
| [`jido_native_test.exs`](jido_native_test.exs) | `ActiveInferenceAgent.fresh/4` produces a real `Jido.Agent`; `use Jido.Agent` contract holds |
| [`runtime_test.exs`](runtime_test.exs) | `Runtime.start_agent` / `perceive` / `plan` / `act` / `step` end-to-end; agent converges on a small corridor |
| [`plane_separation_test.exs`](plane_separation_test.exs) | `agent_plane` has **no** compiled reference to `world_plane`; blanket packets are the only crossing |
| [`provenance_test.exs`](provenance_test.exs) | Agent state carries `spec_id`, `bundle_id`, `family_id`, `primary_equation_ids` through a full episode |
| [`equation_map_test.exs`](equation_map_test.exs) | `EquationMap.lookup/3` resolves every `DiscreteTime` public fn to non-empty equation-id list |
| [`test_helper.exs`](test_helper.exs) | `ExUnit.start()` |

## Conventions

- `ExUnit.Case, async: true`
- No `Process.sleep/1` — use `Jido.await/2` or event-driven assertions on `WorldModels.Bus` per [`CLAUDE.md`](../../../../CLAUDE.md)
- Tests exercise the supervised Jido path (real `Jido.AgentServer`)

## Verification status

- `:verified` — 5 tests pass on every CI run.

## Related

- App docs: [`../ReadmeAI.MD`](../ReadmeAI.MD)
- Jido test helpers: [`../../../../knowledgebase/jido/20-testing.md`](../../../../knowledgebase/jido/20-testing.md)
