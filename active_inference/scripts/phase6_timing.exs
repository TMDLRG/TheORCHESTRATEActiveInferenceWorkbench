Process.sleep(300)
alias AgentPlane.BundleBuilder
alias SharedContracts.Blanket
alias WorkbenchWeb.Episode
alias WorldModels.{AgentRegistry, Bus, Spec}
alias WorldPlane.Worlds

world = Worlds.tiny_open_goal()
blanket = Blanket.maze_default()

walls =
  world.grid
  |> Enum.filter(fn {_, t} -> t == :wall end)
  |> Enum.map(fn {{c, r}, _} -> r * world.width + c end)

start_idx = elem(world.start, 1) * world.width + elem(world.start, 0)
goal_idx = elem(world.goal, 1) * world.width + elem(world.goal, 0)

{:ok, _} =
  AgentRegistry.register_spec(
    Spec.new(%{
      id: "spec-timing",
      archetype_id: "pomdp_maze",
      family_id: "POMDP",
      primary_equation_ids: ["eq_4_14_policy_posterior"],
      bundle_params: %{},
      blanket: %{}
    })
  )

bundle =
  BundleBuilder.for_maze(
    width: world.width,
    height: world.height,
    start_idx: start_idx,
    goal_idx: goal_idx,
    walls: walls,
    blanket: blanket,
    horizon: 5,
    policy_depth: 5,
    spec_id: "spec-timing"
  )

{:ok, pid} =
  Episode.start_link(
    session_id: "session-timing",
    maze: world,
    blanket: blanket,
    bundle: bundle,
    agent_id: "agent-timing",
    max_steps: 8,
    goal_idx: goal_idx,
    mode: :pure
  )

Bus.subscribe_agent("agent-timing")

t0 = System.monotonic_time(:millisecond)
{:ok, _} = Episode.step(pid)
t1 = System.monotonic_time(:millisecond)

IO.puts("Episode.step (horizon=5, policy_depth=5): #{t1 - t0}ms")

:stopped = :mnesia.stop()
System.halt(0)
