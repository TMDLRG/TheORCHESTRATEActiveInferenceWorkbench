# Week 8 Lab — Perception as inference (mean-field VMP)

**Spec:** `curriculum_app/content/lessons/week-08-math-spec.md` ·
**Gates exercised:** 1 (nats), 2 (bound `F[q] ≥ −ln p(o|m)`), 4 (declared path).

> **Inference path.** This workbench implements **mean-field variational message
> passing** (`ActiveInferenceCore.DiscreteTime.inference_path/0 == :mean_field_vmp`):
> the state-belief update (eq. 4.13/B.5) uses the expected-log transition message
> `(ln B) s`. The lesson teaches this implemented method.

## What you'll observe

A single observation turns a prior over hidden states into a posterior, and the
variational free energy of that posterior equals the surprise — the bound is
*tight* at the exact posterior and only ever above it.

## Reproduce the gate

```bash
mix test apps/active_inference_core/test/trust_gate_test.exs   # Anchor 2 = this lab
mix test apps/active_inference_core/test/discrete_time_test.exs
```

## Explore in IEx

```elixir
# iex -S mix
alias ActiveInferenceCore.{DiscreteTime, Math}

a = [[0.9, 0.2], [0.1, 0.8]]   # P(o|s): columns are states
d = [0.5, 0.5]                 # prior over the two states
o = [1.0, 0.0]                 # observed outcome 0

post = DiscreteTime.update_state_beliefs(nil, d, nil, o, a, nil, nil, 1.0)
# => [0.818..., 0.182...]  — posterior ∝ A[o,:]·D

# The bound: F[q*] equals the surprise −ln p(o); any other q gives MORE.
f = DiscreteTime.variational_free_energy([post], [:stay],
      %{stay: [[1.0, 0.0], [0.0, 1.0]]}, a, [o], d)
surprise = -:math.log(Enum.sum(Enum.zip_with(DiscreteTime.predict_obs(a, d), o, &(&1 * &2))))
{f, surprise}   # ≈ {0.59784, 0.59784}
```

Try a *wrong* `q` (e.g. `[0.5, 0.5]`) in `variational_free_energy/6` and confirm
`F` rises above the surprise — never below it (gate 2).

## Run in the app

```
mix phx.server
# /labs?recipe=bayes-one-step-coin
```
Step the agent and watch the belief bar update as each observation arrives; the
`/glass` trace shows the `eq_4_13_state_belief_update` and
`eq_4_11_vfe_linear_algebra` spans firing.
