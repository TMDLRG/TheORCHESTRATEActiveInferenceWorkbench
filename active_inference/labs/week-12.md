# Week 12 Lab — Capstone: the cue task and its five ablations

**Spec:** `curriculum_app/content/lessons/week-12-math-spec.md` ·
**Gates exercised:** 9 (ablation gate — behaviour survives and *fails in the
predicted ways*), and the full stack (gates 1–8).

## What you'll observe

A cue-guided T-maze (`AgentPlane.BundleBuilder.CueTask`): the reward is at the
left or right arm, the **cue** reveals which, and `C` prefers the **reward
outcome, not the cue**. The mechanism has two robust halves — an informative cue
*resolves the context*, and a context-resolved agent *exploits the matching arm*
— and five ablations each break it in the predicted direction.

> **Honest scope (per the corrected capstone claim).** Explore-then-exploit is
> NOT automatic; it depends on task structure and parameters. It emerges here in
> the **loss-averse regime**: the cue's default `C` strongly disprefers `:loss`,
> so gambling on an arm under unknown context is worse than the safe, informative
> cue — the agent seeks the cue, then exploits once the context is resolved.
> Caveat (UNI): this cue-seeking is *risk-driven*, not *ambiguity-driven*, so
> ablation 2 (drop the ambiguity term) does not abolish it — ablation 3 (flatten
> `C`) does. See the labs README and the UNI packet.

## Reproduce the gate

```bash
mix test apps/agent_plane/test/cue_task_test.exs        # 5 ablations + mechanism
mix test apps/agent_plane/test/build_gate_test.exs      # all 9 gates
```

## Explore in IEx

```elixir
# iex -S mix
alias ActiveInferenceCore.{DiscreteTime, Math}
alias AgentPlane.BundleBuilder.CueTask

p_left = fn b -> CueTask.left_context_states() |> Enum.map(&Enum.at(b, &1)) |> Enum.sum() end
obs = Math.one_hot(5, CueTask.obs_index(:cue_l))
prior = [0.0, 0.0, 0.5, 0.5, 0.0, 0.0, 0.0, 0.0]   # at the cue, context unknown

# Step 0, context unknown — the safe informative cue is strictly preferred:
bundle = CueTask.build()
DiscreteTime.choose_action(bundle, %{}, [], -1).action   # :go_cue

# Informative cue resolves the context; uninformative one does not:
inf = DiscreteTime.update_state_beliefs(nil, prior, nil, obs, bundle.a, nil, nil, 1.0)
unf = DiscreteTime.update_state_beliefs(nil, prior, nil, obs,
        CueTask.build(cue_informative: false).a, nil, nil, 1.0)
{p_left.(inf), p_left.(unf)}    # ≈ {0.98, 0.5}

# Step 1, context resolved → exploit the matching arm (explore-then-exploit):
DiscreteTime.choose_action(%{bundle | d: inf}, %{}, [], -1).action   # :go_left
```

### The five ablations (each weakens the behaviour)

| # | Ablation | Build it | Predicted effect |
|---|----------|----------|------------------|
| 1 | Uninformative cue | `CueTask.build(cue_informative: false)` | cue no longer resolves context |
| 2 | No epistemic term | `CueTask.build(efe_ambiguity: false)` | EFE drops the information term; `G` changes |
| 3 | Flatten `C` | `CueTask.build(preference_strength: 0.0)` | reward-arm action mass falls |
| 4 | Short horizon | `CueTask.build(policy_depth: 1)` | can't seek-cue-then-use |
| 5 | Dominant `E` | `CueTask.build(habit_action: :go_center, habit_strength: 8.0)` | habit overrides `G` |

## Run in the app

```
mix phx.server
# /labs?recipe=epistemic-disambiguate-before-exploit
# /labs?recipe=pomdp-forked-epistemic-win
```
