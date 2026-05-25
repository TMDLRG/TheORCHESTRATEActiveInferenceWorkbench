# Week 11 Lab — Markov blankets, carefully

**Spec:** `curriculum_app/content/lessons/week-11-math-spec.md` ·
**Gates exercised:** 8 (no reach-through; senses-in / actions-out enforced).

## What you'll observe

A Markov blanket `b` renders internal `μ` and external `η` **conditionally
independent**: `p(μ,η|b) = p(μ|b)·p(η|b)`. You *measure* it — the residual
`max_b |p(μ,η|b) − p(μ|b)p(η|b)|` is 0 for a genuine blanket and positive for a
leaky one. The architectural boundary is enforced too: an `ObservationPacket`
carries only declared sense channels and an `ActionPacket` only declared actions
— anything else **raises** at the boundary.

## Reproduce the gate

```bash
mix test apps/active_inference_core/test/markov_blanket_test.exs
mix test apps/agent_plane/test/build_gate_test.exs   # gate 8 (both packet directions)
```

## Explore in IEx

```elixir
# iex -S mix
alias ActiveInferenceCore.MarkovBlanket, as: MB

# A joint built from independent slices → residual 0 (a genuine blanket):
genuine = [
  MB.independent_slice(0.5, [0.8, 0.2], [0.3, 0.7]),
  MB.independent_slice(0.5, [0.5, 0.5], [0.9, 0.1])
]
MB.conditional_independence_residual(genuine)   # < 1.0e-12
MB.conditionally_independent?(genuine)            # true

# A joint where μ tracks η given b → the blanket "leaks":
leaky = [[[0.5, 0.0], [0.0, 0.5]]]
MB.conditional_independence_residual(leaky)       # 0.25
MB.conditionally_independent?(leaky)              # false
```

Boundary enforcement (senses-in / actions-out):

```elixir
b = SharedContracts.Blanket.maze_default()
# An action outside the vocabulary is refused — the agent cannot reach through:
SharedContracts.ActionPacket.new(%{t: 0, action: :teleport, agent_id: "me", blanket: b})
# ** (ArgumentError) blanket violation: action :teleport is not in the blanket's vocabulary
```

## Run in the app

```
mix phx.server
# /labs?recipe=perception-blanket-channel-choice
```
