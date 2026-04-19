defmodule WorldModels.Spec do
  @moduledoc """
  Plan §10.1 — authoritative record of a Builder-composed agent.

  A `Spec` is the persistent artifact the Builder produces and the Runtime
  consumes to instantiate a live `Jido.AgentServer`. Every live agent
  carries its `spec_id` in `%Jido.AgentServer.State{}` so Glass Engine can
  follow a signal back to the composition that produced it.

  The `:hash` field (plan §7.3) is a deterministic BLAKE2b digest of the
  canonical form — two specs with the same content hash identically, so
  re-runs + diffs become trivial.
  """

  @enforce_keys [:id, :archetype_id, :family_id, :primary_equation_ids]

  defstruct [
    :id,
    :archetype_id,
    :family_id,
    :primary_equation_ids,
    :bundle_params,
    :blanket,
    :hash,
    :created_at,
    :created_by,
    :topology,
    version: "1.0"
  ]

  @type t :: %__MODULE__{
          id: String.t(),
          archetype_id: String.t(),
          family_id: String.t(),
          primary_equation_ids: [String.t()],
          bundle_params: map(),
          blanket: map(),
          hash: binary(),
          created_at: DateTime.t() | nil,
          created_by: String.t() | nil,
          version: String.t(),
          topology: map() | nil
        }

  @doc """
  Construct a `Spec` from a bare map.

  `:hash` is auto-computed via `provenance_hash/1` if not supplied, making
  it safe for callers to hand in a content map and receive a properly
  content-addressed struct back.
  """
  @spec new(map()) :: t()
  def new(attrs) when is_map(attrs) do
    attrs =
      attrs
      |> Map.put_new(:bundle_params, %{})
      |> Map.put_new(:blanket, %{})
      |> Map.put_new(:created_at, DateTime.utc_now())
      |> Map.put_new(:topology, nil)

    base = struct!(__MODULE__, Map.drop(attrs, [:hash]))

    %{base | hash: Map.get(attrs, :hash) || provenance_hash(base)}
  end

  @doc """
  Deterministic canonical form — the piece that actually drives behaviour.
  Excludes `:id`, `:created_at`, `:created_by`, `:hash` so that logically
  identical specs (re-registrations, clones) collapse to the same hash.
  """
  @spec canonical_form(t()) :: map()
  def canonical_form(%__MODULE__{} = s) do
    %{
      archetype_id: s.archetype_id,
      family_id: s.family_id,
      primary_equation_ids: Enum.sort(s.primary_equation_ids),
      bundle_params: canonicalize(s.bundle_params),
      blanket: canonicalize(s.blanket),
      topology: canonicalize_topology(s.topology),
      version: s.version
    }
  end

  # Plan §7.3 — topology lists must canonicalize to an order-invariant
  # form so that reordering nodes/edges on the canvas doesn't change the
  # spec's provenance hash. Without this, a user dragging a node changes
  # the hash trivially; with this, only the set of nodes+edges+params
  # matters.
  defp canonicalize_topology(nil), do: nil

  defp canonicalize_topology(%{} = t) do
    %{
      nodes:
        t
        |> Map.get(:nodes, [])
        |> Enum.map(&canonicalize/1)
        |> Enum.sort_by(&node_sort_key/1),
      edges:
        t
        |> Map.get(:edges, [])
        |> Enum.map(&canonicalize/1)
        |> Enum.sort_by(&edge_sort_key/1),
      required_types: t |> Map.get(:required_types, []) |> Enum.sort()
    }
  end

  defp node_sort_key(n), do: Map.get(n, :id) || inspect(n)

  defp edge_sort_key(e),
    do:
      {Map.get(e, :from_node), Map.get(e, :from_port), Map.get(e, :to_node), Map.get(e, :to_port)}

  @doc "BLAKE2b-256 hex digest of the canonical form."
  @spec provenance_hash(t()) :: binary()
  def provenance_hash(%__MODULE__{} = s) do
    payload = s |> canonical_form() |> :erlang.term_to_binary([:deterministic])
    :crypto.hash(:blake2b, payload) |> Base.encode16(case: :lower) |> binary_part(0, 32)
  end

  # Maps sort by key order in ETS; recurse to canonicalize nested structures.
  defp canonicalize(nil), do: nil

  defp canonicalize(%_{} = struct) do
    struct
    |> Map.from_struct()
    |> canonicalize()
  end

  defp canonicalize(m) when is_map(m) do
    m
    |> Enum.map(fn {k, v} -> {k, canonicalize(v)} end)
    |> Enum.sort_by(fn {k, _} -> inspect(k) end)
    |> Map.new()
  end

  defp canonicalize(l) when is_list(l), do: Enum.map(l, &canonicalize/1)
  defp canonicalize(other), do: other
end
