# Plan §12 Phase 2 — runtime observation script.
# Drives one episode end-to-end in MIX_ENV=dev with the full supervision
# tree (Mnesia event log + bus) running, then inspects Mnesia durability.

Process.sleep(200)

alias AgentPlane.BundleBuilder
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
    spec_id: "spec-phase2-observe"
  )

{:ok, pid} =
  Episode.start_link(
    session_id: "session-phase2-observe",
    maze: world,
    blanket: blanket,
    bundle: bundle,
    agent_id: "agent-phase2-observe",
    max_steps: 8,
    goal_idx: goal_idx
  )

drain = fn f ->
  case Episode.step(pid) do
    {:ok, _} -> f.(f)
    {:done, _} -> :done
    {:error, _} -> :err
  end
end

:done = drain.(drain)

ram = length(EventLog.query(agent_id: "agent-phase2-observe"))
IO.puts("\n=== IN RAM AFTER RUN ===")
IO.puts("events persisted: #{ram}")

# Force Mnesia to flush pending disc_copies writes to disk.
:mnesia.sync_log()
_ = :mnesia.dump_log()

dcd = File.stat!("priv/mnesia/dev/world_models_events.DCD").size
IO.puts("\n=== ON DISK AFTER sync_log + dump_log ===")
IO.puts("world_models_events.DCD size: #{dcd} bytes")

:stopped = :mnesia.stop()

dcd_after = File.stat!("priv/mnesia/dev/world_models_events.DCD").size
IO.puts("\n=== ON DISK AFTER :mnesia.stop() ===")
IO.puts("world_models_events.DCD size: #{dcd_after} bytes")

System.halt(0)
