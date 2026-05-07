defmodule AgentPlane.BundleBuilder.Meadow do
  @moduledoc """
  Bundle constructors for the three Bird Meadow tiers.

  Each constructor produces a bundle of the same shape as
  `AgentPlane.BundleBuilder.for_maze/1` (so `ActiveInferenceAgent`
  consumes them unchanged), with two meadow-specific additions:

    * `:obs_adapter` — set to `AgentPlane.MeadowObsAdapter`. Picked up
      by `AgentPlane.Actions.Perceive` to project observation packets
      onto the agent's flat obs vector with the meadow encoding.
    * `:resonant_meta` (Resonant only) — a small map describing how
      the meta-level interaction-mode posterior gates the lower
      bundle's C. The MeadowEpisode reads it and applies the context
      swap before each Plan call.

  ## Tier table (incremental, falsifiable design)

  | Tier      | Hidden state                                            | A factor structure                                | Policy depth | What it adds vs. previous |
  |-----------|---------------------------------------------------------|---------------------------------------------------|--------------|---------------------------|
  | Simple    | `position` (W·H)                                        | wall_sig depends on s; hearing factors uniform    | 1            | baseline pragmatic mover |
  | Complex   | `position × partner_token (5) × partner_present (2)`     | + hearing depends on partner state                | 2            | partner-as-state inference |
  | Resonant  | same as Complex                                          | same as Complex                                   | 2            | + context-swap C modulator |

  All three reuse the audit-verified VFE / EFE math in
  `AgentPlane.Skills.{VariationalFreeEnergy, ExpectedFreeEnergy}`.
  """

  alias ActiveInferenceCore.Math, as: M
  alias ActiveInferenceCore.Models
  alias AgentPlane.MeadowObsAdapter
  alias SharedContracts.Blanket

  @pomdp_family_name "Partially Observable Markov Decision Process (POMDP)"

  @movement_actions [:move_north, :move_south, :move_east, :move_west]

  @doc """
  SimpleBird: single-factor POMDP with position-only hidden state.

  Required opts:
    * `:width`, `:height` — meadow grid dimensions.
    * `:preferred_token` — atom in `[:t1, :t2, :t3, :t4]`. Defines the
      bird's "song identity" — C peaks on observations whose
      `hearing_token` channel matches this token.

  Optional opts:
    * `:walls` (default `[]`) — interior wall tiles `{c, r}`.
    * `:preference_strength` (default 4.0) — log-preference magnitude
      for the preferred-token observations. Capped because high values
      crush epistemic exploration (see RUNTIME_GAPS-style risk register
      in the meadow plan).
    * `:policy_depth` (default 1) — receding-horizon depth.
    * `:horizon` (default `policy_depth`).
    * `:softmax_temperature` (default 1.0) — for the policy posterior.
    * `:action_selection` (default `:sample`) — `:sample` | `:argmax`.
  """
  @spec simple(keyword()) :: map()
  def simple(opts) do
    width = Keyword.fetch!(opts, :width)
    height = Keyword.fetch!(opts, :height)
    preferred = Keyword.fetch!(opts, :preferred_token)
    validate_token!(preferred)

    walls = opts |> Keyword.get(:walls, []) |> MapSet.new()
    pref_strength = clamp_preference(Keyword.get(opts, :preference_strength, 4.0))
    policy_depth = Keyword.get(opts, :policy_depth, 1)
    horizon = Keyword.get(opts, :horizon, policy_depth)
    softmax_temp = Keyword.get(opts, :softmax_temperature, 1.0)
    action_selection = Keyword.get(opts, :action_selection, :sample)

    n_states = width * height
    n_obs = MeadowObsAdapter.n_obs()
    actions = meadow_actions()

    a = build_a_simple(width, height, walls, n_states)
    b = build_b_per_action(width, height, walls, actions, n_states)
    c_log = build_c(preferred, pref_strength)
    d = M.uniform(n_states)
    policies = enumerate_policies(actions, policy_depth)
    pomdp = Models.fetch(@pomdp_family_name)

    %{
      a: a,
      b: b,
      c: c_log,
      d: d,
      e: nil,
      actions: actions,
      policies: policies,
      horizon: horizon,
      dims: %{
        n_states: n_states,
        n_obs: n_obs,
        width: width,
        height: height,
        tier: :simple
      },
      obs_adapter: MeadowObsAdapter,
      precision_vector: nil,
      learning_enabled: false,
      softmax_temperature: softmax_temp,
      action_selection: action_selection,
      bundle_id: generate_bundle_id(),
      spec_id: nil,
      family_id: @pomdp_family_name,
      primary_equation_ids: pomdp.source_basis,
      verification_status: :verified_against_source,
      meadow_meta: %{tier: :simple, preferred_token: preferred}
    }
  end

  @doc """
  ComplexBird: factorised POMDP with `position × partner_token ×
  partner_present` hidden state.

  Same opts as `simple/1` plus:
    * `:partner_persistence` (default 0.9) — diagonal of the
      partner_present transition (probability the partner stays present
      between ticks).
    * `:partner_token_drift` (default 0.05) — probability the believed
      partner_token wanders to one of the other tokens between ticks.

  Default `:policy_depth` is 2.
  """
  @spec complex(keyword()) :: map()
  def complex(opts) do
    width = Keyword.fetch!(opts, :width)
    height = Keyword.fetch!(opts, :height)
    preferred = Keyword.fetch!(opts, :preferred_token)
    validate_token!(preferred)

    walls = opts |> Keyword.get(:walls, []) |> MapSet.new()
    pref_strength = clamp_preference(Keyword.get(opts, :preference_strength, 4.0))
    policy_depth = Keyword.get(opts, :policy_depth, 2)
    horizon = Keyword.get(opts, :horizon, policy_depth)
    softmax_temp = Keyword.get(opts, :softmax_temperature, 1.0)
    action_selection = Keyword.get(opts, :action_selection, :sample)
    persistence = Keyword.get(opts, :partner_persistence, 0.9)
    token_drift = Keyword.get(opts, :partner_token_drift, 0.05)

    n_pos = width * height
    n_token = length(MeadowObsAdapter.token_values())
    n_pres = 2

    n_states = n_pos * n_token * n_pres
    n_obs = MeadowObsAdapter.n_obs()
    actions = meadow_actions()

    a = build_a_complex(width, height, walls)

    b =
      build_b_complex(
        width,
        height,
        walls,
        actions,
        persistence,
        token_drift
      )

    c_log = build_c(preferred, pref_strength)

    # D: uniform on position; partner_token weakly biased toward bird's own
    # preferred token (it expects to find a similar partner — falsifiable
    # claim under audit anchor "is convergence prior-driven?"); partner_present 50/50.
    d = build_d_complex(width, height, preferred)

    policies = enumerate_policies(actions, policy_depth)
    pomdp = Models.fetch(@pomdp_family_name)

    %{
      a: a,
      b: b,
      c: c_log,
      d: d,
      e: nil,
      actions: actions,
      policies: policies,
      horizon: horizon,
      dims: %{
        n_states: n_states,
        n_obs: n_obs,
        width: width,
        height: height,
        n_pos: n_pos,
        n_token: n_token,
        n_pres: n_pres,
        tier: :complex
      },
      obs_adapter: MeadowObsAdapter,
      precision_vector: nil,
      learning_enabled: false,
      softmax_temperature: softmax_temp,
      action_selection: action_selection,
      bundle_id: generate_bundle_id(),
      spec_id: nil,
      family_id: @pomdp_family_name,
      primary_equation_ids: pomdp.source_basis,
      verification_status: :verified_against_source,
      meadow_meta: %{tier: :complex, preferred_token: preferred}
    }
  end

  @doc """
  ResonantBird: structurally identical to ComplexBird but augmented
  with a meta-level context modulator (`:resonant_meta`) that the
  meadow episode runner reads to swap the bird's C-preference between
  two modes:

    * `:explore` — the bird's normal C (peaks on `(token = preferred,
      amp = medium/loud)`). Drives movement toward the partner.
    * `:duet`   — C swapped to peak on `(self_sang = preferred, hearing
      = none)`, encouraging silence-while-listening alternation.

  The meta selects between these contexts based on a summary of the
  recent observation window. This is the falsifiable hypothesis: a
  bird that listens half the time and sings half the time should
  develop call-response timing more reliably than one that just
  follows its base preference.

  Same opts as `complex/1` plus:
    * `:duet_window` (default 8) — number of recent obs to summarise.
    * `:silence_threshold` (default 3) — minimum recent silent ticks
      needed to enter `:duet` mode.

  ## Honest naming (external-review R2-new, v2)

  This v1 "Resonant" tier implements context-swap by a hand-coded
  heuristic on observation summary statistics, **not** by hierarchical
  Bayesian inference over a meta-level generative model. The meta
  has no A/B/C/D matrices of its own; it has a rule (`if recent silence
  count >= threshold, switch to :duet`).

  The name "Resonant" suggests something richer than what's there.
  A future revision should either (a) rename the tier to something like
  `bimodal/1` or `context_swap/1` to reflect the heuristic nature, or
  (b) wire this through `AgentPlane.Hierarchical` (currently
  maze-coupled) so the meta level is a real generative model with its
  own posterior. Tracked as future work; documented here so readers
  know the v1 implementation does mode arbitration, not hierarchical
  inference.
  """
  @spec resonant(keyword()) :: map()
  def resonant(opts) do
    base = complex(opts)
    preferred = Keyword.fetch!(opts, :preferred_token)
    pref_strength = clamp_preference(Keyword.get(opts, :preference_strength, 4.0))
    duet_window = Keyword.get(opts, :duet_window, 8)
    silence_threshold = Keyword.get(opts, :silence_threshold, 3)

    explore_c = build_c(preferred, pref_strength)
    duet_c = build_c_duet(preferred, pref_strength)

    %{
      base
      | dims: Map.put(base.dims, :tier, :resonant),
        meadow_meta: Map.put(base.meadow_meta, :tier, :resonant),
        c: explore_c
    }
    |> Map.put(:resonant_meta, %{
      contexts: %{explore: explore_c, duet: duet_c},
      initial_context: :explore,
      duet_window: duet_window,
      silence_threshold: silence_threshold
    })
  end

  @doc """
  ConvergentBird: a fourth tier whose hidden state is purely
  `partner_bearing` (5-way: none, N, E, S, W). Drops the position
  factor entirely.

  This is the **minimal POMDP that produces genuine spatial
  convergence** under the audit-verified VFE/EFE math. Where
  SimpleBird's hearing factors are uniform conditional on state (so
  EFE has no movement gradient), ConvergentBird's hearing factors are
  conditional on `partner_bearing`, and its B matrix encodes how the
  bird's own movement should change `partner_bearing`. The result:
  EFE-driven action selection prefers movements that maintain or
  increase predicted hearing of the preferred token — i.e. movement
  toward the audible source.

  ## Hidden state
    * `partner_bearing ∈ {:none, :north, :east, :south, :west}` — the
      bird's belief about the relative direction of the loudest
      audible matching partner.

  ## A matrix
    * `P(hearing_bearing | partner_bearing)` — sharp (delta-like with
      noise floor): observed bearing matches the inferred bearing
      most of the time.
    * `P(hearing_amp | partner_bearing)` — when bearing != :none, amp
      distributes across `:soft / :medium / :loud` (the partner
      sometimes sings, sometimes silent); when bearing == :none, amp
      sharply on `:silence`.
    * `P(hearing_token | partner_bearing)` — when bearing != :none,
      uniform over the song alphabet (open-minded about partner's
      identity; preference is encoded in C, not in A); when bearing
      == :none, sharp on `:none`.
    * `P(wall_sig | partner_bearing)` — uniform (no factor coupling).
    * `P(self_sang_token | partner_bearing)` — uniform (action-driven,
      not state-driven).

  ## B matrix (per action)
    * Movement actions update `partner_bearing` per the geometric
      heuristic in `bearing_transition/2`:
      - aligned (move toward partner): bearing usually preserved,
        sometimes becomes :none (crossed through);
      - anti-aligned (move away): bearing preserved with high
        probability of becoming :none (out of range);
      - perpendicular: bearing mostly preserved with small drift;
      - bearing == :none: stays :none with small detection probability.
    * `:stay` and `:sing_*`: identity-with-tiny-drift.

  ## C
    Same as Simple/Complex — peaks on `(hearing_amp = :loud,
    hearing_token = preferred_token)`. The same C produces convergent
    behaviour because A now ties hearing to bearing.

  Defaults: `policy_depth: 1`, `horizon: 1`. (n_states = 5 means even
  depth 2 = 81 policies is fast; depth 1 is sufficient for the EFE
  pragmatic gradient to point toward the partner.)
  """
  @spec convergent(keyword()) :: map()
  def convergent(opts) do
    width = Keyword.fetch!(opts, :width)
    height = Keyword.fetch!(opts, :height)
    preferred = Keyword.fetch!(opts, :preferred_token)
    validate_token!(preferred)

    pref_strength = clamp_preference(Keyword.get(opts, :preference_strength, 4.0))
    policy_depth = Keyword.get(opts, :policy_depth, 1)
    horizon = Keyword.get(opts, :horizon, policy_depth)
    softmax_temp = Keyword.get(opts, :softmax_temperature, 1.0)
    action_selection = Keyword.get(opts, :action_selection, :sample)

    n_obs = MeadowObsAdapter.n_obs()
    bearings = bearing_states()
    n_states = length(bearings)
    actions = meadow_actions()

    a = build_a_convergent()
    b = build_b_convergent(actions)
    c_log = build_c(preferred, pref_strength)
    d = M.uniform(n_states)
    policies = enumerate_policies(actions, policy_depth)
    pomdp = Models.fetch(@pomdp_family_name)

    %{
      a: a,
      b: b,
      c: c_log,
      d: d,
      e: nil,
      actions: actions,
      policies: policies,
      horizon: horizon,
      dims: %{
        n_states: n_states,
        n_obs: n_obs,
        width: width,
        height: height,
        tier: :convergent,
        bearings: bearings
      },
      obs_adapter: MeadowObsAdapter,
      precision_vector: nil,
      learning_enabled: false,
      softmax_temperature: softmax_temp,
      action_selection: action_selection,
      bundle_id: generate_bundle_id(),
      spec_id: nil,
      family_id: @pomdp_family_name,
      primary_equation_ids: pomdp.source_basis,
      verification_status: :verified_against_source,
      meadow_meta: %{tier: :convergent, preferred_token: preferred}
    }
  end

  @doc "The 5-way `partner_bearing` state alphabet."
  @spec bearing_states() :: [atom()]
  def bearing_states, do: [:none, :north, :east, :south, :west]

  # -- Convergent A matrix ----------------------------------------------------

  defp build_a_convergent do
    n_obs = MeadowObsAdapter.n_obs()
    bearings = bearing_states()
    n_states = length(bearings)

    p_wall = 0.5

    # Amp distribution conditional on partner_bearing.
    p_amp_present = %{silence: 0.30, soft: 0.25, medium: 0.25, loud: 0.20}
    p_amp_absent = %{silence: 0.85, soft: 0.05, medium: 0.05, loud: 0.05}

    p_self = 1.0 / length(MeadowObsAdapter.self_sang_values())

    rows =
      for o <- 0..(n_obs - 1) do
        {_ws_o, amp_o, tok_o, brg_o, _self_o} = MeadowObsAdapter.decode_index(o)

        for s_idx <- 0..(n_states - 1) do
          bearing_s = Enum.at(bearings, s_idx)

          p_amp =
            case bearing_s do
              :none -> Map.fetch!(p_amp_absent, amp_o)
              _ -> Map.fetch!(p_amp_present, amp_o)
            end

          p_tok =
            case bearing_s do
              :none ->
                if tok_o == :none, do: 0.85, else: 0.15 / 4
              _ ->
                # Open across all tokens including :none (partner sometimes silent).
                1.0 / length(MeadowObsAdapter.token_values())
            end

          p_brg =
            cond do
              bearing_s == :none and brg_o == :none -> 0.85
              bearing_s == :none -> 0.15 / 4
              brg_o == bearing_s -> 0.85
              brg_o == :none -> 0.05
              true -> 0.10 / 3
            end

          p_wall * p_amp * p_tok * p_brg * p_self
        end
      end

    renormalise_columns(rows)
  end

  # -- Convergent B matrix ----------------------------------------------------

  defp build_b_convergent(actions) do
    bearings = bearing_states()

    Enum.into(actions, %{}, fn action ->
      mat =
        for next_idx <- 0..(length(bearings) - 1) do
          for curr_idx <- 0..(length(bearings) - 1) do
            curr_b = Enum.at(bearings, curr_idx)
            next_b = Enum.at(bearings, next_idx)
            bearing_transition_prob(action, curr_b, next_b)
          end
        end

      {action, renormalise_columns(mat)}
    end)
  end

  @doc """
  Probability `P(partner_bearing_next | partner_bearing_curr, action)`.

  Encodes the bird's MODEL of how its own movements should update its
  belief about the partner's relative bearing. The model is a heuristic
  approximation to the true geometry — its accuracy doesn't need to be
  perfect; it only needs to make movement-aligned-with-bearing more
  attractive under EFE than movement-opposite-to-bearing.
  """
  @spec bearing_transition_prob(atom(), atom(), atom()) :: float()
  def bearing_transition_prob(action, curr, next) do
    Map.get(bearing_transition(action, curr), next, 0.0)
  end

  defp bearing_transition(action, curr) do
    cond do
      action == :stay or sing_action?(action) ->
        # Identity with tiny drift to keep B strictly positive (avoids log(0) in VFE).
        identity_transition(curr)

      action in @movement_actions ->
        direction = movement_direction(action)
        movement_bearing_transition(direction, curr)

      true ->
        identity_transition(curr)
    end
  end

  defp sing_action?(action) when is_atom(action) do
    String.starts_with?(Atom.to_string(action), "sing_")
  end

  defp movement_direction(:move_north), do: :north
  defp movement_direction(:move_south), do: :south
  defp movement_direction(:move_east), do: :east
  defp movement_direction(:move_west), do: :west

  defp opposite_direction(:north), do: :south
  defp opposite_direction(:south), do: :north
  defp opposite_direction(:east), do: :west
  defp opposite_direction(:west), do: :east

  defp identity_transition(curr) do
    others = bearing_states() -- [curr]
    drift_each = 0.05 / length(others)

    Map.merge(
      %{curr => 0.95},
      Map.new(others, fn b -> {b, drift_each} end)
    )
  end

  defp movement_bearing_transition(_direction, :none) do
    # Partner unknown — small chance of detection in any direction.
    %{:none => 0.85, :north => 0.0375, :east => 0.0375, :south => 0.0375, :west => 0.0375}
  end

  defp movement_bearing_transition(direction, curr) do
    cond do
      curr == direction ->
        # Aligned (moving toward partner). Bearing usually preserved; sometimes
        # the bird crosses through and the source moves to :none (or the
        # partner is now too close to localise).
        others = bearing_states() -- [curr, :none]
        drift_each = 0.20 / length(others)

        Map.merge(
          %{curr => 0.50, :none => 0.30},
          Map.new(others, fn b -> {b, drift_each} end)
        )

      curr == opposite_direction(direction) ->
        # Anti-aligned (moving away from partner). Higher chance of losing
        # the source entirely (out of range).
        others = bearing_states() -- [curr, :none]
        drift_each = 0.20 / length(others)

        Map.merge(
          %{curr => 0.40, :none => 0.40},
          Map.new(others, fn b -> {b, drift_each} end)
        )

      true ->
        # Perpendicular movement. Bearing mostly preserved with small drift.
        others = bearing_states() -- [curr, :none]
        drift_each = 0.20 / length(others)

        Map.merge(
          %{curr => 0.70, :none => 0.10},
          Map.new(others, fn b -> {b, drift_each} end)
        )
    end
  end

  # -- Shared helpers ---------------------------------------------------------

  @doc "Canonical action vocabulary used by all meadow tiers."
  @spec meadow_actions() :: [atom()]
  def meadow_actions do
    sing = Enum.map(Blanket.meadow_song_tokens(), fn t -> :"sing_#{t}" end)
    [:stay | @movement_actions] ++ sing
  end

  @doc "Build C log-preference vector peaked at the preferred token."
  @spec build_c(atom(), float()) :: [float()]
  def build_c(preferred_token, strength) do
    n_obs = MeadowObsAdapter.n_obs()

    logits =
      for idx <- 0..(n_obs - 1) do
        {_ws, amp, token, _bearing, _self} = MeadowObsAdapter.decode_index(idx)

        cond do
          token == preferred_token and amp == :loud -> strength
          token == preferred_token and amp == :medium -> strength * 0.75
          token == preferred_token and amp == :soft -> strength * 0.25
          true -> 0.0
        end
      end

    softmax_to_log(logits)
  end

  @doc """
  Duet-mode C: prefers SILENCE in the listener's hearing channel and
  the listener emitting its own preferred token. Encourages turn-taking.
  """
  @spec build_c_duet(atom(), float()) :: [float()]
  def build_c_duet(preferred_token, strength) do
    n_obs = MeadowObsAdapter.n_obs()

    logits =
      for idx <- 0..(n_obs - 1) do
        {_ws, amp, _token, _bearing, self_sang} = MeadowObsAdapter.decode_index(idx)

        cond do
          self_sang == preferred_token and amp == :silence -> strength
          self_sang == :none and amp == :loud -> strength * 0.75
          self_sang == :none and amp == :medium -> strength * 0.5
          true -> 0.0
        end
      end

    softmax_to_log(logits)
  end

  @doc """
  Enumerate policies as all depth-`d` action sequences for the meadow.

  ## Complexity warning (audit anchor A2, v1.2-hardening)

  This is `|A|^d` — exponential. With the meadow's 9-action vocabulary
  (`[:stay, :move_n/s/e/w, :sing_t1/t2/t3/t4]`):
  depth 1 → 9, depth 2 → 81, depth 3 → 729, depth 4 → 6,561.

  ConvergentBird uses depth 1 by design; SimpleBird and ComplexBird
  default to depth 2 with explicit `:policy_depth` overrides for
  experimental tuning. See [`AgentPlane.BundleBuilder.enumerate_policies/2`](`AgentPlane.BundleBuilder.enumerate_policies/2`)
  for the full scaling table and substrate constraints.
  """
  @spec enumerate_policies([atom], pos_integer()) :: [[atom]]
  def enumerate_policies(actions, depth) when is_list(actions) and depth >= 1 do
    Enum.reduce(1..depth, [[]], fn _, acc ->
      for prefix <- acc, a <- actions, do: prefix ++ [a]
    end)
  end

  defp validate_token!(t) do
    valid = Blanket.meadow_song_tokens()

    unless t in valid do
      raise ArgumentError,
            "Meadow bundle: preferred_token #{inspect(t)} not in alphabet #{inspect(valid)}"
    end
  end

  defp clamp_preference(s) when is_number(s) do
    max(0.0, min(s, 4.0))
  end

  defp generate_bundle_id do
    "meadow-bundle-" <> (:crypto.strong_rand_bytes(8) |> Base.url_encode64(padding: false))
  end

  defp softmax_to_log(logits) do
    c_vec = M.softmax(logits)
    Enum.map(c_vec, &:math.log(max(&1, 1.0e-16)))
  end

  # -- A matrix construction --------------------------------------------------

  # SimpleBird: A factorises as P(wall_sig|s)·P(amp)·P(token)·P(bearing)·P(self_sang)
  # The hearing factors are uniform conditional on s — SimpleBird does not have
  # a generative model of other birds. This is the falsifiable simplification.
  defp build_a_simple(width, height, walls, n_states) do
    n_obs = MeadowObsAdapter.n_obs()

    # P(wall_sig | s) for each s: sharp (0.9 / 0.1) on the true signature.
    p_wall_match = 0.9
    p_wall_mismatch = 1.0 - p_wall_match

    # Uniform factors. Stored as scalars so we can multiply once per (o, s).
    p_amp = 1.0 / length(MeadowObsAdapter.amp_values())
    p_token = 1.0 / length(MeadowObsAdapter.token_values())
    p_bearing = 1.0 / length(MeadowObsAdapter.bearing_values())
    p_self = 1.0 / length(MeadowObsAdapter.self_sang_values())

    uniform_factor = p_amp * p_token * p_bearing * p_self

    wall_sig_per_state = build_wall_sig_per_state(width, height, walls, n_states)

    rows =
      for o <- 0..(n_obs - 1) do
        {ws_o, _amp, _tok, _brg, _self} = MeadowObsAdapter.decode_index(o)

        for s <- 0..(n_states - 1) do
          ws_s = elem(wall_sig_per_state, s)
          p_ws = if ws_s == ws_o, do: p_wall_match, else: p_wall_mismatch
          p_ws * uniform_factor
        end
      end

    renormalise_columns(rows)
  end

  # ComplexBird A: hearing factors depend on (partner_token, partner_present).
  defp build_a_complex(width, height, walls) do
    n_obs = MeadowObsAdapter.n_obs()
    n_pos = width * height
    tokens = MeadowObsAdapter.token_values()
    n_token = length(tokens)
    n_pres = 2
    n_states = n_pos * n_token * n_pres

    p_wall_match = 0.9
    p_wall_mismatch = 1.0 - p_wall_match

    # P(amp | partner_present)
    # When present: amp distributes over {soft, medium, loud}; silence uncommon.
    # When absent: silence dominant; non-silence rare.
    p_amp_present = %{silence: 0.10, soft: 0.30, medium: 0.30, loud: 0.30}
    p_amp_absent = %{silence: 0.85, soft: 0.05, medium: 0.05, loud: 0.05}

    # P(token | partner_token, partner_present)
    # When present: P(token = partner_token) high; P(:none) small leak; rest uniform low.
    # When absent: P(:none) high; rest uniform low.
    p_match_present = 0.85
    p_none_present = 0.05
    p_other_present = (1.0 - p_match_present - p_none_present) / max(n_token - 2, 1)

    p_none_absent = 0.85
    p_other_absent = (1.0 - p_none_absent) / max(n_token - 1, 1)

    p_bearing = 1.0 / length(MeadowObsAdapter.bearing_values())
    p_self = 1.0 / length(MeadowObsAdapter.self_sang_values())

    wall_sig_per_pos = build_wall_sig_per_state(width, height, walls, n_pos)

    # Index encoding (must match decode_state_complex below):
    #   s = pos * n_token * n_pres + pt * n_pres + pp
    rows =
      for o <- 0..(n_obs - 1) do
        {ws_o, amp_o, tok_o, _brg_o, _self_o} = MeadowObsAdapter.decode_index(o)

        for s <- 0..(n_states - 1) do
          {pos_s, pt_idx, pp_idx} = decode_state_complex(s, n_token, n_pres)
          pt_atom = Enum.at(tokens, pt_idx)
          pp_atom = if pp_idx == 1, do: :present, else: :absent

          ws_s = elem(wall_sig_per_pos, pos_s)
          p_ws = if ws_s == ws_o, do: p_wall_match, else: p_wall_mismatch

          p_amp =
            case pp_atom do
              :present -> Map.fetch!(p_amp_present, amp_o)
              :absent -> Map.fetch!(p_amp_absent, amp_o)
            end

          p_tok =
            case pp_atom do
              :present ->
                cond do
                  tok_o == pt_atom -> p_match_present
                  tok_o == :none -> p_none_present
                  true -> p_other_present
                end

              :absent ->
                if tok_o == :none, do: p_none_absent, else: p_other_absent
            end

          p_ws * p_amp * p_tok * p_bearing * p_self
        end
      end

    renormalise_columns(rows)
  end

  defp decode_state_complex(s, n_token, n_pres) do
    pp_idx = rem(s, n_pres)
    rest = div(s, n_pres)
    pt_idx = rem(rest, n_token)
    pos = div(rest, n_token)
    {pos, pt_idx, pp_idx}
  end

  defp encode_state_complex(pos, pt_idx, pp_idx, n_token, n_pres) do
    pos * n_token * n_pres + pt_idx * n_pres + pp_idx
  end

  # -- B matrix construction --------------------------------------------------

  # SimpleBird B: per action, n_states × n_states transition.
  defp build_b_per_action(width, height, walls, actions, n_states) do
    Enum.into(actions, %{}, fn action ->
      mat = build_b_pos_only(width, height, walls, action, n_states)
      {action, mat}
    end)
  end

  # Position-only transition matrix (used by Simple, and as a factor by Complex).
  # Movement actions: 0.97 success, 0.03 stay (matches existing maze).
  # Stay / sing actions: identity.
  defp build_b_pos_only(width, height, walls, action, n_states) do
    walls_set = walls

    rows =
      for s_next <- 0..(n_states - 1) do
        for s_curr <- 0..(n_states - 1) do
          c = rem(s_curr, width)
          r = div(s_curr, width)

          {dc, dr} =
            case action do
              :move_north -> {0, -1}
              :move_south -> {0, 1}
              :move_east -> {1, 0}
              :move_west -> {-1, 0}
              _ -> {0, 0}
            end

          target_c = c + dc
          target_r = r + dr

          target_idx =
            cond do
              target_c < 0 or target_r < 0 or target_c >= width or target_r >= height -> s_curr
              MapSet.member?(walls_set, {target_c, target_r}) -> s_curr
              true -> target_r * width + target_c
            end

          cond do
            action in @movement_actions ->
              cond do
                s_next == target_idx and target_idx != s_curr -> 0.97
                s_next == target_idx and target_idx == s_curr -> 1.0
                s_next == s_curr and target_idx != s_curr -> 0.03
                true -> 0.0
              end

            true ->
              if s_next == s_curr, do: 1.0, else: 0.0
          end
        end
      end

    renormalise_columns(rows)
  end

  # ComplexBird B: factorised over (position, partner_token, partner_present).
  # Materialised as a flat n_states × n_states matrix per action.
  defp build_b_complex(width, height, walls, actions, persistence, token_drift) do
    n_pos = width * height
    tokens = MeadowObsAdapter.token_values()
    n_token = length(tokens)
    n_pres = 2
    n_states = n_pos * n_token * n_pres

    # B_pos[a]: standard wall-aware transition over positions.
    b_pos =
      Enum.into(actions, %{}, fn a ->
        {a, build_b_pos_only(width, height, walls, a, n_pos)}
      end)

    # B_partner_token: action-independent. (1 - drift) on the diagonal,
    # drift uniformly distributed over the n_token - 1 off-diagonals.
    drift_per = token_drift / max(n_token - 1, 1)

    b_pt =
      for next <- 0..(n_token - 1) do
        for curr <- 0..(n_token - 1) do
          if next == curr, do: 1.0 - token_drift, else: drift_per
        end
      end
      |> renormalise_columns()

    # B_partner_present: persistence on the diagonal, (1 - persistence) flip.
    flip = 1.0 - persistence

    b_pp = [
      [persistence, flip],
      [flip, persistence]
    ]

    Enum.into(actions, %{}, fn a ->
      bp = Map.fetch!(b_pos, a)

      mat =
        for s_next <- 0..(n_states - 1) do
          {pos_n, pt_n, pp_n} = decode_state_complex(s_next, n_token, n_pres)

          for s_curr <- 0..(n_states - 1) do
            {pos_c, pt_c, pp_c} = decode_state_complex(s_curr, n_token, n_pres)

            p_pos = bp |> Enum.at(pos_n) |> Enum.at(pos_c)
            p_pt = b_pt |> Enum.at(pt_n) |> Enum.at(pt_c)
            p_pp = b_pp |> Enum.at(pp_n) |> Enum.at(pp_c)

            p_pos * p_pt * p_pp
          end
        end

      {a, renormalise_columns(mat)}
    end)
  end

  defp build_d_complex(width, height, preferred_token) do
    n_pos = width * height
    tokens = MeadowObsAdapter.token_values()
    n_token = length(tokens)
    n_pres = 2

    pref_idx = Enum.find_index(tokens, &(&1 == preferred_token))
    none_idx = Enum.find_index(tokens, &(&1 == :none))

    # P(partner_token): peak on preferred_token (0.6), small leak on :none (0.1),
    # rest uniform low.
    p_pt =
      for i <- 0..(n_token - 1) do
        cond do
          i == pref_idx -> 0.6
          i == none_idx -> 0.1
          true -> (1.0 - 0.6 - 0.1) / max(n_token - 2, 1)
        end
      end

    # Uniform on position, 50/50 on partner_present.
    p_pos = 1.0 / n_pos
    p_pp = 0.5

    d =
      for s <- 0..(n_pos * n_token * n_pres - 1) do
        {_pos, pt_idx, _pp_idx} = decode_state_complex(s, n_token, n_pres)
        p_pos * Enum.at(p_pt, pt_idx) * p_pp
      end

    M.normalise(d)
  end

  # Per-state wall_sig lookup. Returns a tuple indexed by state index.
  defp build_wall_sig_per_state(width, height, walls, n_states) do
    list =
      for s <- 0..(n_states - 1) do
        c = rem(s, width)
        r = div(s, width)
        wall_sig_at(width, height, walls, {c, r})
      end

    List.to_tuple(list)
  end

  defp wall_sig_at(width, height, walls, {c, r}) do
    neighbours = [{c, r - 1}, {c, r + 1}, {c - 1, r}, {c + 1, r}]

    near? =
      Enum.any?(neighbours, fn {nc, nr} ->
        nc < 0 or nr < 0 or nc >= width or nr >= height or MapSet.member?(walls, {nc, nr})
      end)

    if near?, do: :near_wall, else: :open
  end

  defp renormalise_columns(m) do
    cols = M.transpose(m)

    normalised =
      Enum.map(cols, fn col ->
        s = Enum.sum(col)
        if s <= 0.0, do: col, else: Enum.map(col, &(&1 / s))
      end)

    M.transpose(normalised)
  end

  # -- Public state-encoding helpers (used by tests + episode) ---------------

  @doc "Decode a Complex/Resonant state index into its three factors."
  @spec decode_state(non_neg_integer(), pos_integer(), pos_integer()) ::
          {non_neg_integer(), non_neg_integer(), non_neg_integer()}
  def decode_state(s, n_token, n_pres), do: decode_state_complex(s, n_token, n_pres)

  @doc "Encode a Complex/Resonant state."
  @spec encode_state(non_neg_integer(), non_neg_integer(), non_neg_integer(), pos_integer(), pos_integer()) ::
          non_neg_integer()
  def encode_state(pos, pt_idx, pp_idx, n_token, n_pres),
    do: encode_state_complex(pos, pt_idx, pp_idx, n_token, n_pres)
end
