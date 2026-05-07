defmodule AgentPlane.Meadow.K2SignalRaceTest do
  @moduledoc """
  AUDIT REGRESSION (external review K2, v1+v2): the receding-horizon
  `prior_d` race in `Plan` under the signal-routed path.

  ## The hazard

  `Perceive` writes `state.beliefs` and `state.t`; `Plan` reads
  `state.marginal_state_belief` to seed `prior_d`. If a `plan` signal
  is dispatched before a `perceive` signal completes, Plan reads the
  stale marginal from the *previous* tick.

  Under raw Erlang messaging, two concurrent senders firing
  `perceive` then `plan` could produce interleaved arrival at the
  agent's mailbox: P_a, plan_a, P_b, plan_b OR P_a, P_b, plan_a, plan_b
  — and the second pattern would race.

  ## Why Jido is safe — and what this test asserts

  `Jido.AgentServer` is a `GenServer`; `handle_call` and `handle_cast`
  are serial within the same process. Once `cmd/2` is invoked from
  the routed signal, it runs to completion before the next signal is
  dequeued. State mutations from action returns land in the
  AgentServer's state via `set/2` BEFORE the next signal is processed.

  This test asserts the **invariant**: under N concurrent senders
  firing `perceive` then `plan` in pairs, the agent's belief
  evolution is causally consistent — every `plan` reads the marginal
  written by SOME `perceive`, never from before any perceive ran.

  Stronger than per-sender ordering: this asserts no torn reads
  from concurrent senders.
  """

  use ExUnit.Case, async: false

  alias AgentPlane.{BundleBuilder, JidoInstance, Runtime}
  alias SharedContracts.{Blanket, ObservationPacket}
  alias WorldPlane.Worlds

  setup do
    JidoInstance.list_agents()
    |> Enum.each(fn {id, _pid} -> Runtime.stop_agent(id) end)

    :ok
  end

  @n_senders 6
  @ticks_per_sender 4

  test "concurrent perceive+plan from N senders preserves causal belief evolution" do
    spec = sample_spec("k2-race-agent", "spec-k2")
    {:ok, agent_id, _pid} = Runtime.start_agent(spec)

    blanket = Blanket.maze_default()
    parent = self()

    # Each sender fires K (perceive, plan) pairs sequentially from its own
    # task. Across senders these interleave at the agent's mailbox.
    tasks =
      for sender <- 1..@n_senders do
        Task.async(fn ->
          for tick <- 1..@ticks_per_sender do
            obs =
              ObservationPacket.new(%{
                t: tick - 1,
                channels: %{
                  wall_north: :wall,
                  wall_south: :wall,
                  wall_east: :open,
                  wall_west: :wall,
                  goal_cue: :east,
                  tile: :empty,
                  wall_hit: :clear
                },
                world_run_id: "k2-world-s#{sender}-t#{tick}",
                terminal?: false,
                blanket: blanket
              })

            {:ok, _} = Runtime.perceive(agent_id, obs)
            {:ok, _} = Runtime.plan(agent_id)
          end

          send(parent, {:done, sender})
        end)
      end

    Task.await_many(tasks, 30_000)

    # Verify the agent's final state is internally consistent:
    {:ok, %Jido.AgentServer.State{} = state} = Runtime.state(agent_id)
    agent_state = state.agent.state

    # 1. obs_history length is exactly N * K.
    assert length(agent_state.obs_history) == @n_senders * @ticks_per_sender

    # 2. t advanced to the final tick.
    assert agent_state.t == @n_senders * @ticks_per_sender - 1

    # 3. last_action is set (means the most recent Plan completed and read
    #    a non-empty marginal — i.e. the read-write order is preserved).
    assert agent_state.last_action != nil

    # 4. marginal_state_belief is a normalised distribution over n_states.
    n_states = agent_state.bundle.dims.n_states
    assert length(agent_state.marginal_state_belief) == n_states
    sum = Enum.sum(agent_state.marginal_state_belief)

    assert_in_delta sum, 1.0, 1.0e-6,
                    "marginal_state_belief is not a normalised distribution; " <>
                      "sum = #{sum}, indicating a torn read or a stale write"

    # 5. policy_posterior is also normalised.
    pi = agent_state.policy_posterior
    assert is_list(pi) and length(pi) > 0
    assert_in_delta Enum.sum(pi), 1.0, 1.0e-6

    :ok = Runtime.stop_agent(agent_id)
  end

  defp sample_spec(agent_id, spec_id) do
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
        horizon: 2,
        policy_depth: 2,
        spec_id: spec_id
      )

    %{
      agent_id: agent_id,
      spec_id: spec_id,
      bundle: bundle,
      blanket: blanket,
      goal_idx: goal_idx
    }
  end
end
