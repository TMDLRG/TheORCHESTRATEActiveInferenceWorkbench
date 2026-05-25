defmodule AgentPlane.BundleBuilder.CueTaskTest do
  @moduledoc """
  W-6 — the Week-12 capstone: a cue-guided T-maze and its five ablations.

  Faithful to the spec's *corrected* claim — explore-then-exploit is NOT
  automatic; it depends on task structure and parameters. Here it emerges
  robustly in the **loss-averse regime**: when gambling on an arm under unknown
  context risks a costly loss, the safe informative cue is strictly preferred,
  and once the cue resolves the context the formerly-risky arm becomes safe and
  the agent exploits it. We assert the full step0-cue → step1-exploit loop plus
  the five ablations.

  One honest caveat (flagged to UNI). Cue-seeking in this engine is
  **risk-driven** (it follows from a loss-averse `C`), not **ambiguity-driven**.
  With near-deterministic likelihoods the EFE ambiguity term is ≈ 0, so ablation
  2 (drop the ambiguity term) changes `G` numerically but does NOT weaken
  cue-seeking — ablation 3 (flatten `C`, removing the risk gradient) is what
  abolishes it. Matching the spec's ablation 2 to the letter (ambiguity-driven
  cue-seeking) would need an ambiguity-structured task or an explicit salience
  term; that choice is in the UNI packet.
  """
  use ExUnit.Case, async: true

  alias ActiveInferenceCore.{DiscreteTime, Math}
  alias AgentPlane.BundleBuilder.CueTask

  defp p_left(belief),
    do: CueTask.left_context_states() |> Enum.map(&Enum.at(belief, &1)) |> Enum.sum()

  describe "ablation 1 — cue informativeness" do
    test "an informative cue sharpens the context belief; an uninformative one does not" do
      prior = [0.0, 0.0, 0.5, 0.5, 0.0, 0.0, 0.0, 0.0]
      obs = Math.one_hot(5, CueTask.obs_index(:cue_l))

      post_inf =
        DiscreteTime.update_state_beliefs(
          nil,
          prior,
          nil,
          obs,
          CueTask.build(cue_informative: true).a,
          nil,
          nil,
          1.0
        )

      post_unf =
        DiscreteTime.update_state_beliefs(
          nil,
          prior,
          nil,
          obs,
          CueTask.build(cue_informative: false).a,
          nil,
          nil,
          1.0
        )

      assert p_left(post_inf) > 0.9
      assert_in_delta p_left(post_unf), 0.5, 0.05
    end
  end

  describe "exploit — context known ⇒ pursue the matching arm" do
    test "the agent heads to the arm that pays out in the known context" do
      left = %{CueTask.build() | d: [1.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0]}
      right = %{CueTask.build() | d: [0.0, 1.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0]}

      assert DiscreteTime.choose_action(left, %{}, [], -1).action == :go_left
      assert DiscreteTime.choose_action(right, %{}, [], -1).action == :go_right
    end
  end

  describe "ablation 3 — preference (flatten C)" do
    test "flat C abolishes cue-seeking and weakens reward pursuit" do
      # Cue-seeking vanishes: with no risk gradient the safe cue stops dominating.
      sharp0 = DiscreteTime.choose_action(CueTask.build(), %{}, [], -1).action_marginal

      flat0 =
        DiscreteTime.choose_action(CueTask.build(preference_strength: 0.0), %{}, [], -1).action_marginal

      assert Map.get(sharp0, :go_cue) > Map.get(flat0, :go_cue) + 0.1

      # Reward pursuit weakens: with the context known, reward-arm mass drops.
      ctx_l = [1.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0]

      m_sharp =
        DiscreteTime.choose_action(%{CueTask.build() | d: ctx_l}, %{}, [], -1).action_marginal

      m_flat =
        DiscreteTime.choose_action(
          %{CueTask.build(preference_strength: 0.0) | d: ctx_l},
          %{},
          [],
          -1
        ).action_marginal

      assert Map.get(m_sharp, :go_left, 0.0) > Map.get(m_flat, :go_left, 0.0)
    end
  end

  describe "ablation 5 — habit (dominant E)" do
    test "a strong habit prior overrides G" do
      ctx_l = [1.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0]

      base = %{CueTask.build() | d: ctx_l}
      assert DiscreteTime.choose_action(base, %{}, [], -1).action == :go_left

      habit = %{CueTask.build(habit_action: :go_center, habit_strength: 8.0) | d: ctx_l}
      assert DiscreteTime.choose_action(habit, %{}, [], -1).action == :go_center
    end
  end

  describe "ablation 4 — horizon (too short to cue then use)" do
    test "depth-1 cannot represent seek-cue-then-visit-arm; depth-2 can" do
      depth1 = CueTask.build(policy_depth: 1)
      assert Enum.all?(depth1.policies, &(length(&1) == 1))

      refute Enum.any?(depth1.policies, fn p ->
               :go_cue in p and (:go_left in p or :go_right in p)
             end)

      depth2 = CueTask.build(policy_depth: 2)
      assert Enum.any?(depth2.policies, &(&1 == [:go_cue, :go_left]))
    end
  end

  describe "ablation 2 — epistemic term (EFE ambiguity toggle)" do
    test "the ambiguity toggle changes G numerically" do
      # NOTE: cue-seeking here is risk-driven (see moduledoc), so dropping the
      # ambiguity term does not abolish it — but it does change G, and the toggle
      # is the gate-2 lever the spec's ablation 2 names.
      g_with = DiscreteTime.choose_action(CueTask.build(efe_ambiguity: true), %{}, [], -1).g
      g_without = DiscreteTime.choose_action(CueTask.build(efe_ambiguity: false), %{}, [], -1).g
      refute g_with == g_without
    end
  end

  describe "explore-then-exploit (loss-averse regime)" do
    test "step 0 prefers the cue; after observing it the agent exploits the right arm" do
      bundle = CueTask.build()

      # Step 0 — context unknown — the safe, informative cue is strictly preferred
      # over gambling on an arm (the loss-averse C makes the gamble worse).
      res0 = DiscreteTime.choose_action(bundle, %{}, [], -1)
      assert res0.action == :go_cue

      assert Map.get(res0.action_marginal, :go_cue) >
               Map.get(res0.action_marginal, :go_left) + 0.05

      # Observe the cue (cue_l) — the context belief sharpens to ctx = l.
      obs = Math.one_hot(5, CueTask.obs_index(:cue_l))

      belief =
        DiscreteTime.update_state_beliefs(
          nil,
          [0.0, 0.0, 0.5, 0.5, 0.0, 0.0, 0.0, 0.0],
          nil,
          obs,
          bundle.a,
          nil,
          nil,
          1.0
        )

      assert p_left(belief) > 0.9

      # Step 1 — context resolved — the formerly-risky arm is now safe; exploit it.
      assert DiscreteTime.choose_action(%{bundle | d: belief}, %{}, [], -1).action == :go_left
    end
  end
end
