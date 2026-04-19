# Plan §12 Phase 3 runtime observation.
#
# Starts the full supervision tree in dev (Jido instance, WorldModels
# event log, bus), runs a real Jido.AgentServer through `tiny_open_goal`
# via Episode in :supervised mode, and reports both the Episode-level
# provenance events and the JIDO runtime telemetry.

Process.sleep(300)

alias AgentPlane.{BundleBuilder, JidoInstance, Runtime}
alias SharedContracts.Blanket
alias WorkbenchWeb.Episode
alias WorldModels.EventLog
alias WorldPlane.Worlds

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
    spec_id: "spec-phase3-supervised"
  )

agent_id = "agent-phase3-supervised"

{:ok, pid} =
  Episode.start_link(
    session_id: "session-phase3-supervised",
    maze: world,
    blanket: blanket,
    bundle: bundle,
    agent_id: agent_id,
    max_steps: 8,
    goal_idx: goal_idx,
    mode: :supervised
  )

# Confirm the agent is a live supervised Jido.AgentServer.
live_agents = JidoInstance.list_agents()
IO.puts("=== Jido.list_agents ===")
Enum.each(live_agents, fn {id, p} -> IO.puts("  #{id} → #{inspect(p)}") end)

{:ok, srv_state} = Runtime.state(agent_id)
IO.puts("\n=== Jido.AgentServer.state provenance ===")
IO.puts("  struct:       #{inspect(srv_state.agent.__struct__)}")
IO.puts("  agent_module: #{inspect(srv_state.agent.agent_module)}")
IO.puts("  agent_id:     #{srv_state.agent.state.agent_id}")
IO.puts("  spec_id:      #{srv_state.agent.state.spec_id}")
IO.puts("  bundle_id:    #{srv_state.agent.state.bundle_id}")
IO.puts("  family_id:    #{srv_state.agent.state.family_id}")

drain = fn d ->
  case Episode.step(pid) do
    {:ok, _} -> d.(d)
    {:done, s} -> s
    {:error, _} -> :err
  end
end

summary = drain.(drain)

IO.puts("\n=== Episode result (supervised) ===")
IO.puts("  goal reached?: #{summary.goal_reached?}")
IO.puts("  steps:         #{summary.steps}")
IO.puts("  final pos:     #{inspect(summary.world.pos)}")

events = EventLog.query(agent_id: agent_id)
IO.puts("\n=== EventLog (#{length(events)} events) ===")

by_type = Enum.frequencies_by(events, & &1.type)
by_type
|> Enum.sort_by(fn {t, _} -> t end)
|> Enum.each(fn {t, n} -> IO.puts("  #{String.pad_trailing(t, 50)} #{n}") end)

runtime_events = Enum.filter(events, &String.starts_with?(&1.type, "runtime."))
IO.puts("\n=== Sample JIDO runtime telemetry event ===")

if first = List.first(runtime_events) do
  IO.puts("  type:     #{first.type}")
  IO.puts("  agent_id: #{inspect(first.provenance.agent_id)}")
  IO.puts("  trace_id: #{inspect(first.provenance.trace_id)}")
  IO.puts("  span_id:  #{inspect(first.provenance.span_id)}")
  IO.puts("  metadata: #{inspect(first.data.metadata, limit: :infinity)}")
else
  IO.puts("  (none)")
end

:ok = Episode.stop(pid)

# Clean shutdown so Mnesia dumps the DCL to DCD. This is what gives us
# the cross-BEAM durability we verified in Phase 2.
:stopped = :mnesia.stop()
System.halt(0)
