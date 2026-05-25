# Week 9 Lab — The generative model, and learning A

**Spec:** `curriculum_app/content/lessons/week-09-math-spec.md` ·
**Gates exercised:** 3 (POMDP `A,B` column-stochastic, `C`,`D`,`E` normalize),
7 (learned `A` uses `E[ln A]`, the digamma form, not `ln E[A]`).

## What you'll observe

A bundle *is* the generative model `(A, B, C, D, E)`. Turn on learning and the
agent updates Dirichlet counts on `A` after each step; inference then consumes
the **expected log** `E[ln A] = ψ(α) − ψ(Σα)`, which sits strictly below the log
of the Dirichlet mean (Jensen) — so the model honestly reflects what it has yet
to learn.

## Reproduce the gate

```bash
mix test apps/agent_plane/test/actions/dirichlet_update_a_test.exs
mix test apps/agent_plane/test/actions/step_learning_test.exs   # held-out prediction improves
mix test apps/active_inference_core/test/math_test.exs           # digamma + E[ln A]
```

## Explore in IEx

```elixir
# iex -S mix
alias ActiveInferenceCore.{DiscreteTime, Math}

# A bundle's pieces are all there and well-formed:
blanket = SharedContracts.Blanket.maze_default()
bundle = AgentPlane.BundleBuilder.for_maze(
  width: 3, height: 1, start_idx: 0, goal_idx: 2, walls: [],
  blanket: blanket, horizon: 2, policy_depth: 2, learning_enabled: true)

# E[ln A] vs ln E[A] on some Dirichlet counts (8 obs of one outcome, 1 of another):
counts = [[9.0, 1.0], [1.0, 9.0]]
e_log_a = Math.dirichlet_expected_log(counts)        # ψ(α) − ψ(Σα)
ln_mean = counts |> Math.transpose() |> Enum.map(&Math.normalise/1)
                 |> Enum.map(&Math.log_eps/1) |> Math.transpose()
# Every entry of e_log_a is ≤ the matching ln_mean entry (Jensen):
Enum.zip(List.flatten(e_log_a), List.flatten(ln_mean)) |> Enum.all?(fn {e, m} -> e <= m end)
# => true

# inference_log_a/1 returns E[ln A] only when a bundle is actively learning:
DiscreteTime.inference_log_a(%{learning_enabled: true, dirichlet_a_counts: counts}) == e_log_a
```

Drive a learning agent with `AgentPlane.Actions.Step` and inspect
`agent.state.bundle.dirichlet_a_counts` growing each tick (see
`step_learning_test.exs`). Learning is gated on `:learning_enabled`; with it off,
`Step` is a strict no-op — `/labs` is unaffected.

## Run in the app

```
mix phx.server
# /labs?recipe=dirichlet-learn-a-matrix
# /labs?recipe=dirichlet-concentration-prior-effect
```
