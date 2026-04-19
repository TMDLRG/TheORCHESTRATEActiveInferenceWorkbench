# Plan §12 Phase 5 runtime observation.
#
# Registers a Spec via WorldModels.AgentRegistry, boots a supervised
# agent under that spec, runs an Episode, then demonstrates the full
# round-trip that the Glass Engine and Builder will rely on:
#   - spec_id  → fetch_spec  → canonical content
#   - spec_id  → live_for_spec → [agent_id]
#   - agent_id → fetch_live   → {spec_id, pid, started_at}
#   - event    → provenance.spec_id → back to the builder spec

Process.sleep(300)

alias AgentPlane.{BundleBuilder, Runtime}
alias SharedContracts.Blanket
alias WorkbenchWeb.Episode
alias WorldModels.{AgentRegistry, EventLog, Spec}
alias WorldPlane.Worlds

world = Worlds.tiny_open_goal()
blanket = Blanket.maze_default()
walls = world.grid |> Enum.filter(fn {_, t} -> t == :wall end) |> Enum.map(fn {{c, r}, _} -> r * world.width + c end)
start_idx = elem(world.start, 1) * world.width + elem(world.start, 0)
goal_idx = elem(world.goal, 1) * world.width + elem(world.goal, 0)

# 1. Builder → AgentRegistry: register a Spec for this composition.
spec =
  Spec.new(%{
    id: "spec-phase5-observe",
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
    created_by: "phase5_observe"
  })

{:ok, registered} = AgentRegistry.register_spec(spec)

IO.puts("=== Registered Spec ===")
IO.puts("  id:              #{registered.id}")
IO.puts("  archetype_id:    #{registered.archetype_id}")
IO.puts("  family_id:       #{registered.family_id}")
IO.puts("  hash:            #{registered.hash}")
IO.puts("  equations:       #{length(registered.primary_equation_ids)}")

# 2. Build bundle tagged with the spec_id so agent state, signals, and the
#    registry all point at the same composition.
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
    spec_id: registered.id
  )

agent_id = "agent-phase5-observe"

{:ok, pid} =
  Episode.start_link(
    session_id: "session-phase5-observe",
    maze: world,
    blanket: blanket,
    bundle: bundle,
    agent_id: agent_id,
    max_steps: 8,
    goal_idx: goal_idx,
    mode: :supervised
  )

# 3. Spec → live_for_spec round-trip.
live = AgentRegistry.live_for_spec(registered.id)
IO.puts("\n=== live_for_spec(\"#{registered.id}\") ===")
Enum.each(live, fn aid -> IO.puts("  #{aid}") end)

# 4. agent_id → fetch_live.
{:ok, live_row} = AgentRegistry.fetch_live(agent_id)
IO.puts("\n=== fetch_live(\"#{agent_id}\") ===")
IO.puts("  spec_id:         #{live_row.spec_id}")
IO.puts("  pid:             #{inspect(live_row.pid)}")
IO.puts("  started_at_usec: #{live_row.started_at_usec}")

# 5. Run the episode to completion.
drain = fn d ->
  case Episode.step(pid) do
    {:ok, _} -> d.(d)
    {:done, s} -> s
    {:error, _} -> :err
  end
end

summary = drain.(drain)

IO.puts("\n=== Episode result ===")
IO.puts("  goal reached?: #{summary.goal_reached?}")
IO.puts("  steps:         #{summary.steps}")

# 6. Pick a random `agent.action_emitted` event and back-trace it to the Spec.
events = EventLog.query(agent_id: agent_id)
action_event = Enum.find(events, &(&1.type == "agent.action_emitted"))

IO.puts("\n=== Back-trace: event → spec ===")
IO.puts("  event:         #{action_event.type} @ t=#{action_event.ts_usec}")
IO.puts("  agent_id:      #{action_event.provenance.agent_id}")
IO.puts("  bundle_id:     #{action_event.provenance.bundle_id}")
IO.puts("  family_id:     #{action_event.provenance.family_id}")
IO.puts("  spec_id:       #{action_event.provenance.spec_id}")

case AgentRegistry.fetch_spec(action_event.provenance.spec_id) do
  {:ok, resolved} ->
    IO.puts("  → resolved:    Spec[#{resolved.id}] (hash=#{resolved.hash})")
    IO.puts("  → archetype:   #{resolved.archetype_id}")
    IO.puts("  → hash match?  #{resolved.hash == registered.hash}")

  :error ->
    IO.puts("  → UNRESOLVED")
end

# 7. Stop + detach.
:ok = Episode.stop(pid)

live_after = AgentRegistry.live_for_spec(registered.id)
IO.puts("\n=== after Episode.stop ===")
IO.puts("  live_for_spec: #{inspect(live_after)}  (should be [])")

# Prove specs survive across a Mnesia stop/start within this BEAM.
IO.puts("\n=== durability ===")
:stopped = :mnesia.stop()
:ok = :mnesia.start()
:ok = :mnesia.wait_for_tables([:world_models_specs], 5_000)

{:ok, reloaded} = AgentRegistry.fetch_spec(registered.id)
IO.puts("  reloaded after mnesia restart → id=#{reloaded.id}, hash=#{reloaded.hash}")
IO.puts("  hash stable?   #{reloaded.hash == registered.hash}")

:stopped = :mnesia.stop()
System.halt(0)
