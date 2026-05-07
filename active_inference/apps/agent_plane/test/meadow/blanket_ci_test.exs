defmodule AgentPlane.Meadow.BlanketCITest do
  @moduledoc """
  AUDIT ANCHOR: inter-agent Markov blanket as CI (conditional
  independence) partition.

  Project CLAUDE.md adjudication anchor:

      "Markov blanket has three meanings (CI partition, causal/process
      diagram, inference architecture); keep them separate. Do not
      infer one from another unless justified."

  This test asserts the **CI-partition** reading at the inter-agent
  level: bird A's beliefs depend only on its own bundle and its own
  observation history — never on bird B's hidden state. This is the
  architectural property the typed Markov blanket
  (`SharedContracts.ObservationPacket` and `.ActionPacket`) enforces.

  Two complementary mechanisms verify this:

  ### 1. cmd/2 contract reflection

  `ActiveInferenceAgent.cmd(agent, action)` takes only `agent` and
  `action` — there is no parameter through which another agent's state
  could enter. Any leak would have to flow through `agent.state.bundle`
  or through the observation packet — both of which are A's own data.

  ### 2. Replay-determinism on the meadow

  Run two SimpleBirds with `:argmax` selection (no sampling
  randomness) on the meadow for N steps. Capture bird A's per-step
  beliefs (`marginal_state_belief`). Reset and re-run. With identical
  inputs, the trajectories must be **bitwise-identical**.

  Then run a *third* time with bird B replaced by a "scripted bird"
  that emits exactly the action sequence B emitted in run 1 — but with
  no internal bundle, no inference. Bird A's beliefs must again be
  bitwise-identical, because A only ever sees the world's
  ObservationPacket, which depends on B's *actions* (the blanket),
  never on B's beliefs.
  """

  use ExUnit.Case, async: false

  alias AgentPlane.{ActiveInferenceAgent, BundleBuilder.Meadow}
  alias AgentPlane.Actions.{Act, Perceive, Plan}
  alias Jido.Agent.Directive
  alias SharedContracts.{ActionPacket, Blanket}
  alias WorldPlane.Worlds.BirdMeadow

  @blanket Blanket.meadow_default()
  @grid 4

  describe "cmd/2 contract reflection" do
    test "ActiveInferenceAgent.cmd/2 exists" do
      assert function_exported?(ActiveInferenceAgent, :cmd, 2)
    end

    test "the agent's signal_routes only mention its own actions (no peer access)" do
      routes = ActiveInferenceAgent.signal_routes(%{})
      action_modules = Enum.map(routes, &elem(&1, 1))

      # Every routed action must be under AgentPlane.Actions.* — i.e., scoped
      # to this agent's own action namespace. There must be no route that
      # imports another agent's state.
      Enum.each(action_modules, fn mod ->
        prefix = Atom.to_string(mod)

        assert String.starts_with?(prefix, "Elixir.AgentPlane.Actions."),
               "signal_routes must only fire AgentPlane.Actions.* — found #{inspect(mod)}"
      end)
    end
  end

  describe "two-bird determinism (replay invariance)" do
    @tag timeout: 180_000
    test "argmax-mode birds produce bitwise-identical belief trajectories on replay" do
      # Run 1
      {beliefs_a_run1, actions_a_run1, actions_b_run1} = run_two_bird_episode(seed: 1)

      # Run 2 — same seed, same setup
      {beliefs_a_run2, actions_a_run2, actions_b_run2} = run_two_bird_episode(seed: 1)

      assert beliefs_a_run1 == beliefs_a_run2,
             "argmax replay produced different belief trajectories"

      assert actions_a_run1 == actions_a_run2
      assert actions_b_run1 == actions_b_run2
    end

    @tag timeout: 240_000
    test "replacing bird B with a scripted-actions stand-in leaves A's beliefs invariant" do
      {beliefs_a_run1, _actions_a_run1, actions_b_run1} = run_two_bird_episode(seed: 7)

      # Run 2: bird B is replaced by a scripted bird that emits the EXACT
      # action sequence B emitted in run 1. Bird A's observations are
      # therefore identical to run 1 — and so its beliefs must be too.
      beliefs_a_run2 =
        run_with_scripted_partner(seed: 7, scripted_actions: actions_b_run1)

      assert beliefs_a_run1 == beliefs_a_run2,
             "Bird A's beliefs changed when bird B's internal state was replaced " <>
               "with no-state scripted actions — CI-partition violated."
    end
  end

  # -- Helpers ----------------------------------------------------------------

  defp two_simple_bundles do
    bundle_a =
      Meadow.simple(
        width: @grid,
        height: @grid,
        preferred_token: :t1,
        action_selection: :argmax
      )

    bundle_b =
      Meadow.simple(
        width: @grid,
        height: @grid,
        preferred_token: :t1,
        action_selection: :argmax
      )

    {bundle_a, bundle_b}
  end

  defp run_two_bird_episode(opts) do
    seed = Keyword.fetch!(opts, :seed)
    :rand.seed(:exsss, {seed, seed, seed})

    {:ok, meadow} = BirdMeadow.start_link(width: @grid, height: @grid)
    {bundle_a, bundle_b} = two_simple_bundles()

    :ok = BirdMeadow.add_bird(meadow, "alice", {0, 0})
    :ok = BirdMeadow.add_bird(meadow, "bob", {3, 3})

    agent_a = ActiveInferenceAgent.fresh("alice", bundle_a, @blanket)
    agent_b = ActiveInferenceAgent.fresh("bob", bundle_b, @blanket)

    {beliefs_a, actions_a, actions_b, _, _} =
      Enum.reduce(1..6, {[], [], [], agent_a, agent_b}, fn _t,
                                                           {b_acc, aa_acc, ab_acc, agent_a,
                                                            agent_b} ->
        {:ok, obs_a} = BirdMeadow.observe(meadow, "alice")
        {:ok, obs_b} = BirdMeadow.observe(meadow, "bob")

        {agent_a2, action_a} = perceive_plan_act(agent_a, obs_a)
        {agent_b2, action_b} = perceive_plan_act(agent_b, obs_b)

        actions = %{
          "alice" =>
            ActionPacket.new(%{t: 0, action: action_a, agent_id: "alice", blanket: @blanket}),
          "bob" => ActionPacket.new(%{t: 0, action: action_b, agent_id: "bob", blanket: @blanket})
        }

        {:ok, _} = BirdMeadow.multi_step(meadow, actions)

        {[agent_a2.state.marginal_state_belief | b_acc], [action_a | aa_acc], [action_b | ab_acc],
         agent_a2, agent_b2}
      end)

    GenServer.stop(meadow)

    {Enum.reverse(beliefs_a), Enum.reverse(actions_a), Enum.reverse(actions_b)}
  end

  defp run_with_scripted_partner(opts) do
    seed = Keyword.fetch!(opts, :seed)
    scripted = Keyword.fetch!(opts, :scripted_actions)
    :rand.seed(:exsss, {seed, seed, seed})

    {:ok, meadow} = BirdMeadow.start_link(width: @grid, height: @grid)
    {bundle_a, _} = two_simple_bundles()

    :ok = BirdMeadow.add_bird(meadow, "alice", {0, 0})
    :ok = BirdMeadow.add_bird(meadow, "bob", {3, 3})

    agent_a = ActiveInferenceAgent.fresh("alice", bundle_a, @blanket)

    {beliefs_a, _final_a} =
      scripted
      |> Enum.with_index()
      |> Enum.reduce({[], agent_a}, fn {scripted_b_action, _i}, {b_acc, agent_a} ->
        {:ok, obs_a} = BirdMeadow.observe(meadow, "alice")
        {agent_a2, action_a} = perceive_plan_act(agent_a, obs_a)

        actions = %{
          "alice" =>
            ActionPacket.new(%{t: 0, action: action_a, agent_id: "alice", blanket: @blanket}),
          "bob" =>
            ActionPacket.new(%{
              t: 0,
              action: scripted_b_action,
              agent_id: "bob",
              blanket: @blanket
            })
        }

        {:ok, _} = BirdMeadow.multi_step(meadow, actions)
        {[agent_a2.state.marginal_state_belief | b_acc], agent_a2}
      end)

    GenServer.stop(meadow)
    Enum.reverse(beliefs_a)
  end

  defp perceive_plan_act(agent, obs) do
    {a1, _} = ActiveInferenceAgent.cmd(agent, {Perceive, %{observation: obs}})
    {a2, _} = ActiveInferenceAgent.cmd(a1, Plan)
    {a3, dirs} = ActiveInferenceAgent.cmd(a2, Act)

    action =
      case Enum.find(dirs || [], &match?(%Directive.Emit{}, &1)) do
        %Directive.Emit{signal: %{data: %{action: a}}} -> a
        _ -> a3.state.last_action
      end

    {a3, action}
  end
end
