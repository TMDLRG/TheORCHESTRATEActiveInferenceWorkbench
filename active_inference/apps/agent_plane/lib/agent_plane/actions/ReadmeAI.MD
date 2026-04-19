# agent_plane/lib/agent_plane/actions/ — ReadmeAI

## Purpose

The seven Jido actions implementing Active Inference. Each is a `use Jido.Action` module with a schema and a `run/2` callback. All return `{:ok, result, state}` or `{:error, reason}` per the [Jido.Action contract](../../../../../knowledgebase/jido/02-actions.md).

**Purity invariant**: `run/2` is pure relative to its inputs. Side effects (emit signals, publish events) are declared as **directives** returned alongside `{:ok, result, state}` — see [`knowledgebase/jido/04-directives.md`](../../../../../knowledgebase/jido/04-directives.md).

## Contents

| File | Module | Implements | Equation(s) |
|---|---|---|---|
| [`perceive.ex`](perceive.ex) | `AgentPlane.Actions.Perceive` | Sweep state beliefs given the observation history | eq. 4.13 / B.5 |
| [`plan.ex`](plan.ex) | `AgentPlane.Actions.Plan` | Compute F, G, policy posterior for every policy | eq. 4.11 (F), 4.10 (G), 4.14 / B.9 (π) |
| [`sophisticated_plan.ex`](sophisticated_plan.ex) | `AgentPlane.Actions.SophisticatedPlan` | Extended Plan with deep-horizon rollout (Ch 7) | eq. 7.2–7.4 |
| [`act.ex`](act.ex) | `AgentPlane.Actions.Act` | Pick action from marginal over π; emit `"active_inference.action"` signal | — |
| [`step.ex`](step.ex) | `AgentPlane.Actions.Step` | Convenience: Perceive → Plan → Act | — |
| [`dirichlet_update_a.ex`](dirichlet_update_a.ex) | `AgentPlane.Actions.DirichletUpdateA` | Online A-matrix learning (likelihood) | eq. 7.10, B.10–B.12 |
| [`dirichlet_update_b.ex`](dirichlet_update_b.ex) | `AgentPlane.Actions.DirichletUpdateB` | Online B-matrix learning (transition) | eq. 7.10, B.10–B.12 |

## Public API (all actions)

Every action exports `run/2`:

```elixir
@spec run(params :: map(), ctx :: Jido.Action.ctx()) ::
        {:ok, result :: map(), state :: map()} | {:error, term()}
```

Parameters per action are declared via the Jido `schema:` block; see each file.

## Directives used

- `Jido.Agent.Directive.Emit` — issued by `Act` to dispatch the `ActionPacket` as a `Jido.Signal` of type `"active_inference.action"`.

## Telemetry emitted

Every action call produces:

- `[:jido, :agent, :cmd, :start|:stop|:exception]` (Jido framework)
- `[:active_inference_core, :discrete_time, :call, :start|:stop|:exception]` for every `DiscreteTime` function invoked within (observable per equation)

See [`../telemetry/ReadmeAI.MD`](../telemetry/ReadmeAI.MD).

## Verification status

- `:verified` — `Perceive`, `Plan`, `Act`, `Step` exercised end-to-end by `../../../../test/runtime_test.exs`.
- `:scaffolded` — `SophisticatedPlan`, `DirichletUpdateA`, `DirichletUpdateB` compile and are wired to examples L3–L4; no dedicated tests yet.

## Related

- App docs: [`../../../ReadmeAI.MD`](../../../ReadmeAI.MD)
- Jido action rules: [`../../../../../knowledgebase/jido/02-actions.md`](../../../../../knowledgebase/jido/02-actions.md)
- Equation mapping: [`../equation_map.ex`](../equation_map.ex)
