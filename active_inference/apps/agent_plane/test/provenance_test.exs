defmodule AgentPlane.ProvenanceTest do
  @moduledoc """
  Plan §12 Phase 1 — closes GAP-P1, GAP-P2, GAP-P3.

  Bundles, agent state, and emitted signals must carry provenance linking
  every live artifact back to the model taxonomy + equation registry.
  """

  use ExUnit.Case, async: true

  alias ActiveInferenceCore.Equations
  alias AgentPlane.ActiveInferenceAgent
  alias AgentPlane.Actions.{Act, Perceive, Plan}
  alias AgentPlane.BundleBuilder
  alias Jido.Agent.Directive.Emit
  alias SharedContracts.Blanket
  alias WorldPlane.Worlds

  describe "T1: bundle provenance (GAP-P2)" do
    test "for_maze/1 bundle carries provenance fields" do
      bundle = build_bundle()

      assert is_binary(bundle.bundle_id)
      assert String.starts_with?(bundle.bundle_id, "bundle-")

      assert bundle.family_id == "Partially Observable Markov Decision Process (POMDP)"

      assert is_list(bundle.primary_equation_ids)
      assert Enum.all?(bundle.primary_equation_ids, &is_binary/1)

      # Every listed equation ID must actually resolve in the registry.
      Enum.each(bundle.primary_equation_ids, fn eq_id ->
        assert %{} = Equations.fetch(eq_id),
               "bundle references unknown equation #{eq_id}"
      end)

      assert bundle.verification_status in [
               :verified_against_source,
               :verified_against_source_and_appendix,
               :extracted_uncertain,
               :unverified
             ]
    end

    test "explicit :spec_id opt is carried into bundle" do
      bundle = build_bundle(spec_id: "spec-test-123")
      assert bundle.spec_id == "spec-test-123"
    end

    test "omitted :spec_id defaults to nil (spec binding comes in Phase 5)" do
      bundle = build_bundle()
      assert bundle.spec_id == nil
    end

    test "two bundles built back-to-back get distinct bundle_ids" do
      b1 = build_bundle()
      b2 = build_bundle()
      assert b1.bundle_id != b2.bundle_id
    end
  end

  describe "T2: agent state provenance (GAP-P3)" do
    test "ActiveInferenceAgent.fresh/4 copies provenance from bundle into state" do
      bundle = build_bundle(spec_id: "spec-xyz")
      blanket = Blanket.maze_default()

      agent = ActiveInferenceAgent.fresh("agent-prov", bundle, blanket, goal_idx: 5)

      assert agent.state.bundle_id == bundle.bundle_id
      assert agent.state.spec_id == "spec-xyz"
      assert agent.state.family_id == bundle.family_id
      assert agent.state.primary_equation_ids == bundle.primary_equation_ids
      assert agent.state.verification_status == bundle.verification_status
    end
  end

  describe "T3: emitted Jido.Signal provenance (GAP-P1)" do
    test "Act emits a signal whose data carries equation_id + full provenance" do
      agent =
        build_bundle(spec_id: "spec-emit")
        |> then(fn bundle ->
          ActiveInferenceAgent.fresh("agent-emit", bundle, Blanket.maze_default(), goal_idx: 4)
        end)

      # Walk through Perceive → Plan → Act so Act has a :last_action to emit.
      obs_packet =
        SharedContracts.ObservationPacket.new(%{
          t: 0,
          channels: %{goal_cue: :not_here},
          world_run_id: "run-test",
          terminal?: false,
          blanket: agent.state.blanket
        })

      {a1, _} = ActiveInferenceAgent.cmd(agent, {Perceive, %{observation: obs_packet}})
      {a2, _} = ActiveInferenceAgent.cmd(a1, Plan)
      {_a3, dirs} = ActiveInferenceAgent.cmd(a2, Act)

      emit = Enum.find(dirs, &match?(%Emit{}, &1))
      assert emit, "Act must return at least one %Directive.Emit{}"

      data = emit.signal.data

      # GAP-P1: every emission is grounded in an explicit equation.
      assert data.equation_id == "eq_4_14_policy_posterior"

      assert %{} = Equations.fetch(data.equation_id),
             "emitted equation_id must resolve in the registry"

      # Full provenance tuple must ride along.
      assert data.spec_id == "spec-emit"
      assert is_binary(data.bundle_id)
      assert data.family_id == "Partially Observable Markov Decision Process (POMDP)"
      assert is_list(data.f)
      assert is_list(data.g)
      assert is_list(data.policy_posterior)
      assert is_integer(data.best_policy_index)

      # Existing pre-provenance fields must still be present (no regression).
      assert is_atom(data.action)
      assert is_integer(data.t)
      assert data.agent_id == "agent-emit"
    end
  end

  describe "T4: preserve native JIDO guarantees" do
    test "agent is still a %Jido.Agent{agent_module: ActiveInferenceAgent}" do
      bundle = build_bundle()
      agent = ActiveInferenceAgent.fresh("agent-native", bundle, Blanket.maze_default())

      assert agent.__struct__ == Jido.Agent
      assert agent.agent_module == ActiveInferenceAgent
    end
  end

  # -- Helpers ---------------------------------------------------------------

  defp build_bundle(extra \\ []) do
    world = Worlds.tiny_open_goal()
    blanket = Blanket.maze_default()

    walls =
      world.grid
      |> Enum.filter(fn {_, t} -> t == :wall end)
      |> Enum.map(fn {{c, r}, _} -> r * world.width + c end)

    start_idx = elem(world.start, 1) * world.width + elem(world.start, 0)
    goal_idx = elem(world.goal, 1) * world.width + elem(world.goal, 0)

    opts =
      [
        width: world.width,
        height: world.height,
        start_idx: start_idx,
        goal_idx: goal_idx,
        walls: walls,
        blanket: blanket,
        horizon: 3,
        policy_depth: 3
      ] ++ extra

    BundleBuilder.for_maze(opts)
  end
end
