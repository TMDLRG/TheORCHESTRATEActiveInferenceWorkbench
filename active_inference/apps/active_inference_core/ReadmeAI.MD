# apps/active_inference_core/ — ReadmeAI

## Purpose

Pure mathematical library for discrete-time POMDP Active Inference (Parr, Pezzulo, Friston 2022). Zero process involvement, zero Jido dependency, zero umbrella dependency. Every higher-level app depends on this one for math + registries.

## Contents

| Path | Role |
|---|---|
| [`lib/active_inference_core.ex`](lib/active_inference_core.ex) | Root module delegating to equation + model registries |
| [`lib/active_inference_core/math.ex`](lib/active_inference_core/math.ex) | Low-level tensor ops on lists/matrices; no `Nx` |
| [`lib/active_inference_core/discrete_time.ex`](lib/active_inference_core/discrete_time.ex) | Core POMDP inference loop (eq. 4.11 / 4.13 / 4.14 / B.5 / B.9) |
| [`lib/active_inference_core/equation.ex`](lib/active_inference_core/equation.ex) | Source-traced equation struct |
| [`lib/active_inference_core/equations.ex`](lib/active_inference_core/equations.ex) | Registry of ~50 equations extracted from the book |
| [`lib/active_inference_core/model.ex`](lib/active_inference_core/model.ex) | Model-family record |
| [`lib/active_inference_core/models.ex`](lib/active_inference_core/models.ex) | Registry of model families (POMDP, continuous, hybrid…) |
| [`mix.exs`](mix.exs) | Hex deps: `:jason ~> 1.4`, `:telemetry ~> 1.2` |
| [`test/`](test/) | 20 tests — [`test/ReadmeAI.MD`](test/ReadmeAI.MD) |
| [`lib/ReadmeAI.MD`](lib/ReadmeAI.MD) | Lib subtree map |

## Public API surface

| Module | Function | Arity | Purpose |
|---|---|---|---|
| `ActiveInferenceCore` | `all_equations/0` | 0 | Delegates to `Equations.all/0` |
| `ActiveInferenceCore` | `all_models/0` | 0 | Delegates to `Models.all/0` |
| `ActiveInferenceCore.Equations` | `all/0` | 0 | Full registry |
| `ActiveInferenceCore.Equations` | `fetch/1` | 1 | Fetch by id |
| `ActiveInferenceCore.Equations` | `by_type/1` | 1 | Filter by `:discrete` \| `:continuous` \| `:hybrid` \| `:general` |
| `ActiveInferenceCore.Equations` | `by_family/1` | 1 | Filter by model family |
| `ActiveInferenceCore.Models` | `all/0` | 0 | Full family list |
| `ActiveInferenceCore.Models` | `fetch/1` | 1 | Fetch family by id |
| `ActiveInferenceCore.Models` | `by_type/1` | 1 | Filter families by type |
| `ActiveInferenceCore.Math` | `log_eps/1` | 1 | log with `@eps` floor |
| `ActiveInferenceCore.Math` | `log_eps_mat/1` | 1 | element-wise log for matrix |
| `ActiveInferenceCore.Math` | `hadamard/2` | 2 | Element-wise product |
| `ActiveInferenceCore.Math` | `dot/2` | 2 | Dot product |
| `ActiveInferenceCore.Math` | `sum/1` | 1 | Sum of vector |
| `ActiveInferenceCore.Math` | `scale/2` | 2 | Scalar × vector |
| `ActiveInferenceCore.Math` | `add/2` \| `sub/2` | 2 | Vector add / subtract |
| `ActiveInferenceCore.Math` | `transpose/1` | 1 | Matrix transpose |
| `ActiveInferenceCore.Math` | `matvec/2` | 2 | Matrix × vector |
| `ActiveInferenceCore.Math` | `log_matvec/2` | 2 | log(M) · v (for KL stability) |
| `ActiveInferenceCore.Math` | `normalise/1` | 1 | Vector normalisation (L1) |
| `ActiveInferenceCore.Math` | `softmax/1` | 1 | Softmax |
| `ActiveInferenceCore.Math` | `entropy/1` | 1 | Shannon entropy |
| `ActiveInferenceCore.Math` | `kl/2` | 2 | KL divergence |
| `ActiveInferenceCore.Math` | `ambiguity_vector/1` | 1 | Per-state observation ambiguity |
| `ActiveInferenceCore.Math` | `one_hot/2` | 2 | One-hot vector |
| `ActiveInferenceCore.Math` | `uniform/1` | 1 | Uniform distribution of size N |
| `ActiveInferenceCore.DiscreteTime` | `predict_obs/2` | 2 | Predict next observation from A × state belief |
| `ActiveInferenceCore.DiscreteTime` | `update_state_beliefs/8` | 8 | Full belief update — eq. 4.13 / B.5 |
| `ActiveInferenceCore.DiscreteTime` | `sweep_state_beliefs/7` | 7 | Iterate `update_state_beliefs` over history |
| `ActiveInferenceCore.DiscreteTime` | `variational_free_energy/6` | 6 | F — eq. 4.11 |
| `ActiveInferenceCore.DiscreteTime` | `expected_free_energy/3` | 3 | G — eq. 4.10 |
| `ActiveInferenceCore.DiscreteTime` | `policy_posterior/4` | 4 | π posterior from F, G, E — eq. 4.14 / B.9 |
| `ActiveInferenceCore.DiscreteTime` | `choose_action/4` | 4 | Marginal over π for each action; pick argmax |
| `ActiveInferenceCore.DiscreteTime` | `marginal_over_policies/3` | 3 | Weighted sum of per-policy state beliefs |
| `ActiveInferenceCore.DiscreteTime` | `fresh_beliefs/1` | 1 | Initial uniform belief tensor |
| `ActiveInferenceCore.DiscreteTime` | `rollout_forward/4` | 4 | Forward rollout used by sophisticated planner |

