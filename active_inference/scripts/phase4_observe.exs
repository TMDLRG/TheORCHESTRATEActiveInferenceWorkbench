# Plan §12 Phase 4 runtime observation.
#
# Boots the full supervision tree (Jido + WorldModels bus + Mnesia event
# log), runs one supervised Episode, then reports:
#   - equation.evaluated events per DiscreteTime function,
#   - that every event resolves to a real equation in the registry,
#   - that the Glass Engine can follow a single runtime event back through
#     equation -> family -> bundle -> spec -> agent.

Process.sleep(300)

alias ActiveInferenceCore.Equations
alias AgentPlane.{BundleBuilder, Runtime}
alias SharedContracts.Blanket
alias WorkbenchWeb.Episode
alias WorldModels.EventLog
alias WorldPlane.Worlds

world = Worlds.tiny_open_goal()
blanket = Blanket.maze_default()
walls = world.grid |> Enum.filter(fn {_, t} -> t == :wall end) |> Enum.map(fn {{c, r}, _} -> r * world.width + c end)
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
    spec_id: "spec-phase4-observe"
  )

agent_id = "agent-phase4-observe"

{:ok, pid} =
  Episode.start_link(
    session_id: "session-phase4-observe",
    maze: world,
    blanket: blanket,
    bundle: bundle,
    agent_id: agent_id,
    max_steps: 8,
    goal_idx: goal_idx,
    mode: :supervised
  )

drain = fn d ->
  case Episode.step(pid) do
    {:ok, _} -> d.(d)
    {:done, s} -> s
    {:error, _} -> :err
  end
end

_summary = drain.(drain)
:ok = Episode.stop(pid)

events = EventLog.query(agent_id: agent_id)
eq_events = Enum.filter(events, &(&1.type == "equation.evaluated"))

IO.puts("=== Event counts ===")

events
|> Enum.frequencies_by(& &1.type)
|> Enum.sort_by(fn {t, _} -> t end)
|> Enum.each(fn {t, n} -> IO.puts("  #{String.pad_trailing(t, 50)} #{n}") end)

IO.puts("\n=== equation.evaluated by function ===")
eq_events
|> Enum.frequencies_by(& &1.data.fn_name)
|> Enum.sort_by(fn {f, _} -> Atom.to_string(f) end)
|> Enum.each(fn {fn_name, n} ->
  eq_id = eq_events |> Enum.find(&(&1.data.fn_name == fn_name)) |> then(& &1.provenance.equation_id)
  IO.puts("  #{String.pad_trailing(Atom.to_string(fn_name), 25)} n=#{String.pad_trailing("#{n}", 4)} eq_id=#{eq_id}")
end)

IO.puts("\n=== registry resolution ===")
eq_ids = eq_events |> Enum.map(& &1.provenance.equation_id) |> Enum.uniq()

for id <- eq_ids do
  case Equations.fetch(id) do
    %ActiveInferenceCore.Equation{equation_number: num, chapter: ch} ->
      IO.puts("  #{id} → eq. #{num} (#{ch})")

    nil ->
      IO.puts("  #{id} → UNRESOLVED")
  end
end

IO.puts("\n=== one sample equation.evaluated event ===")
sample = List.first(eq_events)
IO.puts("  type:           #{sample.type}")
IO.puts("  equation_id:    #{sample.provenance.equation_id}")
IO.puts("  family_id:      #{sample.provenance.family_id}")
IO.puts("  spec_id:        #{sample.provenance.spec_id}")
IO.puts("  bundle_id:      #{sample.provenance.bundle_id}")
IO.puts("  world_run_id:   #{sample.provenance.world_run_id}")
IO.puts("  fn_name:        #{sample.data.fn_name}/#{sample.data.arity}")
IO.puts("  duration_us:    #{sample.data.duration_us}")

:stopped = :mnesia.stop()
System.halt(0)
