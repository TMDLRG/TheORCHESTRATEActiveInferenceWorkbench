defmodule WorldPlane.Worlds.BirdMeadow.HearingModel do
  @moduledoc """
  Pure physics of song propagation in the Bird Meadow.

  Centralised here so the world's `multi_step/2` and the per-bird
  `ObservationEncoder` share one canonical hearing function — and so the
  function can be exercised in isolation by property tests.

  ## Geometry & attenuation

  Distance is **Manhattan** (matches the agent's 4-direction movement
  vocabulary; using Euclidean would create a movement/perception
  geometry mismatch).

  Amplitude attenuates **linearly with a hard cutoff** at `d_max`:

      amp(d) = max(0, 1 − d / d_max)        for d ≤ d_max
             = 0                            otherwise

  Linear with a hard cutoff is chosen over inverse-square because
  (a) inverse-square never reaches zero (we'd still need a separate
  threshold) and (b) linear gives clean, controllable hearing radii for
  experiments with predictable boundaries.

  Default `d_max = 5`.

  ## Aggregation

  When more than one source is audible, the listener observes only the
  **loudest** (the meadow blanket exposes a single aggregated audible
  signal, not per-source channels — this preserves the inter-agent
  Markov blanket: a listener cannot directly observe other birds'
  hidden state, only an aggregated audible projection).

  Tie-break is fully deterministic — amplitude DESC, then distance ASC,
  then `agent_id` lexicographic ASC. Determinism is a hard requirement
  for the audit-anchor reproducibility tests; do not loosen it.

  ## Bearing

  Bearing is binned to four cardinal quadrants (N/E/S/W) by comparing
  |Δrow| vs |Δcol|. Ties (|Δrow| == |Δcol|) resolve to the vertical axis
  (N/S) for determinism.

  Same-tile sources (Δrow == 0 and Δcol == 0) report bearing `:none`.
  """

  @typedoc "An (col, row) coordinate, 0-indexed top-left."
  @type coord :: {non_neg_integer(), non_neg_integer()}

  @typedoc "A song event emitted on this tick."
  @type song_event :: %{
          required(:agent_id) => String.t(),
          required(:token) => atom(),
          required(:position) => coord(),
          optional(:source_amp) => float(),
          optional(:t) => non_neg_integer()
        }

  @typedoc "Aggregated hearing observation for one listener on one tick."
  @type heard :: %{
          token: atom(),
          amp_bin: :silence | :soft | :medium | :loud,
          bearing: :none | :north | :east | :south | :west,
          raw_amp: float(),
          source_id: String.t() | nil,
          distance: non_neg_integer() | nil
        }

  @default_d_max 5

  @doc "Default attenuation cutoff distance (Manhattan units)."
  @spec default_d_max() :: pos_integer()
  def default_d_max, do: @default_d_max

  @doc "Manhattan distance between two coordinates."
  @spec distance(coord(), coord()) :: non_neg_integer()
  def distance({c1, r1}, {c2, r2}), do: abs(c1 - c2) + abs(r1 - r2)

  @doc """
  Linear attenuation with hard cutoff at `d_max`. `source_amp` defaults
  to 1.0 (the canonical full-intensity emission).
  """
  @spec attenuate(non_neg_integer(), pos_integer(), float()) :: float()
  def attenuate(distance, d_max \\ @default_d_max, source_amp \\ 1.0)
      when is_integer(distance) and distance >= 0 and is_integer(d_max) and d_max > 0 do
    if distance > d_max do
      0.0
    else
      max(0.0, source_amp * (1.0 - distance / d_max))
    end
  end

  @doc """
  Bin a continuous amplitude into the meadow blanket's 4-way categorical:
  `[:silence, :soft, :medium, :loud]`. Boundaries are 0, 1/3, 2/3, 1.0.
  """
  @spec bin_amp(float()) :: :silence | :soft | :medium | :loud
  def bin_amp(amp) when is_float(amp) do
    cond do
      amp <= 0.0 -> :silence
      amp <= 1.0 / 3.0 -> :soft
      amp <= 2.0 / 3.0 -> :medium
      true -> :loud
    end
  end

  @doc """
  Cardinal bearing from listener to source, binned to 4 quadrants.
  Returns `:none` when both coordinates coincide.
  """
  @spec bearing_of(coord(), coord()) :: :none | :north | :east | :south | :west
  def bearing_of({src_c, src_r}, {lst_c, lst_r}) do
    dr = src_r - lst_r
    dc = src_c - lst_c

    cond do
      dr == 0 and dc == 0 ->
        :none

      abs(dr) >= abs(dc) ->
        if dr < 0, do: :north, else: :south

      true ->
        if dc > 0, do: :east, else: :west
    end
  end

  @doc """
  Aggregate all audible song events at one listener position.

  Returns a `heard/0` map. When no source is audible, returns the silent
  default `%{token: :none, amp_bin: :silence, bearing: :none, raw_amp: 0.0,
  source_id: nil, distance: nil}`.

  Tie-break ordering (deterministic): amplitude DESC, distance ASC,
  agent_id lexicographic ASC.
  """
  @spec aggregate_per_listener([song_event()], coord(), keyword()) :: heard()
  def aggregate_per_listener(song_events, listener_pos, opts \\ []) when is_list(song_events) do
    d_max = Keyword.get(opts, :d_max, @default_d_max)

    audible =
      song_events
      |> Enum.map(fn ev ->
        d = distance(ev.position, listener_pos)
        amp = attenuate(d, d_max, Map.get(ev, :source_amp, 1.0))
        {ev, d, amp}
      end)
      |> Enum.filter(fn {_ev, _d, amp} -> amp > 0.0 end)

    case audible do
      [] ->
        silent()

      list ->
        {ev, d, amp} =
          Enum.min_by(list, fn {ev, d, amp} -> {-amp, d, ev.agent_id} end)

        %{
          token: ev.token,
          amp_bin: bin_amp(amp),
          bearing: bearing_of(ev.position, listener_pos),
          raw_amp: amp,
          source_id: ev.agent_id,
          distance: d
        }
    end
  end

  @doc "The silent default heard observation."
  @spec silent() :: heard()
  def silent do
    %{token: :none, amp_bin: :silence, bearing: :none, raw_amp: 0.0, source_id: nil, distance: nil}
  end
end
