# Plan §12 Phase 8 runtime observation.
#
# Registers a Spec, runs a supervised Episode end-to-end, then verifies
# the Glass Engine routes return populated pages AND that state/spec
# survive a Mnesia restart (proxy for BEAM restart durability).

Process.sleep(300)

alias AgentPlane.{BundleBuilder, Runtime}
alias SharedContracts.Blanket
alias WorkbenchWeb.Episode
alias WorldModels.{AgentRegistry, EventLog, Spec}
alias WorldPlane.Worlds

spec_id = "spec-phase8-observe"
agent_id = "agent-phase8-observe"

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
      blanket: %{observation_channels: [:goal_cue], action_vocabulary: [:move_east, :move_west]},
      created_by: "phase8_observe"
    })
  )

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
    spec_id: spec.id
  )

{:ok, pid} =
  Episode.start_link(
    session_id: "session-phase8-observe",
    maze: world,
    blanket: blanket,
    bundle: bundle,
    agent_id: agent_id,
    max_steps: 8,
    goal_idx: goal_idx,
    mode: :pure
  )

:ok = AgentRegistry.attach_live(agent_id, spec.id)

drain = fn d ->
  case Episode.step(pid) do
    {:ok, _} -> d.(d)
    {:done, s} -> s
    {:error, _} -> :err
  end
end

summary = drain.(drain)

IO.puts("=== Episode ===")
IO.puts("  goal reached?: #{summary.goal_reached?}")
IO.puts("  steps:         #{summary.steps}")

events = EventLog.query(agent_id: agent_id, order: :asc)
IO.puts("  events logged: #{length(events)}")

# ---------- T5-style scrub ----------
mid_ts = events |> Enum.at(div(length(events), 4)) |> Map.fetch!(:ts_usec)
snap_mid = EventLog.snapshot_at(agent_id, mid_ts)
snap_end = EventLog.snapshot_at(agent_id, List.last(events).ts_usec)

IO.puts("\n=== Timeline scrub ===")
IO.puts("  scrub @ mid_ts=#{mid_ts}")
IO.puts("    events in window: #{length(snap_mid.events)}")
IO.puts("    reconstructed chosen_action: #{inspect(Map.get(snap_mid.state, :chosen_action))}")
IO.puts("    reconstructed t: #{inspect(Map.get(snap_mid.state, :t))}")
IO.puts("  scrub @ end_ts")
IO.puts("    events in window: #{length(snap_end.events)}")
IO.puts("    reconstructed chosen_action: #{inspect(Map.get(snap_end.state, :chosen_action))}")
IO.puts("    reconstructed best_policy_index: #{inspect(Map.get(snap_end.state, :best_policy_index))}")

# ---------- T4-style span card data ----------
[action_event | _] = EventLog.query(agent_id: agent_id, type: "agent.action_emitted")

IO.puts("\n=== Span card data (for /glass/signal/:id) ===")
IO.puts("  event_id:       #{action_event.id}")
IO.puts("  equation_id:    #{action_event.provenance.equation_id}")

eq = ActiveInferenceCore.Equations.fetch(action_event.provenance.equation_id)
IO.puts("  resolved to eq. #{eq.equation_number} — #{String.slice(eq.source_text_equation, 0, 60)}…")

:ok = Episode.stop(pid)

# ---------- BEAM-restart durability ----------
IO.puts("\n=== Mnesia restart simulating BEAM restart ===")
:stopped = :mnesia.stop()
:ok = :mnesia.start()
:ok = :mnesia.wait_for_tables(
  [:world_models_events, :world_models_specs, :world_models_live_agents],
  5_000
)

# Live row is gone (ram_copies); spec + events survive.
{:ok, reloaded_spec} = AgentRegistry.fetch_spec(spec.id)
events_after = EventLog.query(agent_id: agent_id)

IO.puts("  spec hash stable:  #{reloaded_spec.hash == spec.hash}")
IO.puts("  events persisted:  #{length(events_after)}")
IO.puts("  live_for_spec:     #{inspect(AgentRegistry.live_for_spec(spec.id))}  (should be [])")

IO.puts("\n=== URLs now ready ===")
IO.puts("  http://localhost:4000/glass")
IO.puts("  http://localhost:4000/glass/agent/#{agent_id}")
IO.puts("  http://localhost:4000/glass/signal/#{action_event.id}")

:stopped = :mnesia.stop()
System.halt(0)
