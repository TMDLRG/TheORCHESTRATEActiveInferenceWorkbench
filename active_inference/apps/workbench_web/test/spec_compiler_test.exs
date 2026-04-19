defmodule WorkbenchWeb.SpecCompilerTest do
  @moduledoc """
  Expansion Phase J — each seeded example spec must compile against
  every registered maze and produce a runnable bundle.
  """
  use WorldModels.MnesiaCase, async: false

  alias SharedContracts.Blanket
  alias WorkbenchWeb.SpecCompiler
  alias WorldModels.{AgentRegistry, Seeds, Spec}
  alias WorldModels.EventLog.Setup
  alias WorldPlane.Worlds

  setup do
    :ok = Setup.ensure_schema!()
    :ok = Seeds.Examples.seed_all!()
    :ok
  end

  @example_ids [
    "example-l1-hello-pomdp",
    "example-l2-epistemic-explorer",
    "example-l3-sophisticated-planner",
    "example-l4-dirichlet-learner"
    # L5 uses composition archetypes not yet wired through SpecCompiler;
    # covered by CompositionRuntime tests rather than this compiler path.
  ]

  describe "compile/3 across every (spec × maze) combination" do
    for spec_id <- @example_ids do
      test "spec #{spec_id} compiles on every maze" do
        {:ok, %Spec{} = spec} = AgentRegistry.fetch_spec(unquote(spec_id))

        for maze <- Worlds.all() do
          assert {:ok, bundle, agent_opts} =
                   SpecCompiler.compile(spec, maze, blanket: Blanket.maze_default())

          assert bundle.dims.n_states == maze.width * maze.height,
                 "bundle n_states must match maze geometry (#{maze.id})"

          assert bundle.spec_id == spec.id

          # Planner choice must be one of the known modes.
          assert Keyword.get(agent_opts, :planner) in [:naive, :sophisticated, :none]
        end
      end
    end
  end

  describe "guards" do
    test "disabled archetype returns :archetype_disabled" do
      spec =
        Spec.new(%{
          id: "spec-test-disabled",
          archetype_id: "continuous_generalized_filter",
          family_id: "Continuous-time Generative Model (generalized filtering)",
          primary_equation_ids: ["eq_8_1_continuous_generative_model"]
        })

      maze = Worlds.tiny_open_goal()

      assert {:error, :archetype_disabled} =
               SpecCompiler.compile(spec, maze, blanket: Blanket.maze_default())
    end

    test "unknown archetype returns :unknown_archetype" do
      spec =
        %Spec{
          id: "spec-test-unknown",
          archetype_id: "mystery_meat",
          family_id: "Unknown",
          primary_equation_ids: [],
          bundle_params: %{},
          blanket: %{}
        }

      maze = Worlds.tiny_open_goal()

      assert {:error, :unknown_archetype} =
               SpecCompiler.compile(spec, maze, blanket: Blanket.maze_default())
    end
  end

  describe "topology-driven overrides" do
    test "sophisticated_planner node in topology picks the sophisticated planner" do
      {:ok, spec} = AgentRegistry.fetch_spec("example-l3-sophisticated-planner")
      maze = Worlds.deceptive_dead_end()

      assert {:ok, _bundle, agent_opts} =
               SpecCompiler.compile(spec, maze, blanket: Blanket.maze_default())

      assert Keyword.fetch!(agent_opts, :planner) == :sophisticated
    end

    test "naive planner when no sophisticated node present" do
      {:ok, spec} = AgentRegistry.fetch_spec("example-l1-hello-pomdp")
      maze = Worlds.tiny_open_goal()

      assert {:ok, _, agent_opts} =
               SpecCompiler.compile(spec, maze, blanket: Blanket.maze_default())

      assert Keyword.fetch!(agent_opts, :planner) == :naive
    end

    test "Dirichlet learners attach as extra_actions" do
      {:ok, spec} = AgentRegistry.fetch_spec("example-l4-dirichlet-learner")
      maze = Worlds.corridor_turns()

      assert {:ok, _, agent_opts} =
               SpecCompiler.compile(spec, maze, blanket: Blanket.maze_default())

      extra = Keyword.fetch!(agent_opts, :extra_actions)
      assert AgentPlane.Actions.DirichletUpdateA in extra
      assert AgentPlane.Actions.DirichletUpdateB in extra
    end
  end
end
