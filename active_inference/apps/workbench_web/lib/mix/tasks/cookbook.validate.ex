defmodule Mix.Tasks.Cookbook.Validate do
  @moduledoc """
  Validate every recipe under
  `apps/workbench_web/priv/cookbook/*.json` against the schema and the live
  runtime.

  A recipe **cannot ship** unless:

    * required keys are present (see `priv/cookbook/_schema.yaml` for the
      authoritative reference — recipes themselves are JSON to match the
      suite's state-file convention and avoid a new YAML dependency);
    * every `runtime.actions_used` atom resolves to a module under
      `AgentPlane.Actions.*`;
    * every `runtime.skills_used` atom resolves to a module under
      `AgentPlane.Skills.*`;
    * `runtime.world` is a registered maze (`WorldPlane.Worlds`) OR a
      registered continuous world (`WorldPlane.ContinuousWorlds`).

  Run with:

      mix cookbook.validate
  """

  use Mix.Task

  @shortdoc "Validate cookbook JSON recipes against schema + runtime"

  @required_keys ~w(slug title level tier_label minutes tags runtime runnable math audiences orchestrate credits)a
  @required_audiences ~w(kid real equation derivation)a
  @required_runtime_keys ~w(agent_module bundle world actions_used skills_used horizon policy_depth preference_strength expected_outcome)a
  @required_orchestrate ~w(objective role context)a

  @impl true
  def run(_args) do
    Mix.Task.run("app.start")
    dir = cookbook_dir()

    files =
      dir
      |> File.ls!()
      |> Enum.filter(&String.ends_with?(&1, ".json"))
      |> Enum.reject(&String.starts_with?(&1, "_"))
      |> Enum.sort()
      |> Enum.map(&Path.join(dir, &1))

    {ok, errors} =
      Enum.reduce(files, {0, []}, fn path, {ok, errs} ->
        case validate_file(path) do
          :ok -> {ok + 1, errs}
          {:error, msgs} -> {ok, errs ++ Enum.map(msgs, &{path, &1})}
        end
      end)

    if errors == [] do
      Mix.shell().info("[cookbook.validate] #{ok} recipes, 0 errors")
      :ok
    else
      for {path, msg} <- errors do
        Mix.shell().error("  #{Path.basename(path)}: #{msg}")
      end

      Mix.shell().error(
        "[cookbook.validate] #{ok} passed, #{length(errors)} error#{if length(errors) == 1, do: "", else: "s"}"
      )

      exit({:shutdown, 1})
    end
  end

  @doc "Validate a single recipe file.  Returns `:ok` or `{:error, [messages]}`."
  @spec validate_file(Path.t()) :: :ok | {:error, [String.t()]}
  def validate_file(path) do
    with {:ok, body} <- File.read(path),
         {:ok, data} <- Jason.decode(body) do
      validate_recipe(data)
    else
      {:error, reason} -> {:error, ["parse error: #{inspect(reason)}"]}
    end
  end

  @doc false
  def validate_recipe(data) when is_map(data) do
    errs =
      []
      |> check_required_keys(data)
      |> check_audiences(data)
      |> check_runtime_keys(data)
      |> check_orchestrate(data)
      |> check_level(data)
      |> check_tags(data)
      |> check_runtime_modules(data)
      |> check_world(data)
      |> check_credits(data)

    case errs do
      [] -> :ok
      _ -> {:error, Enum.reverse(errs)}
    end
  end

  def validate_recipe(_), do: {:error, ["top-level must be a map"]}

  # --- per-check helpers ---------------------------------------------------

  defp check_required_keys(errs, data) do
    Enum.reduce(@required_keys, errs, fn key, acc ->
      if Map.has_key?(data, to_string(key)), do: acc, else: ["missing required key: #{key}" | acc]
    end)
  end

  defp check_audiences(errs, %{"audiences" => aud}) when is_map(aud) do
    Enum.reduce(@required_audiences, errs, fn tier, acc ->
      v = Map.get(aud, to_string(tier))

      cond do
        is_nil(v) -> ["audiences.#{tier} missing" | acc]
        not is_binary(v) -> ["audiences.#{tier} must be string" | acc]
        String.trim(v) == "" -> ["audiences.#{tier} must be non-empty" | acc]
        true -> acc
      end
    end)
  end

  defp check_audiences(errs, _), do: ["audiences block missing or not a map" | errs]

  defp check_runtime_keys(errs, %{"runtime" => rt}) when is_map(rt) do
    Enum.reduce(@required_runtime_keys, errs, fn key, acc ->
      if Map.has_key?(rt, to_string(key)), do: acc, else: ["runtime.#{key} missing" | acc]
    end)
  end

  defp check_runtime_keys(errs, _), do: ["runtime block missing or not a map" | errs]

  defp check_orchestrate(errs, %{"orchestrate" => orc}) when is_map(orc) do
    Enum.reduce(@required_orchestrate, errs, fn key, acc ->
      if Map.has_key?(orc, to_string(key)), do: acc, else: ["orchestrate.#{key} missing" | acc]
    end)
  end

  defp check_orchestrate(errs, _), do: ["orchestrate block missing or not a map" | errs]

  defp check_level(errs, %{"level" => l}) when is_integer(l) and l >= 1 and l <= 5, do: errs
  defp check_level(errs, %{"level" => l}), do: ["level must be 1..5, got #{inspect(l)}" | errs]
  defp check_level(errs, _), do: errs

  defp check_tags(errs, %{"tags" => t}) when is_list(t) and length(t) >= 1, do: errs
  defp check_tags(errs, %{"tags" => _}), do: ["tags must be a non-empty list" | errs]
  defp check_tags(errs, _), do: errs

  defp check_credits(errs, %{"credits" => c}) when is_list(c) and length(c) >= 1, do: errs
  defp check_credits(errs, %{"credits" => _}), do: ["credits must be a non-empty list" | errs]
  defp check_credits(errs, _), do: errs

  defp check_runtime_modules(errs, %{"runtime" => rt}) when is_map(rt) do
    errs
    |> check_module_list(rt["actions_used"], "AgentPlane.Actions", "runtime.actions_used")
    |> check_module_list(rt["skills_used"], "AgentPlane.Skills", "runtime.skills_used")
  end

  defp check_runtime_modules(errs, _), do: errs

  defp check_module_list(errs, nil, _prefix, label),
    do: ["#{label} missing" | errs]

  defp check_module_list(errs, list, prefix, label) when is_list(list) do
    Enum.reduce(list, errs, fn entry, acc ->
      atom = entry |> to_string() |> String.trim_leading(":")
      candidates = atom_to_module_candidates(atom) |> Enum.map(&(prefix <> "." <> &1))

      found? =
        Enum.any?(candidates, fn name ->
          case safe_module(name) do
            nil -> false
            mod -> Code.ensure_loaded?(mod)
          end
        end)

      if found? do
        acc
      else
        ["#{label}: no module for #{inspect(atom)} (tried #{Enum.join(candidates, ", ")})" | acc]
      end
    end)
  end

  defp check_module_list(errs, _, _, label), do: ["#{label} must be a list" | errs]

  # Generate a small set of candidate module-name spellings for a kebab/snake atom.
  # Handles common acronyms (KL, EFE, VFE) by uppercasing segments that are
  # obvious abbreviations.
  defp atom_to_module_candidates(str) do
    parts = String.split(str, ~r/[_\s-]+/)
    capitalised = Enum.map(parts, &String.capitalize/1) |> Enum.join()

    uppercase_short =
      parts
      |> Enum.map(fn p ->
        cond do
          String.length(p) <= 3 -> String.upcase(p)
          true -> String.capitalize(p)
        end
      end)
      |> Enum.join()

    [capitalised, uppercase_short] |> Enum.uniq()
  end

  defp safe_module(name) do
    try do
      String.to_existing_atom("Elixir." <> name)
    rescue
      ArgumentError -> nil
    end
  end

  defp check_world(errs, %{"runtime" => %{"world" => w}}) when is_binary(w) do
    # Force-load both world modules so their world-id atoms are registered
    # before we try `String.to_existing_atom/1`.
    Code.ensure_loaded?(WorldPlane.Worlds)
    continuous = safe_module("WorldPlane.ContinuousWorlds")
    if continuous, do: Code.ensure_loaded?(continuous)

    if continuous do
      # Pre-touch each registered id so the atom table holds them.
      Enum.each(apply(continuous, :all, []), fn world -> _ = world.id end)
    end

    Enum.each(WorldPlane.Worlds.all(), fn world -> _ = world.id end)

    atom =
      try do
        String.to_existing_atom(w)
      rescue
        ArgumentError -> nil
      end

    cond do
      is_nil(atom) ->
        ["runtime.world atom #{inspect(w)} not known (no matching world registered)" | errs]

      WorldPlane.Worlds.fetch(atom) != nil ->
        errs

      continuous && apply(continuous, :fetch, [atom]) != nil ->
        errs

      true ->
        ["runtime.world #{inspect(w)} not registered in Worlds or ContinuousWorlds" | errs]
    end
  end

  defp check_world(errs, _), do: errs

  defp cookbook_dir do
    Path.join([
      :code.priv_dir(:workbench_web) |> to_string(),
      "cookbook"
    ])
  end
end
