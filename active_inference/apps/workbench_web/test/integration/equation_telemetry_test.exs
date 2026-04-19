defmodule WorkbenchWeb.EquationTelemetryTest do
  @moduledoc """
  Plan §12 Phase 4 end-to-end — an Episode step should produce
  `equation.evaluated` events on the bus + persist them to Mnesia, each
  tagged with the specific equation_id that drove the computation.
  """

  use WorldModels.MnesiaCase, async: false

  alias AgentPlane.{BundleBuilder, JidoInstance, Runtime}
  alias SharedContracts.Blanket
  alias WorkbenchWeb.Episode
  alias WorldModels.{Bus, EventLog}
  alias WorldModels.EventLog.Setup
  alias WorldPlane.Worlds

  setup _ do
    :ok = Setup.ensure_schema!()
    start_supervised!({Phoenix.PubSub, name: WorldModels.Bus})

    JidoInstance.list_agents()
    |> Enum.each(fn {id, _pid} -> Runtime.stop_agent(id) end)

    :ok
  end

  test "equation.evaluated events fire per DiscreteTime call during a step" do
    agent_id = "agent-equation-telemetry"
    :ok = Bus.subscribe_agent(agent_id)

    {:ok, pid} = start_episode(agent_id, "spec-equation-telemetry")

    {:ok, _entry} = Episode.step(pid)

    events = EventLog.query(agent_id: agent_id)
    eq_events = Enum.filter(events, &(&1.type == "equation.evaluated"))

    assert length(eq_events) > 0,
           "no equation.evaluated events; got: #{inspect(Enum.map(events, & &1.type))}"

    # Every equation.evaluated must carry a real equation_id and full provenance.
    Enum.each(eq_events, fn e ->
      eq = e.provenance.equation_id
      assert is_binary(eq), "missing equation_id in #{inspect(e)}"
      assert %ActiveInferenceCore.Equation{} = ActiveInferenceCore.Equations.fetch(eq)

      assert e.provenance.spec_id == "spec-equation-telemetry"
      assert is_binary(e.provenance.bundle_id)

      assert e.provenance.family_id ==
               "Partially Observable Markov Decision Process (POMDP)"

      assert e.data.module == "ActiveInferenceCore.DiscreteTime"
      assert is_atom(e.data.fn_name)
    end)

    # Per-step we expect at least: one sweep_state_beliefs (Perceive),
    # one choose_action (Plan), plus the inner vfe/efe/policy_posterior
    # spans it fans out to.
    fn_names = Enum.map(eq_events, & &1.data.fn_name) |> Enum.uniq()

    assert :sweep_state_beliefs in fn_names
    assert :choose_action in fn_names
    assert :policy_posterior in fn_names

    :ok = Episode.stop(pid)
  end

  defp start_episode(agent_id, spec_id) do
    world = Worlds.tiny_open_goal()
    blanket = Blanket.maze_default()

    walls =
      world.grid
      |> Enum.filter(fn {_, t} -> t == :wall end)
      |> Enum.map(fn {{c, r}, _} -> r * world.width + c end)

    start_idx = elem(world.start, 1) * world.width + elem(world.start, 0)
    goal_idx = elem(world.goal, 1) * world.width + elem(world.goal, 0)

    bundle =
      BundleBuilder.for_maze(
        width: world.width,
        height: world.height,
        start_idx: start_idx,
        goal_idx: goal_idx,
        walls: walls,
        blanket: blanket,
        horizon: 3,
        policy_depth: 3,
        spec_id: spec_id
      )

    Episode.start_link(
      session_id: "session-equation-telemetry",
      maze: world,
      blanket: blanket,
      bundle: bundle,
      agent_id: agent_id,
      max_steps: 8,
      goal_idx: goal_idx,
      mode: :pure
    )
  end
end