## Data types & schemas

| Type | File | Fields |
|---|---|---|
| `Math.vec/0` | [math.ex:12](lib/active_inference_core/math.ex) | `[float()]` |
| `Math.mat/0` | [math.ex:15](lib/active_inference_core/math.ex) | `[[float()]]` |
| `DiscreteTime.belief/0` | [discrete_time.ex:58](lib/active_inference_core/discrete_time.ex) | `[Math.vec()]` per-τ belief tensor |
| `Equation.t/0` | [equation.ex:39](lib/active_inference_core/equation.ex) | `:id`, `:source_title`, `:chapter`, `:section`, `:equation_number`, `:source_text_equation`, `:normalized_latex`, `:symbols`, `:model_family`, `:model_type`, `:conceptual_role`, `:implementation_role`, `:dependencies`, `:verification_status`, `:verification_notes` |
| `Model.t/0` | [model.ex](lib/active_inference_core/model.ex) | Family id, source basis equation IDs, variables, priors, likelihood, transition, inference, planning, extensibility |

## Constants & config keys

| Constant | Value | File:Line |
|---|---|---|
| `@eps` | `1.0e-16` | [math.ex:17](lib/active_inference_core/math.ex) |
| `@telemetry_event` | `[:active_inference_core, :discrete_time, :call]` | [discrete_time.ex:60](lib/active_inference_core/discrete_time.ex) |
| `@source_title` | `"Parr, Pezzulo, Friston (2022)..."` | [equations.ex:36](lib/active_inference_core/equations.ex) |

No runtime Application env keys; this app is pure.

## Telemetry / signals / events emitted here

| Event | Measurements | Metadata | Emitter |
|---|---|---|---|
| `[:active_inference_core, :discrete_time, :call, :start]` | n/a (`:telemetry.span/3`) | `%{fn: atom, arity: int}` (process dict adds `:wm_telemetry_context`) | [`DiscreteTime`](lib/active_inference_core/discrete_time.ex) public fns |
| `[:active_inference_core, :discrete_time, :call, :stop]` | `duration: native_units` | as above | as above |
| `[:active_inference_core, :discrete_time, :call, :exception]` | n/a | as above | as above |

Subscribed by [`AgentPlane.Telemetry.Bus`](../agent_plane/lib/agent_plane/telemetry/bus.ex:17-32) and re-emitted as `WorldModels.Event` of type `"equation.evaluated"`.

## Dependencies

- **Inbound**: every other umbrella app except `shared_contracts`.
- **Outbound (Hex)**: [`:jason ~> 1.4`](mix.exs:29), [`:telemetry ~> 1.2`](mix.exs:31).
- **Outbound (umbrella)**: none.

## Verification status

- `:verified` — 20 tests pass ([`test/ReadmeAI.MD`](test/ReadmeAI.MD)); covers equation registry integrity, math primitives, POMDP end-to-end on discrete_time.
- `:verified` — plane-separation invariant: no reverse dependency from any other app leaking back.
- `:scaffolded` — continuous-time / hybrid equations exist in registry but lack dedicated runtime tests.

## Related

- Umbrella: [`../../ReadmeAI.MD`](../../ReadmeAI.MD)
- Equation registry detail: [`lib/active_inference_core/equations.ex`](lib/active_inference_core/equations.ex) `@moduledoc`
- Consumers: [`../agent_plane/`](../agent_plane/), [`../workbench_web/`](../workbench_web/)
