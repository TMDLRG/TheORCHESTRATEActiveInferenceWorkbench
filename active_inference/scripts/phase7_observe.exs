# Plan §12 Phase 7 runtime observation.
#
# Drives the full Builder round-trip in-process: seed archetype on an
# empty canvas → validate → save → instantiate → verify live agent
# appears in AgentRegistry + Glass-accessible.

Process.sleep(300)

alias AgentPlane.Runtime
alias WorldModels.{AgentRegistry, Archetypes, Spec}

# 1. User drags POMDP archetype onto empty canvas.
archetype = Archetypes.fetch("pomdp_maze")
topology = Archetypes.seed_topology(archetype)

IO.puts("=== Step 1: archetype seed ===")
IO.puts("  archetype:       #{archetype.id}")
IO.puts("  nodes seeded:    #{length(topology.nodes)}")
IO.puts("  edges seeded:    #{length(topology.edges)}")

# 2. Server-side validation.
case WorldModels.Spec.Topology.validate(topology) do
  :ok -> IO.puts("  validation:      ok ✓")
  {:error, errs} -> IO.puts("  validation:      ERRORS: #{inspect(errs)}")
end

# 3. Save spec.
spec_id = "spec-phase7-observe"

spec =
  Spec.new(%{
    id: spec_id,
    archetype_id: archetype.id,
    family_id: archetype.family_id,
    primary_equation_ids: archetype.primary_equation_ids,
    bundle_params: archetype.default_params,
    blanket: %{observation_channels: [:goal_cue], action_vocabulary: [:move_east, :move_west]},
    topology: topology,
    created_by: "phase7_observe"
  })

{:ok, saved} = AgentRegistry.register_spec(spec)

IO.puts("\n=== Step 2: save_spec ===")
IO.puts("  spec_id:         #{saved.id}")
IO.puts("  hash:            #{saved.hash}")
IO.puts("  topology hash stable? #{saved.hash == spec.hash}")

# 4. Instantiate — simulate what BuilderLive.Compose does on click.
agent_id = "agent-phase7-observe"

alias AgentPlane.BundleBuilder
alias SharedContracts.Blanket
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
    spec_id: saved.id
  )

{:ok, ^agent_id, pid} =
  Runtime.start_agent(%{
    agent_id: agent_id,
    bundle: bundle,
    blanket: blanket,
    goal_idx: goal_idx,
    spec_id: saved.id
  })

IO.puts("\n=== Step 3: instantiate ===")
IO.puts("  agent_id:        #{agent_id}")
IO.puts("  pid:             #{inspect(pid)}")
IO.puts("  alive?           #{Process.alive?(pid)}")

# 5. Verify the live_for_spec round-trip.
live = AgentRegistry.live_for_spec(saved.id)
IO.puts("\n=== Step 4: AgentRegistry.live_for_spec ===")
IO.puts("  agents for #{saved.id}: #{inspect(live)}")

# 6. Verify Jido.AgentServer state carries provenance.
{:ok, srv} = Runtime.state(agent_id)

IO.puts("\n=== Step 5: Jido.AgentServer.state ===")
IO.puts("  struct:          #{inspect(srv.agent.__struct__)}")
IO.puts("  agent_module:    #{inspect(srv.agent.agent_module)}")
IO.puts("  agent_id:        #{srv.agent.state.agent_id}")
IO.puts("  spec_id:         #{srv.agent.state.spec_id}")
IO.puts("  bundle_id:       #{srv.agent.state.bundle_id}")
IO.puts("  family_id:       #{srv.agent.state.family_id}")
IO.puts("  primary eqs:     #{length(srv.agent.state.primary_equation_ids)}")

IO.puts("\n=== Glass URL ===")
IO.puts("  http://localhost:4000/glass/agent/#{agent_id}")

:ok = Runtime.stop_agent(agent_id)
:stopped = :mnesia.stop()
System.halt(0)
