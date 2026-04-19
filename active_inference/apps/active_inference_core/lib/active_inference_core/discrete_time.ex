defmodule ActiveInferenceCore.DiscreteTime do
  @moduledoc """
  Discrete-time Active Inference — POMDP formulation.

  This module implements the algorithms grounded in the following equations
  from the registry:

    * `eq_4_5_pomdp_likelihood`          — A matrix
    * `eq_4_6_pomdp_prior_over_states`   — B^π and D
    * `eq_4_10_efe_linear_algebra`       — G_π linear-algebraic form
    * `eq_4_11_vfe_linear_algebra`       — F_π linear-algebraic form
    * `eq_4_13_state_belief_update`      — state-belief update
    * `eq_4_14_policy_posterior`         — policy posterior
    * `eq_B_5_gradient_descent_states`   — gradient-descent form
    * `eq_B_9_policy_posterior_update`   — canonical posterior with habit E
    * `eq_B_30_efe_per_time`             — per-time-step EFE summed

  The data structures are deliberately plain: vectors as lists, matrices as
  lists of row lists. See `ActiveInferenceCore.Math` for the primitive ops.

  ## Telemetry (plan §8.4)

  Every public function is wrapped in `:telemetry.span/3` under the shared
  event name `[:active_inference_core, :discrete_time, :call]`. Metadata
  carries `{fn: atom, arity: integer}`; the caller is expected to stash
  an agent/context map in `Process.get(:wm_telemetry_context)` for the
  forwarder in `AgentPlane.Telemetry.Bus` to pick up.

  The math module itself never reads the telemetry context — it is pure.

  ## Generative-model bundle

  A POMDP bundle has the shape:

      %{
        a: matrix,          # A — likelihood P(o|s) (rows: obs, cols: state)
        b: %{action => mat} # B_π — transitions P(s'|s) per action
        c: vector,          # C — log-preferences over observations (unnormalised)
        d: vector,          # D — initial-state prior (categorical)
        e: vector | nil,    # E — habit prior over policies; nil ⇒ uniform
        actions: [atom],    # action labels in a fixed order
        policies: [[atom]], # list of action sequences (one per policy)
        horizon: integer    # number of time-steps modelled per episode
      }

  The engine layer (`AgentPlane.ActiveInferenceAgent`) stores this bundle
  inside its agent state and never shares it with the world plane.
  """

  alias ActiveInferenceCore.Math, as: M

  # Plan §8.4 — the xref pass run during `mix test` doesn't always resolve
  # the `:telemetry` dep at the moment this module is compiled; silence the
  # benign "undefined" warning without disabling --warnings-as-errors.
  @compile {:no_warn_undefined, {:telemetry, :span, 3}}

  @typedoc "Per-policy belief tensor: list of state-belief vectors, one per τ."
  @type belief :: [M.vec()]

  @telemetry_event [:active_inference_core, :discrete_time, :call]

  # ---------------------------------------------------------------------------
  # eq_4_5_pomdp_likelihood — observation probabilities from state beliefs
  # ---------------------------------------------------------------------------

  @doc """
  Predicted outcome distribution `o^π_τ = A · s^π_τ` for a state-belief vector.
  (eq. 4.10 line 6 / B.28.)
  """
  @spec predict_obs(M.mat(), M.vec()) :: M.vec()
  def predict_obs(a, s) do
    with_span(:predict_obs, 2, fn -> M.matvec(a, s) end)
  end

  # ---------------------------------------------------------------------------
  # State-belief update — eq. 4.13 / B.5
  # ---------------------------------------------------------------------------

  @doc """
  Single gradient-descent step on the per-(policy, time) state belief.

  Implements eq. 4.13 / B.5.

      ε^π_τ = ln A · o_τ  +  ln B^π_τ · s^π_{τ-1}  +  ln B^π_{τ+1}^T · s^π_{τ+1}  −  ln s^π_τ
      v^π_τ ← v^π_τ + η · ε^π_τ
      s^π_τ = σ(v^π_τ)

  Arguments:

    * `s_prev` — `s^π_{τ-1}` or `nil` at τ=0 (then `D` is used by the caller).
    * `s_curr` — current `s^π_τ`.
    * `s_next` — `s^π_{τ+1}` or `nil` at horizon.
    * `obs` — categorical (one-hot) observation `o_τ` or `nil` if unobserved.
    * `a` — likelihood matrix A.
    * `b_curr` — transition matrix B^π_τ (unused at τ=0; pass any or `nil`).
    * `b_next` — transition matrix B^π_{τ+1} (unused at horizon; pass `nil`).
    * `step_size` — η, defaults to 1.0 (a full-step Bethe-style update).

  Returns the new `s^π_τ`.
  """
  @spec update_state_beliefs(
          M.vec() | nil,
          M.vec(),
          M.vec() | nil,
          M.vec() | nil,
          M.mat(),
          M.mat() | nil,
          M.mat() | nil,
          float()
        ) :: M.vec()
  def update_state_beliefs(s_prev, s_curr, s_next, obs, a, b_curr, b_next, step_size \\ 1.0) do
    with_span(:update_state_beliefs, 8, fn ->
      do_update_state_beliefs(s_prev, s_curr, s_next, obs, a, b_curr, b_next, step_size)
    end)
  end

  defp do_update_state_beliefs(s_prev, s_curr, s_next, obs, a, b_curr, b_next, step_size) do
    likelihood_msg =
      if is_nil(obs) do
        List.duplicate(0.0, length(s_curr))
      else
        M.matvec(M.transpose(M.log_eps_mat(a)), obs)
      end

    past_msg =
      if is_nil(s_prev) or is_nil(b_curr) do
        List.duplicate(0.0, length(s_curr))
      else
        M.matvec(M.log_eps_mat(b_curr), s_prev)
      end

    future_msg =
      if is_nil(s_next) or is_nil(b_next) do
        List.duplicate(0.0, length(s_curr))
      else
        M.matvec(M.transpose(M.log_eps_mat(b_next)), s_next)
      end

    log_s = M.log_eps(s_curr)

    eps = likelihood_msg |> M.add(past_msg) |> M.add(future_msg) |> M.sub(log_s)

    v_new = log_s |> M.add(M.scale(eps, step_size))
    M.softmax(v_new)
  end

  @doc """
  Run `n_iters` sweeps of eq. 4.13 across all (policy, time) pairs.

  `beliefs` is a map `%{policy_index => belief()}` where each belief is a list
  of length `horizon + 1` (τ = 0..horizon) of state-belief vectors.

  `obs_history` is a list of one-hot observation vectors, length equal to the
  number of time-steps elapsed so far (which may be < horizon+1).
  """
  @spec sweep_state_beliefs(
          %{non_neg_integer() => belief()},
          [[atom]],
          map(),
          M.mat(),
          [M.vec()],
          M.vec(),
          pos_integer()
        ) :: %{non_neg_integer() => belief()}
  # Default n_iters reduced from 8 → 3 after the A matrix jumped from
  # 4 obs to 64 obs (wall-signature localization). 3 mean-field sweeps
  # are enough for the belief to converge on a localized posterior
  # given sharp A; 8 was pegging per-step time past 30s at policy_depth 3.
  def sweep_state_beliefs(beliefs, policies, b_per_action, a, obs_history, d, n_iters \\ 3) do
    with_span(:sweep_state_beliefs, 7, fn ->
      do_sweep_state_beliefs(beliefs, policies, b_per_action, a, obs_history, d, n_iters)
    end)
  end

  defp do_sweep_state_beliefs(beliefs, policies, b_per_action, a, obs_history, d, n_iters) do
    # Hoist expensive matrix transforms out of the inner loop. The
    # sweep does n_iters × n_policies × horizon belief updates; each
    # one used to re-transpose log(A) and log-transform every B[a] on
    # the fly. For a 64×n_states A and 4 B matrices that was dominating
    # step time. Precompute once here and thread the cache down.
    log_a_t = M.transpose(M.log_eps_mat(a))
    log_b_per_action = Map.new(b_per_action, fn {k, m} -> {k, M.log_eps_mat(m)} end)

    log_b_t_per_action =
      Map.new(b_per_action, fn {k, m} -> {k, M.transpose(M.log_eps_mat(m))} end)

    cache = %{log_a_t: log_a_t, log_b: log_b_per_action, log_b_t: log_b_t_per_action}

    Enum.reduce(1..n_iters, beliefs, fn _, acc ->
      policies
      |> Enum.with_index()
      |> Enum.reduce(acc, fn {policy, pi}, acc2 ->
        chain = Map.fetch!(acc2, pi)
        new_chain = sweep_one_policy(chain, policy, b_per_action, a, obs_history, d, cache)
        Map.put(acc2, pi, new_chain)
      end)
    end)
  end

  defp sweep_one_policy(chain, policy, b_per_action, a, obs_history, d, cache) do
    len = length(chain)

    # Precompute the expensive log-space transforms once per sweep when
    # no cache was threaded in. Every τ update previously re-computed
    # log(A)^T and log(B[a]) on the fly — dominant cost on the 64-obs
    # A matrix. Reused across the mean-field iterations too.
    log_a_t =
      if cache, do: cache.log_a_t, else: M.transpose(M.log_eps_mat(a))

    _ = a

    last_obs = List.last(obs_history)
    obs_window = [last_obs | List.duplicate(nil, len - 1)]

    for tau <- 0..(len - 1) do
      s_prev = if tau == 0, do: nil, else: Enum.at(chain, tau - 1)
      s_curr = Enum.at(chain, tau)
      s_next = if tau == len - 1, do: nil, else: Enum.at(chain, tau + 1)
      obs = Enum.at(obs_window, tau)

      log_b_curr =
        if tau == 0 do
          nil
        else
          action = Enum.at(policy, tau - 1)

          if cache,
            do: Map.get(cache.log_b, action),
            else: M.log_eps_mat(Map.get(b_per_action, action))
        end

      log_b_t_next =
        if tau == len - 1 do
          nil
        else
          action = Enum.at(policy, tau)

          if cache,
            do: Map.get(cache.log_b_t, action),
            else: M.transpose(M.log_eps_mat(Map.get(b_per_action, action)))
        end

      cond do
        tau == 0 and s_prev == nil and obs == nil ->
          d

        true ->
          do_update_state_beliefs_cached(
            s_prev,
            s_curr,
            s_next,
            obs,
            log_a_t,
            log_b_curr,
            log_b_t_next,
            1.0
          )
      end
    end
  end

  # Cached variant of do_update_state_beliefs — takes already-log'd A
  # and B matrices so the inner loop avoids redundant transforms.
  defp do_update_state_beliefs_cached(
         s_prev,
         s_curr,
         s_next,
         obs,
         log_a_t,
         log_b_curr,
         log_b_t_next,
         step_size
       ) do
    likelihood_msg =
      if is_nil(obs),
        do: List.duplicate(0.0, length(s_curr)),
        else: M.matvec(log_a_t, obs)

    past_msg =
      if is_nil(s_prev) or is_nil(log_b_curr),
        do: List.duplicate(0.0, length(s_curr)),
        else: M.matvec(log_b_curr, s_prev)

    future_msg =
      if is_nil(s_next) or is_nil(log_b_t_next),
        do: List.duplicate(0.0, length(s_curr)),
        else: M.matvec(log_b_t_next, s_next)

    log_s = M.log_eps(s_curr)

    eps = likelihood_msg |> M.add(past_msg) |> M.add(future_msg) |> M.sub(log_s)
    v_new = log_s |> M.add(M.scale(eps, step_size))
    M.softmax(v_new)
  end

  # ---------------------------------------------------------------------------
  # Variational free energy — eq. 4.11 / B.4
  # ---------------------------------------------------------------------------

  @doc """
  Compute F_π = Σ_τ F_{πτ} for one policy given its belief chain.

      F_{πτ} = s^π_τ · ( ln s^π_τ − ln A · o_τ − ln B^π_τ s^π_{τ-1} )

  At τ=0, the transition term uses D in place of B^π_0 s^π_{-1}.
  """
  @spec variational_free_energy(belief(), [atom], map(), M.mat(), [M.vec()], M.vec()) :: float()
  def variational_free_energy(chain, policy, b_per_action, a, obs_history, d) do
    with_span(:variational_free_energy, 6, fn ->
      do_variational_free_energy(chain, policy, b_per_action, a, obs_history, d)
    end)
  end

  defp do_variational_free_energy(chain, policy, b_per_action, a, obs_history, d) do
    # Same receding-horizon semantics as sweep_one_policy: only the
    # latest observation anchors chain[0]; future τ slots have no
    # likelihood term (nil obs).
    last_obs = List.last(obs_history)
    obs_window = [last_obs | List.duplicate(nil, length(chain) - 1)]

    chain
    |> Enum.with_index()
    |> Enum.reduce(0.0, fn {s_tau, tau}, acc ->
      log_s = M.log_eps(s_tau)

      log_likelihood =
        case Enum.at(obs_window, tau) do
          nil -> List.duplicate(0.0, length(s_tau))
          o -> M.matvec(M.transpose(M.log_eps_mat(a)), o)
        end

      log_prior =
        if tau == 0 do
          M.log_eps(d)
        else
          action = Enum.at(policy, tau - 1)
          b = Map.fetch!(b_per_action, action)
          s_prev = Enum.at(chain, tau - 1)
          M.log_eps(M.matvec(b, s_prev))
        end

      contribution =
        s_tau
        |> M.dot(M.sub(log_s, M.add(log_likelihood, log_prior)))

      acc + contribution
    end)
  end

  # ---------------------------------------------------------------------------
  # Expected free energy — eq. 4.10 / B.30
  # ---------------------------------------------------------------------------

  @doc """
  Compute G_π = Σ_τ G_{πτ} where
      G_{πτ} = H · s^π_τ + o^π_τ · ( ln o^π_τ − ln C_τ ).

  Only the "future" portion of the belief chain contributes (τ > t_now),
  since G measures prospective value. Pass `t_now = -1` to sum from τ=0.

  `c_log` is `ln C`. `C` is assumed constant over time when a single vector
  is supplied; to vary C by τ, pass a list-of-vectors `c_log_per_tau`.
  """
  @spec expected_free_energy(belief(), M.mat(), M.vec() | [M.vec()], integer()) :: %{
          total: float(),
          per_tau: [float()],
          ambiguity_per_tau: [float()],
          risk_per_tau: [float()]
        }
  def expected_free_energy(chain, a, c_log, t_now \\ -1) do
    with_span(:expected_free_energy, 4, fn ->
      do_expected_free_energy(chain, a, c_log, t_now)
    end)
  end

  defp do_expected_free_energy(chain, a, c_log, t_now) do
    h = M.ambiguity_vector(a)

    c_log_per_tau =
      case c_log do
        [h1 | _] = list when is_list(h1) -> list
        vec when is_list(vec) -> List.duplicate(vec, length(chain))
      end

    chain
    |> Enum.with_index()
    |> Enum.reduce(
      %{total: 0.0, per_tau: [], ambiguity_per_tau: [], risk_per_tau: []},
      fn {s_tau, tau}, acc ->
        if tau <= t_now do
          acc
        else
          # Call the inner math directly — a predict_obs span for every
          # (policy × τ) cell would drown the event stream.
          o_pi = M.matvec(a, s_tau)
          log_o = M.log_eps(o_pi)
          c_tau = Enum.at(c_log_per_tau, min(tau, length(c_log_per_tau) - 1))

          ambiguity = M.dot(h, s_tau)
          risk = M.dot(o_pi, M.sub(log_o, c_tau))
          g_tau = ambiguity + risk

          %{
            total: acc.total + g_tau,
            per_tau: acc.per_tau ++ [g_tau],
            ambiguity_per_tau: acc.ambiguity_per_tau ++ [ambiguity],
            risk_per_tau: acc.risk_per_tau ++ [risk]
          }
        end
      end
    )
  end

  # ---------------------------------------------------------------------------
  # Policy posterior — eq. 4.14 / B.9
  # ---------------------------------------------------------------------------

  @doc """
  Compute posterior over policies.

      π = σ( ln E  −  F  −  G )

  * `f_vec` — per-policy VFE.
  * `g_vec` — per-policy EFE.
  * `e_vec` — habit prior (pass `nil` for uniform).
  """
  @spec policy_posterior([float()], [float()], M.vec() | nil, float()) :: M.vec()
  def policy_posterior(f_vec, g_vec, e_vec \\ nil, temperature \\ 1.0) do
    with_span(:policy_posterior, 3, fn ->
      do_policy_posterior(f_vec, g_vec, e_vec, temperature)
    end)
  end

  defp do_policy_posterior(f_vec, g_vec, e_vec, temperature) do
    log_e =
      case e_vec do
        nil -> List.duplicate(0.0, length(f_vec))
        list -> M.log_eps(list)
      end

    neg_f = Enum.map(f_vec, &(-&1))
    neg_g = Enum.map(g_vec, &(-&1))
    t = max(temperature, 1.0e-6)

    log_e
    |> M.add(neg_f)
    |> M.add(neg_g)
    |> Enum.map(&(&1 / t))
    |> M.softmax()
  end

  # ---------------------------------------------------------------------------
  # End-to-end: select an action from the current belief state
  # ---------------------------------------------------------------------------

  @doc """
  Run one full inference + planning step and return the action to execute next.

  Inputs:
    * `bundle` — generative-model bundle (see module docstring).
    * `beliefs` — current `%{policy_index => belief()}`.
    * `obs_history` — list of one-hot observation vectors so far (length T+1).
    * `t_now` — current 0-based time-step, i.e. the last τ that was observed.

  Returns:
      %{
        action: atom,
        policy_posterior: vec,
        f: [float],
        g: [float],
        beliefs: updated beliefs,
        telemetry: %{...}
      }
  """
  @spec choose_action(map(), %{non_neg_integer() => belief()}, [M.vec()], integer()) :: map()
  def choose_action(bundle, beliefs, obs_history, t_now) do
    with_span(:choose_action, 4, fn ->
      do_choose_action(bundle, beliefs, obs_history, t_now)
    end)
  end

  defp do_choose_action(bundle, beliefs, obs_history, _t_now) do
    %{a: a, b: b_per_action, c: c, d: d, e: e, policies: policies} = bundle

    c_log =
      case c do
        [h | _] = list when is_list(h) -> list
        vec when is_list(vec) -> vec
      end

    # Receding-horizon. `bundle.d` is set by the caller (Plan /
    # SophisticatedPlan) to the agent's previous-step marginal, so the
    # sweep's τ=0 prior is anchored at the agent's current belief —
    # not the original point-mass-at-start D. On step 0 the incoming
    # beliefs map is empty; fresh_beliefs rolls the (updated) D
    # forward. On subsequent steps we reuse the previous chain so the
    # per-policy rollouts retain their history-informed future
    # predictions.
    beliefs =
      if map_size(beliefs) == 0,
        do: fresh_beliefs(bundle),
        else: beliefs

    beliefs = sweep_state_beliefs(beliefs, policies, b_per_action, a, obs_history, d)

    # Receding-horizon: chain[0] is "now" (swept with the latest obs),
    # chain[1..H] are pure predictions. EFE therefore scores everything
    # past τ=0 as "future" — we pass `t_now_eff = 0` to the
    # expected-free-energy loop so its `tau <= t_now` guard drops only
    # the current state and includes every rollout step.
    t_now_eff = 0

    f_vec =
      policies
      |> Enum.with_index()
      |> Enum.map(fn {policy, pi} ->
        variational_free_energy(Map.fetch!(beliefs, pi), policy, b_per_action, a, obs_history, d)
      end)

    efe_per_policy =
      policies
      |> Enum.with_index()
      |> Enum.map(fn {_policy, pi} ->
        expected_free_energy(Map.fetch!(beliefs, pi), a, c_log, t_now_eff)
      end)

    g_vec = Enum.map(efe_per_policy, & &1.total)

    # Softmax temperature defaults to 2.0 so the policy posterior isn't
    # dominated by micro-differences in F/G when no horizon-H policy can
    # reach the goal. Deterministic callers can pin `:softmax_temperature`
    # to 1.0 on their bundle to recover the textbook σ(ln E − F − G) form.
    temperature = Map.get(bundle, :softmax_temperature, 2.0)
    pi_post = policy_posterior(f_vec, g_vec, e, temperature)

    # Receding-horizon controller: **always take the first action of the
    # selected policy**. Re-planning happens every step, so indexing into
    # `policies[t_now+1]` (the old behaviour) was wrong — when t_now ≥
    # horizon it fell off the end and repeated a single action forever.
    #
    # Selection mode is `:sample` by default — sample from π — because on
    # adversarial mazes (Deceptive Dead End, …) every horizon-H policy has
    # near-identical EFE, and pure `:argmax` picks the first-enumerated
    # policy deterministically, producing infinite wall-bumps. Callers
    # that need a deterministic agent can opt back into argmax via the
    # bundle's `:action_selection` field.
    selection_mode = Map.get(bundle, :action_selection, :sample)

    best_idx =
      case selection_mode do
        :argmax ->
          {_best_prob, idx} =
            pi_post
            |> Enum.with_index()
            |> Enum.max_by(fn {p, _} -> p end)

          idx

        _ ->
          sample_index(pi_post)
      end

    best_policy = Enum.at(policies, best_idx)
    action = List.first(best_policy)

    # Phase L — the best-policy's belief chain is already available in
    # `beliefs[best_idx]`; surface it so Plan/Episode can forward it
    # to the UI for the trajectory overlay.
    best_chain = Map.get(beliefs, best_idx, [])

    %{
      action: action,
      policy_posterior: pi_post,
      f: f_vec,
      g: g_vec,
      efe_per_policy: efe_per_policy,
      beliefs: beliefs,
      # chain[0] IS "now" under receding-horizon semantics — the
      # heatmap reads belief at τ=0 (current position estimate), not
      # the rollout endpoint.
      marginal_state_belief: marginal_over_policies(beliefs, pi_post, 0),
      best_policy_chain: best_chain,
      telemetry: %{
        policies: policies,
        best_policy_index: best_idx,
        selected_action: action,
        best_policy_chain: best_chain
      }
    }
  end

  @doc "Marginalise state beliefs over the policy posterior at a given time-step."
  @spec marginal_over_policies(%{non_neg_integer() => belief()}, M.vec(), integer()) :: M.vec()
  def marginal_over_policies(beliefs, pi_post, t_now) do
    with_span(:marginal_over_policies, 3, fn ->
      do_marginal_over_policies(beliefs, pi_post, t_now)
    end)
  end

  defp do_marginal_over_policies(beliefs, pi_post, t_now) do
    # Receding-horizon guard — each policy's belief chain is length
    # (policy_depth + 1); after the agent has taken more steps than
    # that, `t_now` would index past the chain and fall back to
    # chain[0] (the rollout's origin = D = point mass at start),
    # which makes the belief heatmap snap back to "I'm at start"
    # even though the agent has moved on. Cap tau at the last
    # valid chain index so we always render the planner's terminal
    # predicted marginal instead.
    first_chain = beliefs |> Map.values() |> List.first()
    chain_len = if is_list(first_chain), do: length(first_chain), else: 0
    tau = max(t_now, 0) |> min(max(chain_len - 1, 0))

    beliefs
    |> Enum.sort_by(fn {pi, _} -> pi end)
    |> Enum.reduce(nil, fn {pi, chain}, acc ->
      s = Enum.at(chain, tau) || List.first(chain)
      p = Enum.at(pi_post, pi)
      scaled = M.scale(s, p)

      if is_nil(acc), do: scaled, else: M.add(acc, scaled)
    end)
    |> M.normalise()
  end

  # ---------------------------------------------------------------------------
  # Initialisers
  # ---------------------------------------------------------------------------

  @doc """
  Build a fresh `%{policy_index => belief()}` by rolling D forward under each
  policy's B^π. This is the clean prior predictive, which is also the correct
  starting point for a VMP sweep — the alternative (uniform or D-at-every-τ)
  causes the future-message term in eq. 4.13 to pull beliefs toward τ=0.
  """
  @spec fresh_beliefs(map()) :: %{non_neg_integer() => belief()}
  def fresh_beliefs(bundle) do
    with_span(:fresh_beliefs, 1, fn -> do_fresh_beliefs(bundle) end)
  end

  defp do_fresh_beliefs(bundle) do
    %{d: d, horizon: h, b: b_per_action, policies: policies} = bundle

    policies
    |> Enum.with_index()
    |> Enum.into(%{}, fn {policy, pi} -> {pi, rollout_forward(d, policy, b_per_action, h)} end)
  end

  @doc "Pure forward predictive rollout: s^π_0 = D, s^π_{τ+1} = B^π_τ s^π_τ."
  @spec rollout_forward(M.vec(), [atom()], map(), non_neg_integer()) :: belief()
  def rollout_forward(d, policy, b_per_action, horizon) do
    with_span(:rollout_forward, 4, fn -> do_rollout_forward(d, policy, b_per_action, horizon) end)
  end

  defp do_rollout_forward(d, policy, b_per_action, horizon) do
    Enum.reduce(0..(horizon - 1), [d], fn tau, acc ->
      latest = hd(acc)
      action = Enum.at(policy, tau, List.first(policy))
      b = Map.fetch!(b_per_action, action)
      [M.matvec(b, latest) | acc]
    end)
    |> Enum.reverse()
  end

  # ---------------------------------------------------------------------------
  # Telemetry helper — wraps every public call in a uniform span.
  # Plan §8.4. The caller's context (agent_id, spec_id, …) is picked up by
  # the AgentPlane.Telemetry.Bus forwarder via Process.get/1, so no
  # equation registry or agent-plane concerns leak into this pure module.
  # ---------------------------------------------------------------------------
  defp with_span(fn_name, arity, body_fn) do
    meta = %{fn: fn_name, arity: arity}

    :telemetry.span(@telemetry_event, meta, fn ->
      result = body_fn.()
      {result, meta}
    end)
  end

  # Draw one index according to the categorical distribution `p`.
  # Expects `p` to be non-negative and approximately normalised; we do
  # not re-normalise here (the caller hands us softmaxed output).
  defp sample_index(p) when is_list(p) do
    u = :rand.uniform()

    {idx, _} =
      p
      |> Enum.with_index()
      |> Enum.reduce_while({0, 0.0}, fn {pi, i}, {_, acc} ->
        acc = acc + pi
        if u <= acc, do: {:halt, {i, acc}}, else: {:cont, {i, acc}}
      end)

    idx
  end
end
