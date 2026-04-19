defmodule WorldModels.Event do
  @moduledoc """
  Plan §8.2 — versioned event envelope for the unified WorldModels.Bus.

  Every artifact crossing the bus (signals, agent lifecycle, equation
  evaluations, world events) rides inside a `%Event{}` so every subscriber
  sees the same shape and the EventLog has a single canonical record.

  `:provenance` is the plan §7.1 tuple — foreign keys into the taxonomy and
  equation registry. Consumers resolve IDs against the registry at render
  time; we never snapshot book content into events.
  """

  @enforce_keys [:id, :ts, :ts_usec, :type, :provenance]
  defstruct [
    :id,
    :ts,
    :ts_usec,
    :version,
    :type,
    :provenance,
    :data
  ]

  @type provenance :: %{
          optional(:agent_id) => String.t() | nil,
          optional(:spec_id) => String.t() | nil,
          optional(:bundle_id) => String.t() | nil,
          optional(:family_id) => String.t() | nil,
          optional(:world_run_id) => String.t() | nil,
          optional(:equation_id) => String.t() | nil,
          optional(:trace_id) => String.t() | nil,
          optional(:span_id) => String.t() | nil
        }

  @type t :: %__MODULE__{
          id: String.t(),
          ts: DateTime.t(),
          ts_usec: integer(),
          version: String.t(),
          type: String.t(),
          provenance: provenance(),
          data: map()
        }

  @spec new(map() | keyword()) :: t()
  def new(opts) when is_list(opts), do: opts |> Map.new() |> new()

  def new(opts) when is_map(opts) do
    type = Map.fetch!(opts, :type)
    provenance = Map.fetch!(opts, :provenance)

    ts_usec =
      case Map.get(opts, :ts_usec) do
        nil -> System.system_time(:microsecond)
        n when is_integer(n) -> n
      end

    ts =
      case Map.get(opts, :ts) do
        nil -> DateTime.from_unix!(ts_usec, :microsecond)
        %DateTime{} = dt -> dt
      end

    %__MODULE__{
      id: Map.get_lazy(opts, :id, &generate_id/0),
      ts: ts,
      ts_usec: ts_usec,
      version: Map.get(opts, :version, "1.0"),
      type: type,
      provenance: provenance,
      data: Map.get(opts, :data, %{})
    }
  end

  defp generate_id do
    "evt-" <> (:crypto.strong_rand_bytes(8) |> Base.url_encode64(padding: false))
  end
end
