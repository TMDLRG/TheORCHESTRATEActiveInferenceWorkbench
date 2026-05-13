defmodule AgentPlane.BundleBuilder.Birdsong do
  @moduledoc """
  Generative-model bundle for the Birdsong Call-Response lab.

  This module builds a discrete POMDP consumed unchanged by
  `AgentPlane.ActiveInferenceAgent`. The model is symbolic-acoustic: waveform
  input is converted to coarse motif tokens by the world plane, while the agent
  infers over latent motif, turn phase, response mode, and self-audition state.

  Hidden state factors:

    * heard motif: `[:silence, :a, :b, :c, :d, :unknown]`
    * turn phase: `[:call, :gap, :response_due, :refractory]`
    * interaction mode: `[:echo, :complement, :withhold]`
    * self motif: `[:none, :a, :b, :c, :d]`

  Flat hidden-state cardinality is 6 * 4 * 3 * 5 = 360.
  """

  alias ActiveInferenceCore.Math, as: M
  alias ActiveInferenceCore.Models
  alias AgentPlane.{BirdsongObsAdapter, BirdsongSongbook, BundleBuilder}

  @pomdp_family_name "Partially Observable Markov Decision Process (POMDP)"

  @motifs [:silence, :a, :b, :c, :d, :unknown]
  @singable [:a, :b, :c, :d]
  @phases [:call, :gap, :response_due, :refractory]
  @modes [:echo, :complement, :withhold]
  @self_values [:none, :a, :b, :c, :d]
  @actions [:listen, :sing_a, :sing_b, :sing_c, :sing_d]

  @n_motif length(@motifs)
  @n_phase length(@phases)
  @n_mode length(@modes)
  @n_self length(@self_values)
  @n_states @n_motif * @n_phase * @n_mode * @n_self

  @doc "Hidden heard-motif alphabet."
  @spec motifs() :: [atom()]
  def motifs, do: @motifs

  @doc "Turn-phase state alphabet."
  @spec phases() :: [atom()]
  def phases, do: @phases

  @doc "Interaction-mode state alphabet."
  @spec modes() :: [atom()]
  def modes, do: @modes

  @doc "Self-audition state alphabet."
  @spec self_values() :: [atom()]
  def self_values, do: @self_values

  @doc "Canonical action vocabulary."
  @spec actions() :: [atom()]
  def actions, do: @actions

  @doc """
  Build the birdsong POMDP bundle.

  Options:

    * `:policy_depth` - default 2.
    * `:horizon` - default policy depth.
    * `:softmax_temperature` - default 0.5.
    * `:action_selection` - default `:sample`; tests and demos may use `:argmax`.
    * `:preferred_mode` - one of `:echo | :complement | :withhold`, default `:complement`.
    * `:songbook_counts` - optional Dirichlet counts for learned response
      mapping `P(response_motif | heard_motif)`.
  """
  @spec build(keyword()) :: map()
  def build(opts \\ []) do
    policy_depth = Keyword.get(opts, :policy_depth, 2)
    horizon = Keyword.get(opts, :horizon, policy_depth)
    preferred_mode = Keyword.get(opts, :preferred_mode, :complement)
    validate_mode!(preferred_mode)

    a = build_a()
    b = build_b()
    songbook_counts = Keyword.get(opts, :songbook_counts, nil)

    c = build_c(songbook_counts, Keyword.get(opts, :songbook_strength, 6.0))
    d = build_d(preferred_mode)
    policies = BundleBuilder.enumerate_policies(@actions, policy_depth)
    pomdp = Models.fetch(@pomdp_family_name)

    %{
      a: a,
      b: b,
      c: c,
      d: d,
      e: nil,
      actions: @actions,
      policies: policies,
      horizon: horizon,
      dims: %{
        n_states: @n_states,
        n_obs: BirdsongObsAdapter.n_obs(),
        factors: %{
          motif: @motifs,
          phase: @phases,
          mode: @modes,
          self: @self_values
        }
      },
      obs_adapter: BirdsongObsAdapter,
      precision_vector: nil,
      learning_enabled: false,
      softmax_temperature: Keyword.get(opts, :softmax_temperature, 0.5),
      action_selection: Keyword.get(opts, :action_selection, :sample),
      bundle_id: generate_bundle_id(),
      spec_id: nil,
      family_id: @pomdp_family_name,
      primary_equation_ids: pomdp.source_basis,
      verification_status: :verified_against_source,
      birdsong_meta: %{
        representation: :symbolic_motif_sequence,
        preferred_mode: preferred_mode,
        songbook_learning?: not is_nil(songbook_counts),
        fixed_parameters?: true,
        online_inference: [:hidden_state_posterior, :policy_posterior],
        learned_parameters: if(is_nil(songbook_counts), do: [], else: [:songbook_counts])
      }
    }
  end

  @doc "Encode hidden-state factors to a flat index."
  @spec state_index(atom(), atom(), atom(), atom()) :: 0..359
  def state_index(motif, phase, mode, self_motif) do
    mi = idx_in(@motifs, motif)
    pi = idx_in(@phases, phase)
    zi = idx_in(@modes, mode)
    si = idx_in(@self_values, self_motif)

    ((mi * @n_phase + pi) * @n_mode + zi) * @n_self + si
  end

  @doc "Decode a flat hidden-state index."
  @spec decode_state(0..359) :: {atom(), atom(), atom(), atom()}
  def decode_state(idx) when idx in 0..(@n_states - 1)//1 do
    si = rem(idx, @n_self)
    rest1 = div(idx, @n_self)
    zi = rem(rest1, @n_mode)
    rest2 = div(rest1, @n_mode)
    pi = rem(rest2, @n_phase)
    mi = div(rest2, @n_phase)

    {Enum.at(@motifs, mi), Enum.at(@phases, pi), Enum.at(@modes, zi), Enum.at(@self_values, si)}
  end

  defp build_a do
    rows =
      for obs_idx <- 0..(BirdsongObsAdapter.n_obs() - 1) do
        {heard_o, phase_o, self_o, fit_o} = BirdsongObsAdapter.decode_index(obs_idx)

        for state_idx <- 0..(@n_states - 1) do
          {motif_s, phase_s, mode_s, self_s} = decode_state(state_idx)

          p_heard = categorical_match(heard_o, motif_s, @motifs, 0.92)
          p_phase = categorical_match(phase_o, phase_s, @phases, 0.94)
          p_self = categorical_match(self_o, self_s, @self_values, 0.96)

          p_fit =
            categorical_match(
              fit_o,
              expected_fit(motif_s, mode_s, self_s),
              BirdsongObsAdapter.fit_values(),
              0.90
            )

          p_heard * p_phase * p_self * p_fit
        end
      end

    renormalise_columns(rows)
  end

  defp build_b do
    Enum.into(@actions, %{}, fn action ->
      mat =
        for next_idx <- 0..(@n_states - 1) do
          {motif_n, phase_n, mode_n, self_n} = decode_state(next_idx)

          for curr_idx <- 0..(@n_states - 1) do
            {motif_c, phase_c, mode_c, _self_c} = decode_state(curr_idx)
            p_motif = categorical_match(motif_n, motif_c, @motifs, 0.96)
            p_phase = categorical_match(phase_n, next_phase(phase_c, action), @phases, 0.97)
            p_mode = categorical_match(mode_n, mode_c, @modes, 0.98)
            p_self = categorical_match(self_n, action_to_self(action), @self_values, 0.99)

            p_motif * p_phase * p_mode * p_self
          end
        end

      {action, renormalise_columns(mat)}
    end)
  end

  defp build_c(songbook_counts, strength) do
    logits =
      for obs_idx <- 0..(BirdsongObsAdapter.n_obs() - 1) do
        {_heard, phase, self_sang, fit} = BirdsongObsAdapter.decode_index(obs_idx)
        {heard, _phase, _self, _fit} = BirdsongObsAdapter.decode_index(obs_idx)

        songbook_logit(songbook_counts, heard, phase, self_sang, fit, strength)
      end

    logits |> M.softmax() |> Enum.map(&:math.log(max(&1, 1.0e-16)))
  end

  defp songbook_logit(counts, heard, phase, self_sang, fit, strength)
       when heard in @singable do
    dist = BirdsongSongbook.distribution(counts, heard)
    target_p = Map.get(dist, self_sang, 0.0)
    best = BirdsongSongbook.predict(counts, heard)

    cond do
      phase in [:call, :gap, :response_due] and self_sang == best ->
        strength * (1.0 + target_p)

      phase in [:call, :gap, :response_due] and self_sang in @singable ->
        strength * target_p - 2.0

      phase in [:call, :gap, :response_due] and self_sang == :none ->
        -2.5

      fit == :good_fit ->
        1.0

      fit == :poor_fit ->
        -2.0

      true ->
        0.0
    end
  end

  defp songbook_logit(_counts, _heard, phase, self_sang, fit, _strength) do
    cond do
      phase in [:call, :gap] and self_sang == :none -> 1.0
      fit == :good_fit -> 1.0
      fit == :poor_fit -> -2.0
      true -> 0.0
    end
  end

  defp build_d(preferred_mode) do
    logits =
      for state_idx <- 0..(@n_states - 1) do
        {motif, phase, mode, self_motif} = decode_state(state_idx)

        motif_logit = if motif == :silence, do: 0.0, else: 0.2
        phase_logit = if phase == :call, do: 1.0, else: 0.0
        mode_logit = if mode == preferred_mode, do: 1.5, else: 0.0
        self_logit = if self_motif == :none, do: 1.0, else: 0.0

        motif_logit + phase_logit + mode_logit + self_logit
      end

    M.softmax(logits)
  end

  defp next_phase(:call, _action), do: :response_due
  defp next_phase(:gap, _action), do: :response_due
  defp next_phase(:response_due, action) when action == :listen, do: :response_due
  defp next_phase(:response_due, _action), do: :refractory
  defp next_phase(:refractory, _action), do: :call

  defp expected_fit(_motif, :withhold, :none), do: :none
  defp expected_fit(_motif, :withhold, _self), do: :poor_fit
  defp expected_fit(_motif, _mode, :none), do: :none
  defp expected_fit(motif, :echo, self) when motif in @singable and self == motif, do: :good_fit

  defp expected_fit(motif, :complement, self) when motif in @singable do
    if self == complement(motif), do: :good_fit, else: :poor_fit
  end

  defp expected_fit(motif, mode, self)
       when motif in @singable and mode in [:echo, :complement] and self in @singable,
       do: :poor_fit

  defp expected_fit(_, _, _), do: :none

  defp action_to_self(:listen), do: :none
  defp action_to_self(:sing_a), do: :a
  defp action_to_self(:sing_b), do: :b
  defp action_to_self(:sing_c), do: :c
  defp action_to_self(:sing_d), do: :d

  defp complement(:a), do: :b
  defp complement(:b), do: :a
  defp complement(:c), do: :d
  defp complement(:d), do: :c

  defp categorical_match(observed, expected, values, p_match) do
    if observed == expected do
      p_match
    else
      (1.0 - p_match) / max(length(values) - 1, 1)
    end
  end

  defp validate_mode!(mode) do
    unless mode in @modes do
      raise ArgumentError, "Birdsong mode #{inspect(mode)} is not in #{inspect(@modes)}"
    end
  end

  defp idx_in(values, value) do
    case Enum.find_index(values, &(&1 == value)) do
      nil -> raise ArgumentError, "value #{inspect(value)} is not in #{inspect(values)}"
      idx -> idx
    end
  end

  defp renormalise_columns(m) do
    cols = M.transpose(m)

    cols
    |> Enum.map(&M.normalise/1)
    |> M.transpose()
  end

  defp generate_bundle_id do
    "birdsong-bundle-" <> (:crypto.strong_rand_bytes(8) |> Base.url_encode64(padding: false))
  end
end
