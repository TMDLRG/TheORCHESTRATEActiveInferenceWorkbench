# Plan §13 — final UAT observation script.
#
# Runs live against MIX_ENV=dev with full supervision (Phoenix endpoint,
# Jido instance, Mnesia EventLog, Bus). Seeds a complete spec + runs an
# Episode, then reports each of the 6 UATs with its class-A observed
# evidence.

Process.sleep(300)

alias ActiveInferenceCore.{Equations, Models}
alias AgentPlane.{BundleBuilder, JidoInstance, Runtime}
alias SharedContracts.Blanket
alias WorkbenchWeb.Episode
alias WorldModels.{AgentRegistry, Archetypes, EventLog, Spec}
alias WorldPlane.Worlds

spec_id = "spec-uat-observe"
agent_id = "agent-uat-observe"

{:ok, _} =
  AgentRegistry.register_spec(
    Spec.new(%{
      id: spec_id,
      archetype_id: "pomdp_maze",
      family_id: "Partially Observable Markov Decision Process (POMDP)",
      primary_equation_ids: Archetypes.fetch("pomdp_maze").primary_equation_ids,
      bundle_params: %{horizon: 3, policy_depth: 3, preference_strength: 4.0},
      blanket: %{},
      created_by: "phase9_uat_observe"
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
    spec_id: spec_id
  )

# Real supervised agent for UAT-1 evidence.
{:ok, ^agent_id, pid} =
  Runtime.start_agent(%{
    agent_id: agent_id,
    bundle: bundle,
    blanket: blanket,
    goal_idx: goal_idx,
    spec_id: spec_id
  })

# Drive an Episode in :pure mode (faster — same math, same provenance)
# for the events UAT-3..UAT-6 inspect.
episode_agent_id = "agent-uat-observe-episode"

{:ok, episode_pid} =
  Episode.start_link(
    session_id: "uat-session",
    maze: world,
    blanket: blanket,
    bundle: BundleBuilder.for_maze(
      width: world.width,
      height: world.height,
      start_idx: start_idx,
      goal_idx: goal_idx,
      walls: walls,
      blanket: blanket,
      horizon: 3,
      policy_depth: 3,
      spec_id: spec_id
    ),
    agent_id: episode_agent_id,
    max_steps: 8,
    goal_idx: goal_idx,
    mode: :pure
  )

:ok = AgentRegistry.attach_live(episode_agent_id, spec_id)

drain = fn d ->
  case Episode.step(episode_pid) do
    {:ok, _} -> d.(d)
    {:done, s} -> s
    {:error, _} -> :err
  end
end

summary = drain.(drain)

IO.puts("\n===== UAT-1: Taxonomy → real native Jido agent =====")
{:ok, %Jido.AgentServer.State{} = srv} = Runtime.state(agent_id)
IO.puts("  process:      #{inspect(pid)} (alive? #{Process.alive?(pid)})")
IO.puts("  struct:       #{inspect(srv.agent.__struct__)}")
IO.puts("  agent_module: #{inspect(srv.agent.agent_module)}")
IO.puts("  spec_id:      #{srv.agent.state.spec_id}")
IO.puts("  bundle_id:    #{srv.agent.state.bundle_id}")
IO.puts("  family_id:    #{srv.agent.state.family_id}")

IO.puts("\n===== UAT-2: Builder ↔ World ↔ Glass linkage =====")
live = AgentRegistry.list_live_agents()
IO.puts("  live agents:  #{length(live)}")

Enum.each(live, fn {aid, sid} -> IO.puts("    - #{aid} → #{sid}") end)

{:ok, spec} = AgentRegistry.fetch_spec(spec_id)
IO.puts("  spec hash:    #{spec.hash}")
IO.puts("  family:       #{spec.family_id}")
IO.puts("  equations:    #{length(spec.primary_equation_ids)}")

IO.puts("\n===== UAT-3: World interaction visibility =====")
events = EventLog.query(agent_id: episode_agent_id)
by_type = events |> Enum.frequencies_by(& &1.type) |> Enum.sort_by(fn {t, _} -> t end)
IO.puts("  Episode summary: goal_reached?=#{summary.goal_reached?} steps=#{summary.steps}")
IO.puts("  events on bus + in Mnesia (#{length(events)} total):")

Enum.each(by_type, fn {t, n} ->
  IO.puts("    #{String.pad_trailing(t, 50)} #{n}")
end)

IO.puts("\n===== UAT-4: Glass introspection content =====")
[sample_action | _] = EventLog.query(agent_id: episode_agent_id, type: "agent.action_emitted")
IO.puts("  span card event_id: #{sample_action.id}")
IO.puts("  equation_id:        #{sample_action.provenance.equation_id}")
eq = Equations.fetch(sample_action.provenance.equation_id)
IO.puts("  verbatim source:    #{eq.source_text_equation}")
IO.puts("  LaTeX:              #{eq.normalized_latex}")
IO.puts("  verification:       #{eq.verification_status}")

IO.puts("\n===== UAT-5: Timeline scrub shows state evolution =====")
sorted = Enum.sort_by(events, & &1.ts_usec)
early_ts = sorted |> Enum.at(1) |> Map.fetch!(:ts_usec)
final_ts = sorted |> List.last() |> Map.fetch!(:ts_usec)

early_snap = EventLog.snapshot_at(episode_agent_id, early_ts)
final_snap = EventLog.snapshot_at(episode_agent_id, final_ts)

IO.puts("  early snap ts_usec=#{early_ts}")
IO.puts("    events: #{length(early_snap.events)}")
IO.puts("    chosen_action: #{inspect(Map.get(early_snap.state, :chosen_action))}")

IO.puts("  final snap ts_usec=#{final_ts}")
IO.puts("    events: #{length(final_snap.events)}")
IO.puts("    chosen_action: #{inspect(Map.get(final_snap.state, :chosen_action))}")
IO.puts("    best_policy_index: #{inspect(Map.get(final_snap.state, :best_policy_index))}")

IO.puts("\n===== UAT-6: End-to-end provenance round-trip =====")
IO.puts("  forward trace from event #{sample_action.id}:")
IO.puts("    event      → agent_id:      #{sample_action.provenance.agent_id}")
IO.puts("               → bundle_id:     #{sample_action.provenance.bundle_id}")
IO.puts("               → spec_id:       #{sample_action.provenance.spec_id}")
IO.puts("               → family_id:     #{sample_action.provenance.family_id}")
IO.puts("               → equation_id:   #{sample_action.provenance.equation_id}")

{:ok, resolved_spec} = AgentRegistry.fetch_spec(sample_action.provenance.spec_id)
family = Models.fetch(sample_action.provenance.family_id)
IO.puts("  ↓ resolutions:")
IO.puts("    Spec hash     : #{resolved_spec.hash}")
IO.puts("    Family type   : #{family.type}  (#{length(family.source_basis)} equations)")
IO.puts("    Equation      : #{eq.equation_number} (#{eq.chapter})")

back = AgentRegistry.live_for_spec(spec_id)
IO.puts("  backward trace spec_id → live_for_spec: #{inspect(back)}")

IO.puts("\n===== URLs for manual browser verification =====")
IO.puts("  http://localhost:4000/")
IO.puts("  http://localhost:4000/world")
IO.puts("  http://localhost:4000/builder/new")
IO.puts("  http://localhost:4000/glass")
IO.puts("  http://localhost:4000/glass/agent/#{episode_agent_id}")
IO.puts("  http://localhost:4000/glass/signal/#{sample_action.id}")

:ok = Episode.stop(episode_pid)
:ok = Runtime.stop_agent(agent_id)

:stopped = :mnesia.stop()
System.halt(0)
