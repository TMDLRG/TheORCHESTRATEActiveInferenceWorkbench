# active_inference_core/lib/ — ReadmeAI

## Purpose

Source tree for the pure-math library. All modules live directly under `lib/active_inference_core/` — no sub-packages.

## Contents

| File | Module | Purpose |
|---|---|---|
| [`active_inference_core.ex`](active_inference_core.ex) | `ActiveInferenceCore` | Root delegator |
| [`active_inference_core/math.ex`](active_inference_core/math.ex) | `ActiveInferenceCore.Math` | Tensor ops (no `Nx`) |
| [`active_inference_core/discrete_time.ex`](active_inference_core/discrete_time.ex) | `ActiveInferenceCore.DiscreteTime` | POMDP inference loop |
| [`active_inference_core/equation.ex`](active_inference_core/equation.ex) | `ActiveInferenceCore.Equation` | Source-traced record struct |
| [`active_inference_core/equations.ex`](active_inference_core/equations.ex) | `ActiveInferenceCore.Equations` | Equation registry |
| [`active_inference_core/model.ex`](active_inference_core/model.ex) | `ActiveInferenceCore.Model` | Model-family record |
| [`active_inference_core/models.ex`](active_inference_core/models.ex) | `ActiveInferenceCore.Models` | Model registry |

See [`../ReadmeAI.MD`](../ReadmeAI.MD) for the full public API table and telemetry details.
