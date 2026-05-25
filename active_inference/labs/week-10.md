# Week 10 Lab — Choosing softly (policy precision γ, EFE)

**Spec:** `curriculum_app/content/lessons/week-10-math-spec.md` ·
**Gates exercised:** 5 (EFE = ambiguity + risk, nats), 6 (action from the
marginal `Q(uₜ)=Σ_{π:πₜ=u} Q(π)`), and trust-gate anchors 5 & 8.

## What you'll observe

The policy posterior is `Q(π) = σ(ln E − γ Gπ − Fπ)`. Sweeping the **policy
precision γ** sharpens or flattens `Q(π)`; the action is then read off the
*marginal* `Q(uₜ)`, never from raw `G`. The EFE itself splits cleanly into
**ambiguity** (expected likelihood entropy) + **risk** (KL of predicted outcomes
from preferences) — both in nats.

## Reproduce the gate

```bash
mix test apps/active_inference_core/test/discrete_time_test.exs   # γ sharpening, EFE split
mix test apps/agent_plane/test/build_gate_test.exs               # gates 5 and 6
```

## Explore in IEx

```elixir
# iex -S mix
alias ActiveInferenceCore.{DiscreteTime, Math}

f = [0.0, 0.0, 0.0]            # equal F so only γ·G drives the posterior
g = [0.0, 1.0, 2.0]            # policy 0 has the lowest expected free energy

low  = DiscreteTime.policy_posterior(f, g, nil, gamma: 0.5)
high = DiscreteTime.policy_posterior(f, g, nil, gamma: 4.0)
# Higher γ concentrates probability on the min-G policy:
{Enum.at(high, 0) > Enum.at(low, 0), Enum.at(high, 2) < Enum.at(low, 2)}   # {true, true}

# EFE splits into ambiguity + risk (nats):
a = [[0.9, 0.1], [0.1, 0.9]]
efe = DiscreteTime.expected_free_energy([[0.3, 0.7]], a, Math.log_eps([0.1, 0.9]), -1)
{efe.total, Enum.sum(efe.ambiguity_per_tau) + Enum.sum(efe.risk_per_tau)}   # equal
```

`γ` rides on the bundle as `:gamma_g` (default `1.0` — the textbook
`σ(ln E − G − F)`); set it and re-run `choose_action/4` to watch `Q(π)` entropy
move. Selection is the marginal `result.action_marginal`, summed from `Q(π)`.

## Run in the app

```
mix phx.server
# /labs?recipe=efe-decompose-epistemic-pragmatic
# /labs?recipe=epistemic-risk-vs-ambiguity
```
