# Plan §12 Phase 6 runtime observation.
#
# Boots an in-process Episode the way /world's `create_episode` handler
# does, then curls /glass/agent/:id against the running endpoint to prove
# the Builder → Runtime → Glass handoff is observable without any UI
# clicks required.

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

spec_id = "spec-world-" <> (:crypto.strong_rand_bytes(4) |> Base.url_encode64(padding: false))

{:ok, spec} =
  AgentRegistry.register_spec(
    Spec.new(%{
      id: spec_id,
      archetype_id: "pomdp_maze",
      family_id: "Partially Observable Markov Decision Process (POMDP)",
      primary_equation_ids: [
        "eq_4_5_pomdp_likelihood",
        "eq_4_6_pomdp_prior_over_states",
        "eq_4_10_efe_linear_algebra",
        "eq_4_11_vfe_linear_algebra",
        "eq_4_13_state_belief_update",
        "eq_4_14_policy_posterior"
      ],
      bundle_params: %{horizon: 3, policy_depth: 3, preference_strength: 4.0},
      blanket: %{
        observation_channels: blanket.observation_channels,
        action_vocabulary: blanket.action_vocabulary
      },
      created_by: "phase6_observe"
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
    horizon: 3,
    policy_depth: 3,
    spec_id: spec.id
  )

agent_id = "agent-phase6-live"

{:ok, pid} =
  Episode.start_link(
    session_id: "session-phase6-live",
    maze: world,
    blanket: blanket,
    bundle: bundle,
    agent_id: agent_id,
    max_steps: 8,
    goal_idx: goal_idx,
    mode: :pure
  )

:ok = AgentRegistry.attach_live(agent_id, spec.id)

Bus.subscribe_agent(agent_id)

# Step the agent a few times so Mnesia fills with events the Glass stub
# can render.
drain = fn d ->
  case Episode.step(pid) do
    {:ok, _} -> d.(d)
    {:done, s} -> s
    {:error, _} -> :err
  end
end

summary = drain.(drain)

IO.puts("=== Spec registered ===")
IO.puts("  id:   #{spec.id}")
IO.puts("  hash: #{spec.hash}")

IO.puts("\n=== Episode ===")
IO.puts("  goal reached?: #{summary.goal_reached?}")
IO.puts("  steps:         #{summary.steps}")

IO.puts("\n=== Live agent URL ===")
IO.puts("  http://localhost:4000/glass/agent/#{agent_id}")

# Keep the BEAM alive so the endpoint + mnesia are there for curl.
# The caller is expected to curl then kill this process.
Process.sleep(2_000)
IO.puts("\n=== Mnesia write delay elapsed ===")

# Stop cleanly so the disk log is flushed.
:ok = Episode.stop(pid)
:stopped = :mnesia.stop()
System.halt(0)
