defmodule WorkbenchWeb.SpecCompiler do
  @moduledoc """
  Expansion Phase J — compile a saved `WorldModels.Spec` against a
  concrete world (maze) into a runnable bundle + agent opts.

  The Builder produces a spec — a declarative composition of A/B/C/D
  blocks, planner choice, learners, etc. The Engine needs a bundle
  sized for the world it will run in. This module is the bridge:

      SpecCompiler.compile(spec, maze) -> {:ok, bundle, agent_opts}

  **Pure** — no process mucking, no Mnesia writes. Given the same spec
  and maze, the same bundle comes back.

  Archetype rules (reused, not redefined):

    * `pomdp_maze` — default path through `BundleBuilder.for_maze/1`
      using `spec.bundle_params` (horizon, policy_depth,
      preference_strength). Naïve `Plan` action.
    * `dirichlet_pomdp` — same bundle, but seed A and B weak so the
      `DirichletUpdateA/B` learners have room to adjust them; include
      the two learner modules in the action set.
    * `hmm` — perception-only, shrinks policies to horizon=1 and drops
      `Plan`/`Act` from the set.
    * Any spec whose topology contains a `sophisticated_planner` node
      overrides the planner choice (Plan → SophisticatedPlan).
    * Any spec whose topology contains an `epistemic_preference` block
      with `pragmatic_weight == 0.0` zeroes the pragmatic term in C.
    * Matrix blocks with `init: "custom"` and a non-empty `cells` list
      replace the corresponding slot in the derived bundle verbatim.

  Disabled archetypes return `{:error, :archetype_disabled}`; unknown
  archetypes return `{:error, :unknown_archetype}`. Callers (`/labs`,
  Builder's Instantiate) surface these to the user.
  """

  alias AgentPlane.BundleBuilder
  alias WorldModels.{Archetypes, Spec}
  alias WorldPlane.Maze

  @type compile_ok :: {:ok, bundle :: map(), agent_opts :: keyword()}
  @type compile_err :: {:error, atom() | {atom(), term()}}

  @spec compile(Spec.t(), Maze.t(), keyword()) :: compile_ok() | compile_err()
  def compile(%Spec{} = spec, %Maze{} = maze, opts \\ []) do
    with {:ok, archetype} <- fetch_archetype(spec),
         :ok <- ensure_enabled(archetype) do
      {:ok, bundle, agent_opts} = compile_for(archetype, spec, maze, opts)

      bundle =
        bundle
        |> Map.put(:spec_id, spec.id)
        |> apply_topology_overrides(spec.topology)

      {:ok, bundle, agent_opts}
    end
  end

  # ----------------------------------------------------------------------------
  # Archetype-specific compilation
  # ----------------------------------------------------------------------------

  defp compile_for(%Archetypes{id: "pomdp_maze"}, spec, maze, opts) do
    base = base_bundle(spec, maze, opts)
    planner = planner_for_topology(spec.topology)

    {:ok, base, [planner: planner]}
  end

  defp compile_for(%Archetypes{id: "dirichlet_pomdp"}, spec, maze, opts) do
    base =
      base_bundle(spec, maze, opts)
      # Weak A/B priors — the Dirichlet learners adjust these online
      # over the episode. Stored on the bundle so Glass can show the
      # learning signal.
      |> Map.put(:weak_priors?, true)

    planner = planner_for_topology(spec.topology)

    {:ok, base,
     [
       planner: planner,
       extra_actions: [AgentPlane.Actions.DirichletUpdateA, AgentPlane.Actions.DirichletUpdateB]
     ]}
  end

  defp compile_for(%Archetypes{id: "hmm"}, spec, maze, opts) do
    # HMM is perception-only — horizon 1, no planner, no acting.
    hmm_opts =
      opts
      |> Keyword.put(:horizon, 1)
      |> Keyword.put(:policy_depth, 1)

    base = base_bundle(spec, maze, hmm_opts) |> Map.put(:hmm?, true)

    {:ok, base, [planner: :none, extra_actions: []]}
  end

  defp compile_for(%Archetypes{id: other}, _spec, _maze, _opts) do
    {:error, {:unsupported_archetype, other}}
  end

  # ----------------------------------------------------------------------------
  # Base bundle via BundleBuilder.for_maze/1 — same path /world uses today
  # ----------------------------------------------------------------------------

  defp base_bundle(spec, maze, opts) do
    width = maze.width
    height = maze.height

    walls =
      maze.grid
      |> Enum.filter(fn {_k, t} -> t == :wall end)
      |> Enum.map(fn {{c, r}, _} -> r * width + c end)

    {sc, sr} = maze.start
    {gc, gr} = maze.goal

    params = spec.bundle_params || %{}

    BundleBuilder.for_maze(
      width: width,
      height: height,
      start_idx: sr * width + sc,
      goal_idx: gr * width + gc,
      walls: walls,
      blanket: Keyword.fetch!(opts, :blanket),
      horizon: Keyword.get(opts, :horizon, Map.get(params, :horizon, 3)),
      policy_depth: Keyword.get(opts, :policy_depth, Map.get(params, :policy_depth, 3)),
      preference_strength:
        Keyword.get(opts, :preference_strength, Map.get(params, :preference_strength, 4.0)),
      spec_id: spec.id
    )
  end

  # ----------------------------------------------------------------------------
  # Topology-driven overrides
  # ----------------------------------------------------------------------------

  defp planner_for_topology(%{nodes: nodes}) do
    if Enum.any?(nodes, &(&1.type == "sophisticated_planner")),
      do: :sophisticated,
      else: :naive
  end

  defp planner_for_topology(_), do: :naive

  defp apply_topology_overrides(bundle, nil), do: bundle

  defp apply_topology_overrides(bundle, %{nodes: nodes}) do
    bundle
    |> maybe_zero_pragmatic(nodes)
    |> maybe_apply_custom_matrices(nodes)
  end

  defp apply_topology_overrides(bundle, _), do: bundle

  defp maybe_zero_pragmatic(bundle, nodes) do
    epistemic =
      Enum.find(nodes, fn n ->
        n.type == "epistemic_preference" and
          to_float(Map.get(n.params || %{}, "pragmatic_weight"), 1.0) == 0.0
      end)

    if epistemic do
      # C in the 4-obs layout: [not_goal_clear, not_goal_hit, goal_clear, goal_hit].
      # Zeroing pragmatic preference flattens the first three entries.
      c_log = bundle.c

      flat =
        c_log
        |> Enum.with_index()
        |> Enum.map(fn {_, i} -> if i == 2, do: Enum.max(c_log), else: 0.0 end)

      %{bundle | c: flat}
    else
      bundle
    end
  end

  defp maybe_apply_custom_matrices(bundle, nodes) do
    bundle
    |> apply_custom(nodes, "likelihood_matrix", :a)
    |> apply_custom(nodes, "transition_matrix", :b)
  end

  defp apply_custom(bundle, nodes, node_type, slot) do
    node =
      Enum.find(nodes, fn n ->
        n.type == node_type and Map.get(n.params || %{}, "init") == "custom"
      end)

    case node do
      nil ->
        bundle

      %{params: params} ->
        cells = Map.get(params, "cells")

        if is_list(cells) and cells != [] do
          Map.put(bundle, slot, cells)
        else
          bundle
        end
    end
  end

  # ----------------------------------------------------------------------------
  # Archetype + enabled-guard helpers
  # ----------------------------------------------------------------------------

  defp fetch_archetype(%Spec{archetype_id: id}) do
    case Archetypes.fetch(id) do
      nil -> {:error, :unknown_archetype}
      a -> {:ok, a}
    end
  end

  defp ensure_enabled(%Archetypes{disabled?: true}), do: {:error, :archetype_disabled}
  defp ensure_enabled(%Archetypes{}), do: :ok

  defp to_float(nil, default), do: default
  defp to_float(x, _) when is_float(x), do: x
  defp to_float(x, _) when is_integer(x), do: x * 1.0

  defp to_float(x, default) when is_binary(x) do
    case Float.parse(x) do
      {f, _} -> f
      :error -> default
    end
  end

  defp to_float(_, default), do: default
end
