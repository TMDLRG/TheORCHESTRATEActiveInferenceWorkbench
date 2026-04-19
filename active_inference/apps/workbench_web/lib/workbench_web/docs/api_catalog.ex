defmodule WorkbenchWeb.Docs.ApiCatalog do
  @moduledoc """
  Introspection helper for the in-app `/guide/technical/apps` and
  `/guide/technical/api/:module` pages. Enumerates modules by umbrella
  app and extracts `@doc` / `@spec` from compiled BEAM files via
  `Code.fetch_docs/1`.

  Nothing here is clever — it's a thin wrapper over standard Elixir
  introspection, grouped by umbrella app for rendering.
  """

  @umbrella_apps [
    :active_inference_core,
    :shared_contracts,
    :world_plane,
    :agent_plane,
    :world_models,
    :composition_runtime,
    :workbench_web
  ]

  @typedoc "Per-module catalog entry used by the Technical LiveViews."
  @type module_entry :: %{
          module: module(),
          doc: String.t() | nil,
          functions: [function_entry()]
        }

  @typedoc "Per-function doc entry."
  @type function_entry :: %{
          name: atom(),
          arity: non_neg_integer(),
          doc: String.t() | nil,
          spec: String.t() | nil
        }

  @doc "List of umbrella app atoms we document."
  @spec apps() :: [atom()]
  def apps, do: @umbrella_apps

  @doc """
  Return `[module_entry]` for every public module belonging to `app`.

  Uses `Application.spec(app, :modules)` to list modules and filters out
  test-support modules plus anonymous `:"Elixir.Anonymous"` fragments.
  """
  @spec modules_for(atom()) :: [module_entry()]
  def modules_for(app) when app in @umbrella_apps do
    case Application.spec(app, :modules) do
      nil ->
        []

      mods ->
        mods
        |> Enum.reject(&hidden?/1)
        |> Enum.sort()
        |> Enum.map(&describe/1)
    end
  end

  def modules_for(_), do: []

  @doc "Catalog for every umbrella app, grouped by app atom."
  @spec all() :: [{atom(), [module_entry()]}]
  def all do
    Enum.map(@umbrella_apps, &{&1, modules_for(&1)})
  end

  @doc """
  Fetch a single module_entry by module name. Accepts atoms or strings
  (`"ActiveInferenceCore.DiscreteTime"` or
  `ActiveInferenceCore.DiscreteTime`). Returns `nil` if the module is
  unknown or has no loaded docs.
  """
  @spec fetch(module() | String.t()) :: module_entry() | nil
  def fetch(module) when is_atom(module), do: describe(module)

  def fetch(module) when is_binary(module) do
    try do
      module |> String.to_existing_atom() |> describe()
    rescue
      ArgumentError -> nil
    end
  end

  # ---- internal ------------------------------------------------------

  defp hidden?(module) do
    name = Atom.to_string(module)

    String.contains?(name, ".Application") ||
      String.contains?(name, ".MixProject") ||
      String.starts_with?(name, "Elixir.Anonymous") ||
      not String.starts_with?(name, "Elixir.")
  end

  defp describe(module) do
    {doc, functions} = fetch_docs(module)
    %{module: module, doc: doc, functions: functions}
  end

  defp fetch_docs(module) do
    case Code.fetch_docs(module) do
      {:docs_v1, _anno, _lang, _format, module_doc, _meta, entries} ->
        {extract_string(module_doc), extract_functions(entries, module)}

      _ ->
        {nil, []}
    end
  end

  defp extract_functions(entries, module) do
    specs = read_specs(module)

    entries
    |> Enum.filter(fn
      {{:function, _, _}, _, _, _, _} -> true
      _ -> false
    end)
    |> Enum.map(fn {{:function, name, arity}, _anno, _sig, doc, _meta} ->
      %{
        name: name,
        arity: arity,
        doc: extract_string(doc),
        spec: Map.get(specs, {name, arity})
      }
    end)
    |> Enum.sort_by(&{&1.name, &1.arity})
  end

  defp read_specs(module) do
    case Code.Typespec.fetch_specs(module) do
      {:ok, specs} ->
        specs
        |> Enum.map(fn {sig, defs} ->
          rendered = defs |> List.first() |> to_spec_string(sig, module)
          {sig, rendered}
        end)
        |> Map.new()

      _ ->
        %{}
    end
  end

  defp to_spec_string(ast, {name, _arity}, module) do
    try do
      Code.Typespec.spec_to_quoted(name, ast) |> Macro.to_string()
    rescue
      _ -> inspect({module, name})
    end
  end

  defp extract_string(%{"en" => s}) when is_binary(s), do: s
  defp extract_string(s) when is_binary(s), do: s
  defp extract_string(_), do: nil
end
