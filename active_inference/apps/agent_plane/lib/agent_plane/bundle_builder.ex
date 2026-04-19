defmodule AgentPlane.BundleBuilder do
  @moduledoc """
  Construct the POMDP generative-model bundle consumed by
  `ActiveInferenceCore.DiscreteTime`.

  The bundle is built **in the agent plane**, from information the user
  configures in the UI. The world plane is never asked for its grid layout;
  the bundle represents the agent's *belief* about the environment, not the
  ground truth.

  In a fully Bayesian workflow, the agent's A and B would be *learned*. Here,
  for the MVP, we build a reasonable starting model using the maze's width
  and height as the cardinality of the hidden-state space (one state per tile).
  This is still a legitimate Active Inference agent: the key constraint is
  that the bundle it uses is *its own* — the world plane keeps its own
  independent truth.
  """

  alias ActiveInferenceCore.Math, as: M
  alias ActiveInferenceCore.Models
  alias AgentPlane.ObsAdapter

  # Plan §7.1 — POMDP is the MVP-primary family (see models.ex). The maze
  # bundle is a POMDP, so every bundle it builds is grounded in the family's
  # source_basis.
  @pomdp_family_name "Partially Observable Markov Decision Process (POMDP)"

  @doc """
  Build a bundle for a maze-style task.

  Required options:

    * `:width` — integer width of the grid the agent models (tiles).
    * `:height` — integer height.
    * `:start_idx` — 0-based flat index of the believed start tile.
    * `:goal_idx` — 0-based flat index of the believed goal tile.
    * `:walls` — list of 0-based flat indices the agent believes to be walls.
    * `:blanket` — `SharedContracts.Blanket` describing the channels.
    * `:horizon` — planning horizon T (integer, default 6).
    * `:policy_depth` — how many action steps per policy (default horizon).
    * `:preference_strength` — scalar for the log-preference on the goal tile (default 4.0).
    * `:habit_prior` — optional vector `E` over policies; nil ⇒ uniform.
    * `:precision_vector` — optional list of per-observation precision
      multipliers (length `n_obs`).  Cookbook recipes that want to stretch or
      collapse the A columns without re-specifying A pass this.
    * `:c_preference_override` — optional list of per-observation log-preferences
      (length `n_obs`).  If given, replaces the default goal/hit C entirely.
      Cookbook preference/pragmatic recipes (G6) use this to reshape C.
    * `:learning_enabled` — boolean.  When true, the Dirichlet-update actions
      (`AgentPlane.Actions.DirichletUpdateA` / `DirichletUpdateB`) are allowed
      to mutate the A / B posteriors.  Default false.

  Options not relevant to all mazes (like `:start_idx`) may be inferred by
  the caller.
  """
  @spec for_maze(keyword()) :: map()
  def for_maze(opts) do
    width = Keyword.fetch!(opts, :width)
    height = Keyword.fetch!(opts, :height)
    start_idx = Keyword.fetch!(opts, :start_idx)
    goal_idx = Keyword.fetch!(opts, :goal_idx)
    walls = Keyword.get(opts, :walls, [])
    blanket = Keyword.fetch!(opts, :blanket)
    horizon = Keyword.get(opts, :horizon, 6)
    pref_strength = Keyword.get(opts, :preference_strength, 4.0)
    wall_hit_penalty = Keyword.get(opts, :wall_hit_penalty, pref_strength)

    n_states = width * height

    # The agent observes a 64-way combined modality:
    #
    #   obs_idx = wall_sig * 4 + goal * 2 + hit
    #
    # where `wall_sig` is a 4-bit code of which sides of the current
    # tile are walls (N=bit0, E=bit1, S=bit2, W=bit3), `goal` is 1 when
    # the agent is on the goal tile, and `hit` is 1 when the last
    # action was blocked. The wall-signature component is the key to
    # localization — in the prebuilt mazes every tile has a unique
    # signature, so observations alone are enough to resolve the
    # agent's belief to a near-point mass after a single sweep.
    n_obs = ObsAdapter.n_obs()
    hit_rate_fn = build_hit_rate_fn(width, height, walls)
    wall_sig_fn = build_wall_sig_fn(width, height, walls)

    # Sharpness of the wall-signature leak. Chosen so the agent's
    # posterior concentrates on a handful of candidate tiles (not a
    # single tile) — perfect localization collapses the heatmap to a
    # single dot and hides the variational richness we want the user
    # to see. 0.55 on the true signature + 0.45 distributed across
    # the other 15 gives ~10× evidence for the matching tile, enough
    # to drive the agent to a meaningful posterior while still showing
    # a small probability cloud.
    p_match = 0.55
    p_miss_each = (1.0 - p_match) / 15.0

    a =
      for o <- 0..(n_obs - 1) do
        {wall_sig_o, rem_after_wall} = {div(o, 4), rem(o, 4)}
        goal_o? = Bitwise.band(rem_after_wall, 2) == 2
        hit_o? = Bitwise.band(rem_after_wall, 1) == 1

        for s <- 0..(n_states - 1) do
          is_goal_s = s == goal_idx
          wall_sig_s = wall_sig_fn.(s)
          hit_rate = hit_rate_fn.(s)

          # P(wall_sig_o | s): sharply peaked at the state's true
          # signature. The other 15 entries share 0.10 equally, so
          # a wrong signature is 15× less likely than the right one.
          p_wall = if wall_sig_o == wall_sig_s, do: p_match, else: p_miss_each

          # P(goal_o | s) and P(hit_o | s) are state-dependent; the
          # joint P(obs | s) is their product (factorised).
          p_goal_given_s = if is_goal_s, do: 0.95, else: 0.05
          p_hit_given_s = hit_rate

          p_goal_factor =
            if goal_o?, do: p_goal_given_s, else: 1.0 - p_goal_given_s

          p_hit_factor =
            if hit_o?, do: p_hit_given_s, else: 1.0 - p_hit_given_s

          p_wall * p_goal_factor * p_hit_factor
        end
      end
      |> renormalise_columns()

    actions = blanket.action_vocabulary

    b =
      Enum.into(actions, %{}, fn action ->
        {action, transition_matrix(n_states, width, height, walls, action)}
      end)

    d =
      0..(n_states - 1)
      |> Enum.map(fn s -> if s == start_idx, do: 1.0, else: 0.0 end)
      |> M.normalise()

    # C on the 64-dim combined modality — per-obs preferences factorise
    # over (wall_sig, goal, hit). The wall signature is uninformative
    # of preference (all 16 signatures are equally "fine"), so the
    # logits depend only on the goal / hit bits:
    #
    #   not_goal_clear →  0                 (neutral baseline)
    #   not_goal_hit   → −wall_hit_penalty  (wall-hit penalty)
    #   goal_clear     → +pref_strength     (goal reward)
    #   goal_hit       → +pref_strength − wall_hit_penalty / 2
    base_logit = fn o ->
      rem_ = rem(o, 4)
      goal? = Bitwise.band(rem_, 2) == 2
      hit? = Bitwise.band(rem_, 1) == 1

      cond do
        goal? and hit? -> pref_strength - wall_hit_penalty / 2.0
        goal? -> pref_strength
        hit? -> -wall_hit_penalty
        true -> 0.0
      end
    end

    # G6 cookbook option: `:c_preference_override` replaces the default
    # goal/hit logits with caller-supplied per-observation preferences.
    c_logits =
      case Keyword.get(opts, :c_preference_override) do
        nil ->
          Enum.map(0..(n_obs - 1), base_logit)

        override when is_list(override) and length(override) == n_obs ->
          override

        bad ->
          raise ArgumentError,
                "c_preference_override must be a list of length #{n_obs}, got #{inspect(bad)}"
      end

    c_vec = M.softmax(c_logits)
    c_log = Enum.map(c_vec, &:math.log(max(&1, 1.0e-16)))

    policies = enumerate_policies(actions, Keyword.get(opts, :policy_depth, horizon))

    pomdp = Models.fetch(@pomdp_family_name)

    # G6 cookbook option: optional per-observation precision vector.
    precision_vector =
      case Keyword.get(opts, :precision_vector) do
        nil ->
          nil

        list when is_list(list) and length(list) == n_obs ->
          list

        bad ->
          raise ArgumentError,
                "precision_vector must be a list of length #{n_obs}, got #{inspect(bad)}"
      end

    %{
      a: a,
      b: b,
      c: c_log,
      d: d,
      e: Keyword.get(opts, :habit_prior, nil),
      actions: actions,
      policies: policies,
      horizon: horizon,
      dims: %{n_states: n_states, n_obs: n_obs, width: width, height: height},

      # G6 cookbook options -- read by the skills and the Dirichlet actions.
      precision_vector: precision_vector,
      learning_enabled: Keyword.get(opts, :learning_enabled, false),

      # Plan §7.1 provenance tuple — foreign keys into the taxonomy + registry.
      # Filled in at build time so the agent, the signal, and the Glass Engine
      # can all trace back to the same source equations.
      bundle_id: generate_bundle_id(),
      spec_id: Keyword.get(opts, :spec_id, nil),
      family_id: @pomdp_family_name,
      primary_equation_ids: pomdp.source_basis,
      verification_status: :verified_against_source
    }
  end

  defp generate_bundle_id do
    "bundle-" <> (:crypto.strong_rand_bytes(8) |> Base.url_encode64(padding: false))
  end

  @doc "Enumerate policies as all depth-`d` action sequences."
  @spec enumerate_policies([atom], pos_integer()) :: [[atom]]
  def enumerate_policies(actions, d) when is_list(actions) and is_integer(d) and d >= 1 do
    Enum.reduce(1..d, [[]], fn _, acc ->
      for prefix <- acc, a <- actions, do: prefix ++ [a]
    end)
  end

  # -- Transition matrices ----------------------------------------------------

  defp transition_matrix(n_states, w, h, walls, action) do
    wall_set = MapSet.new(walls)

    for s_next <- 0..(n_states - 1) do
      for s_curr <- 0..(n_states - 1) do
        c = rem(s_curr, w)
        r = div(s_curr, w)

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
          if target_c < 0 or target_r < 0 or target_c >= w or target_r >= h do
            s_curr
          else
            idx = target_r * w + target_c

            if MapSet.member?(wall_set, idx) do
              s_curr
            else
              idx
            end
          end

        if s_next == target_idx, do: 0.97, else: if(s_next == s_curr, do: 0.03, else: 0.0)
      end
    end
    |> renormalise_columns()
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

  # Returns a fun(state_idx) → 4-bit wall signature in 0..15
  # (N=bit0, E=bit1, S=bit2, W=bit3). Used by A to localize the
  # agent's belief to the tile whose wall pattern it just observed.
  defp build_wall_sig_fn(w, h, walls) do
    wall_set = MapSet.new(walls)

    fn s ->
      c = rem(s, w)
      r = div(s, w)

      neighbours = [
        {{c, r - 1}, 0},
        {{c + 1, r}, 1},
        {{c, r + 1}, 2},
        {{c - 1, r}, 3}
      ]

      Enum.reduce(neighbours, 0, fn {{nc, nr}, bit}, acc ->
        wall? =
          cond do
            nc < 0 or nr < 0 or nc >= w or nr >= h -> true
            MapSet.member?(wall_set, nr * w + nc) -> true
            true -> false
          end

        if wall?, do: Bitwise.bor(acc, Bitwise.bsl(1, bit)), else: acc
      end)
    end
  end

  # Returns a fun(state_idx) → hit_rate ∈ [0.0, 0.5]. Uses the fraction of
  # the state's four cardinal neighbours that are walls or out-of-bounds.
  # A state completely surrounded by walls has hit_rate 0.5 (the cap is
  # chosen so that the softmax in C never saturates on this term).
  defp build_hit_rate_fn(w, h, walls) do
    wall_set = MapSet.new(walls)

    fn s ->
      c = rem(s, w)
      r = div(s, w)

      neighbours = [
        {c, r - 1},
        {c, r + 1},
        {c - 1, r},
        {c + 1, r}
      ]

      wall_count =
        Enum.count(neighbours, fn {nc, nr} ->
          cond do
            nc < 0 or nr < 0 or nc >= w or nr >= h -> true
            MapSet.member?(wall_set, nr * w + nc) -> true
            true -> false
          end
        end)

      wall_count / 4.0 * 0.5
    end
  end
end
