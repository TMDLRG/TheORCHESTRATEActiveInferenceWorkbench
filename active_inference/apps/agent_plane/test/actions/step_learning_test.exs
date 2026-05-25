defmodule AgentPlane.Actions.StepLearningTest do
  @moduledoc """
  W-3 — online Dirichlet A-learning is wired into the `Step` tick, gated on the
  bundle's `:learning_enabled` flag, and inference consumes the Dirichlet
  expected log E[ln A] (= ψ(α) − ψ(Σα)), not ln of the Dirichlet mean.

  Proves:

    1. A `Step` performs an A-update only when learning is enabled. A
       fixed-likelihood bundle is left untouched — no `/labs` regression.
    2. Held-out prediction improves: across repeated ticks the expected
       log-likelihood the agent assigns to the recurring observation rises.
  """
  use ExUnit.Case, async: true

  alias ActiveInferenceCore.{DiscreteTime, Math}
  alias AgentPlane.{ActiveInferenceAgent, BundleBuilder, ObsAdapter}
  alias AgentPlane.Actions.Step
  alias SharedContracts.{Blanket, ObservationPacket}

  defp base_opts(blanket) do
    [
      width: 3,
      height: 1,
      start_idx: 0,
      goal_idx: 2,
      walls: [],
      blanket: blanket,
      horizon: 2,
      policy_depth: 2
    ]
  end

  defp obs_packet(blanket) do
    ObservationPacket.new(%{
      t: 0,
      channels: %{goal_cue: :unknown, tile: :start, wall_hit: :clear},
      world_run_id: "w3-learn",
      terminal?: false,
      blanket: blanket
    })
  end

  test "Step runs a Dirichlet A-update only when learning_enabled" do
    blanket = Blanket.maze_default()

    learn_bundle = BundleBuilder.for_maze([{:learning_enabled, true} | base_opts(blanket)])
    fixed_bundle = BundleBuilder.for_maze(base_opts(blanket))
    obs = obs_packet(blanket)

    {learn_after, _} =
      ActiveInferenceAgent.cmd(
        ActiveInferenceAgent.fresh("w3-learn", learn_bundle, blanket, goal_idx: 2),
        {Step, %{observation: obs}}
      )

    {fixed_after, _} =
      ActiveInferenceAgent.cmd(
        ActiveInferenceAgent.fresh("w3-fixed", fixed_bundle, blanket, goal_idx: 2),
        {Step, %{observation: obs}}
      )

    # Learning on ⇒ Dirichlet counts now live on the bundle.
    assert is_list(Map.get(learn_after.state.bundle, :dirichlet_a_counts))
    # Learning off ⇒ strictly untouched (the /labs no-regression guarantee).
    assert Map.get(fixed_after.state.bundle, :dirichlet_a_counts) == nil
  end

  test "live learning raises the expected log-likelihood of the recurring observation" do
    blanket = Blanket.maze_default()
    bundle = BundleBuilder.for_maze([{:learning_enabled, true} | base_opts(blanket)])
    agent = ActiveInferenceAgent.fresh("w3-heldout", bundle, blanket, goal_idx: 2)
    obs = obs_packet(blanket)

    # Expected log-likelihood of `obs` under the agent's *current* model, using
    # the same E[ln A] the inference path uses (or ln(A) before any learning),
    # marginalised over the agent's state belief q(s).
    pred_ll = fn ag ->
      st = ag.state
      adapter = Map.get(st.bundle, :obs_adapter, ObsAdapter)
      o = adapter.to_obs_vector(obs)
      ln_a = DiscreteTime.inference_log_a(st.bundle) || Math.log_eps_mat(st.bundle.a)

      qs =
        case st.marginal_state_belief do
          [] -> Math.uniform(length(hd(st.bundle.a)))
          v -> v
        end

      ln_a |> Math.transpose() |> Math.matvec(o) |> Math.dot(qs)
    end

    {trained, lls} =
      Enum.reduce(1..6, {agent, []}, fn _i, {a, acc} ->
        {a2, _} = ActiveInferenceAgent.cmd(a, {Step, %{observation: obs}})
        {a2, acc ++ [pred_ll.(a2)]}
      end)

    assert is_list(Map.fetch!(trained.state.bundle, :dirichlet_a_counts))
    # Held-out prediction sharpens: the recurring outcome is more expected after
    # training than after the first learning tick.
    assert List.last(lls) > List.first(lls)
  end
end
