defmodule WorkbenchWeb.Cookbook.Loader do
  @moduledoc """
  Runtime loader for cookbook recipes.  D2 (plan).

  Reads every `*.json` under `priv/cookbook/` (skipping `_`-prefixed files)
  at boot, validates lightly, and exposes query helpers.  Bad recipes log
  a warning and are skipped -- the app must not crash because one recipe
  file is malformed.

  Source of truth for the schema lives in
  `priv/cookbook/_schema.yaml` and `mix cookbook.validate` is the
  authoritative gate.
  """

  require Logger

  @typedoc "Decoded recipe map (JSON as loaded)."
  @type recipe :: map()

  @doc "Return all loaded recipes, sorted by level then slug."
  @spec list() :: [recipe()]
  def list do
    load_all()
    |> Enum.sort_by(fn r -> {Map.get(r, "level", 99), Map.get(r, "slug", "zz")} end)
  end

  @doc "Fetch a recipe by slug; `nil` if unknown."
  @spec get(String.t()) :: recipe() | nil
  def get(slug) when is_binary(slug) do
    Enum.find(list(), &(Map.get(&1, "slug") == slug))
  end

  @doc "Filter by level (1..5)."
  @spec by_level(integer()) :: [recipe()]
  def by_level(level) when is_integer(level),
    do: Enum.filter(list(), &(Map.get(&1, "level") == level))

  @doc "Filter by tag."
  @spec by_tag(String.t()) :: [recipe()]
  def by_tag(tag) when is_binary(tag) do
    Enum.filter(list(), fn r -> tag in (Map.get(r, "tags") || []) end)
  end

  @doc """
  Map a recipe to the closest seeded example spec_id.  Used by
  "Run in Builder" / "Run in Labs" to hydrate the five pre-seeded
  example specs (L1-L5) with a spec that best matches the recipe's
  runtime requirements.

  Heuristic:

    * hierarchical or hierarchy tag            -> L5
    * dirichlet_update_a or _b in actions      -> L4
    * sophisticated_plan in actions            -> L3
    * zero preference_strength                 -> L2 (epistemic)
    * default                                  -> L1 (hello POMDP)
  """
  @spec spec_id_for(String.t()) :: String.t()
  def spec_id_for(slug) when is_binary(slug) do
    case get(slug) do
      nil ->
        "example-l1-hello-pomdp"

      recipe ->
        rt = Map.get(recipe, "runtime") || %{}
        actions = rt["actions_used"] || []
        tags = recipe["tags"] || []
        pref = rt["preference_strength"]

        cond do
          "hierarchical" in tags or "hierarchy" in tags -> "example-l5-hierarchical-composition"
          "dirichlet_update_a" in actions or "dirichlet_update_b" in actions -> "example-l4-dirichlet-learner"
          "sophisticated_plan" in actions -> "example-l3-sophisticated-planner"
          is_number(pref) and pref == 0 -> "example-l2-epistemic-explorer"
          true -> "example-l1-hello-pomdp"
        end
    end
  end

  @doc """
  Return the runnable spec for a recipe: a keyword list suitable for
  `AgentPlane.BundleBuilder.for_maze/1` plus the world id.  Used by the
  "Run in Builder" and "Run in Labs" buttons (D5 / D6 / G8).
  """
  @spec spec_for(String.t()) ::
          {:ok, %{world: atom(), opts: keyword()}} | {:error, String.t()}
  def spec_for(slug) do
    case get(slug) do
      nil ->
        {:error, "unknown recipe: #{slug}"}

      recipe ->
        rt = Map.get(recipe, "runtime") || %{}
        world = String.to_atom(rt["world"] || "tiny_open_goal")
        horizon = rt["horizon"] || 4
        policy_depth = rt["policy_depth"] || horizon
        preference_strength = (rt["preference_strength"] || 4.0) / 1.0

        opts = [
          horizon: horizon,
          policy_depth: policy_depth,
          preference_strength: preference_strength
        ]

        # Optional bundle-builder knobs (G6).
        opts =
          case rt["c_preference_override"] do
            list when is_list(list) -> Keyword.put(opts, :c_preference_override, list)
            _ -> opts
          end

        opts =
          case rt["precision_vector"] do
            list when is_list(list) -> Keyword.put(opts, :precision_vector, list)
            _ -> opts
          end

        opts =
          case rt["learning_enabled"] do
            true -> Keyword.put(opts, :learning_enabled, true)
            _ -> opts
          end

        {:ok, %{world: world, opts: opts}}
    end
  end

  # -- internals ------------------------------------------------------------

  defp load_all do
    dir = cookbook_dir()

    if File.dir?(dir) do
      dir
      |> File.ls!()
      |> Enum.filter(&String.ends_with?(&1, ".json"))
      |> Enum.reject(&String.starts_with?(&1, "_"))
      |> Enum.map(&Path.join(dir, &1))
      |> Enum.flat_map(&load_one/1)
    else
      []
    end
  end

  defp load_one(path) do
    with {:ok, body} <- File.read(path),
         {:ok, data} <- Jason.decode(body) do
      case minimal_check(data) do
        :ok ->
          [data]

        {:error, reason} ->
          Logger.warning("[cookbook.loader] skipping #{Path.basename(path)}: #{reason}")

          []
      end
    else
      {:error, reason} ->
        Logger.warning(
          "[cookbook.loader] skipping #{Path.basename(path)}: parse error #{inspect(reason)}"
        )

        []
    end
  end

  # Runtime check is lighter than mix cookbook.validate: only slug + level +
  # runtime block.  The heavy check is a build-time gate, not a boot-time one.
  defp minimal_check(%{"slug" => s, "level" => l, "runtime" => rt})
       when is_binary(s) and is_integer(l) and is_map(rt),
       do: :ok

  defp minimal_check(_), do: {:error, "missing slug / level / runtime"}

  defp cookbook_dir do
    Path.join([:code.priv_dir(:workbench_web) |> to_string(), "cookbook"])
  end
end
