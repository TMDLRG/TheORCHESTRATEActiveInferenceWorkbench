defmodule AgentPlane.ExactInference do
  @moduledoc """
  Brute-force exact Bayesian inference over a finite-state HMM.

  **This module exists exclusively to verify the variational inference
  identities used by the active-inference path** (`F[Q] ≥ -ln p(y)`,
  `ELBO ≤ ln p(y)`, etc.). It is **not** part of the production
  inference loop and is *deliberately named distinctly* from the
  variational path so the two cannot be confused — see the audit
  adjudication anchor "q is recognition density vs p(η|y) is exact
  posterior under the generative model — separate code paths".

  All functions operate on **bundles** (the same shape produced by
  `AgentPlane.BundleBuilder.*`). They never accept an agent struct as
  input — the exact posterior is a property of the (generative model,
  observation sequence) pair, not of any specific recognition density.

  ## Scope (intentional)

  - Only single-policy / open-loop sequences. No EFE planning here.
  - Only flat (un-factorised) bundles. The factor structure of larger
    bundles makes brute-force enumeration infeasible (n_states grows
    multiplicatively); the bound tests use a 2-state Simple meadow
    where brute force is trivial.
  - Discrete observations (one-hot vectors).

  These restrictions are *not* mathematical limitations of the
  identities being verified — they are practical limits on enumeration.
  The identities themselves hold for any well-formed POMDP.

  ## Identities verified by callers (`agent_plane/test/meadow/*`)

      For any recognition density q over hidden state sequences:

          F[q]   ≥  -ln p(y_{1:T})              (VFE upper-bounds surprisal)
          ELBO[q] ≤  ln p(y_{1:T})               (ELBO lower-bounds log evidence)
          F[q]   =  -ln p(y_{1:T}) + KL(q || p(x|y))   (the textbook decomposition)

  See:
    * Parr, Pezzulo, Friston (2022), eq. 2.5, 2.7, 4.11.
    * The audit's adjudication anchors (project `CLAUDE.md`).
  """

  alias ActiveInferenceCore.Math, as: M

  @typedoc "A flat HMM bundle — the subset of the Active Inference bundle this module needs."
  @type hmm_bundle :: %{
          required(:a) => M.mat(),
          required(:b) => %{atom() => M.mat()},
          required(:d) => M.vec()
        }

  @doc """
  Exact log-evidence `ln p(y_{1:T})` for an observation sequence under
  bundle's prior + transitions, marginalising over **all** hidden-state
  sequences via the standard forward algorithm.

      log p(y_{1:T}) = ln Σ_{x_{1:T}} p(y_{1:T}, x_{1:T})

  The forward algorithm runs in O(T · n_states²) time — feasible for
  the small bundles used in audit tests (n_states ∈ {2, 4, 8}).

  `obs_seq` is a list of one-hot observation vectors of length T (T ≥ 1).
  `actions` is a list of T-1 atoms (the actions taken between successive
  observations). When `actions == []`, the chain is "free dynamics" —
  every transition uses `B[:_]` if present, else the bundle's `:b` map
  must contain a single action whose key the caller specifies via
  `:default_action` opt.
  """
  @spec log_evidence(hmm_bundle(), [M.vec()], [atom()], keyword()) :: float()
  def log_evidence(%{a: a, b: b, d: d}, obs_seq, actions, opts \\ [])
      when is_list(obs_seq) and is_list(actions) do
    if length(obs_seq) - 1 != length(actions) do
      raise ArgumentError,
            "log_evidence: |obs_seq| - 1 must equal |actions| " <>
              "(got #{length(obs_seq)} obs, #{length(actions)} actions)"
    end

    # forward[t][x] = p(y_{1..t}, x_t = x) (unnormalised)
    [first_obs | rest_obs] = obs_seq

    # alpha_0[x] = D[x] · P(y_0 | x)
    alpha0 =
      d
      |> Enum.with_index()
      |> Enum.map(fn {dx, x} ->
        # P(y_0 | x_0 = x) = Σ_o A[o, x] · y_0[o]
        likelihood = obs_likelihood(a, x, first_obs)
        dx * likelihood
      end)

    {alpha_T, _} =
      Enum.zip(rest_obs, actions)
      |> Enum.reduce({alpha0, 0}, fn {y_t, action}, {alpha_prev, _} ->
        b_a = Map.get(b, action) || raise "log_evidence: bundle.b missing action #{inspect(action)}"

        # alpha_t[x] = (Σ_x' alpha_{t-1}[x'] · B[a][x, x']) · P(y_t | x)
        alpha_t =
          for x <- 0..(length(alpha_prev) - 1) do
            row = Enum.at(b_a, x)
            transit = Enum.zip(row, alpha_prev) |> Enum.reduce(0.0, fn {p, a_prev}, acc -> acc + p * a_prev end)
            transit * obs_likelihood(a, x, y_t)
          end

        {alpha_t, action}
      end)

    _ = opts
    sum = Enum.sum(alpha_T)
    :math.log(max(sum, 1.0e-300))
  end

  @doc """
  Exact posterior `p(x_{1:T} | y_{1:T})` as a list of categorical
  distributions over hidden states (forward-backward).

  Returned: list of length T, each entry a length-n_states distribution.
  """
  @spec posterior_exact(hmm_bundle(), [M.vec()], [atom()]) :: [M.vec()]
  def posterior_exact(%{a: a, b: b, d: d}, obs_seq, actions) do
    if length(obs_seq) - 1 != length(actions) do
      raise ArgumentError,
            "posterior_exact: |obs_seq| - 1 must equal |actions|"
    end

    [first_obs | rest_obs] = obs_seq

    # Forward
    alpha0 =
      d
      |> Enum.with_index()
      |> Enum.map(fn {dx, x} -> dx * obs_likelihood(a, x, first_obs) end)

    forwards =
      Enum.zip(rest_obs, actions)
      |> Enum.reduce([alpha0], fn {y_t, action}, acc ->
        prev = hd(acc)
        b_a = Map.fetch!(b, action)

        alpha =
          for x <- 0..(length(prev) - 1) do
            row = Enum.at(b_a, x)
            transit = Enum.zip(row, prev) |> Enum.reduce(0.0, fn {p, a_prev}, sum -> sum + p * a_prev end)
            transit * obs_likelihood(a, x, y_t)
          end

        [alpha | acc]
      end)
      |> Enum.reverse()

    # Backward
    n_states = length(d)
    last_beta = List.duplicate(1.0, n_states)

    backwards =
      Enum.zip(rest_obs, actions)
      |> Enum.reverse()
      |> Enum.reduce([last_beta], fn {y_t, action}, acc ->
        next_beta = hd(acc)
        b_a = Map.fetch!(b, action)

        # beta_{t}[x] = Σ_{x'} B[a][x', x] · P(y_{t+1} | x') · beta_{t+1}[x']
        beta_t =
          for x <- 0..(n_states - 1) do
            Enum.reduce(0..(n_states - 1), 0.0, fn xp, acc_xp ->
              p_trans = Enum.at(Enum.at(b_a, xp), x)
              p_em = obs_likelihood(a, xp, y_t)
              acc_xp + p_trans * p_em * Enum.at(next_beta, xp)
            end)
          end

        [beta_t | acc]
      end)

    # Combine and normalise per-time-step.
    Enum.zip(forwards, backwards)
    |> Enum.map(fn {alpha, beta} ->
      M.normalise(M.hadamard(alpha, beta))
    end)
  end

  @doc """
  Mean-field variational free energy of a fully-factorised
  recognition density `q(x_{0:T}) = ∏_t q_t(x_t)`, given the bundle
  and observation sequence.

  This is the **textbook** chain VFE used to verify the bound
  `F[q] ≥ -ln p(y)` (saturating at the joint exact posterior **only**
  when that posterior factorises, which is not generally the case for
  HMMs with non-deterministic dynamics — the mean-field bound is
  strict for most q).

  Distinct from `ActiveInferenceCore.DiscreteTime.variational_free_energy/6`,
  which uses the receding-horizon `log(B·s_{τ-1})` form (a Jensen tightening
  that is appropriate for the per-policy rollout but does **not** in
  general satisfy the joint mean-field bound). Both are valid VFEs of
  different recognition structures; the bound test specifically
  exercises the textbook mean-field form so the audit-anchor
  inequality is verified against its canonical derivation.

      F[q] = Σ_t E_{q_t}[ ln q_t(x_t) ]
              - E_{q_0}[ ln p(y_0 | x_0) + ln p(x_0) ]
              - Σ_{t>0} E_{q_t}[ ln p(y_t | x_t) ]
              - Σ_{t>0} E_{q_t, q_{t-1}}[ ln p(x_t | x_{t-1}, a_{t-1}) ]

  The cross-term `E_{q_t, q_{t-1}}[ ln B_a[x_t, x_{t-1}] ]`
  factorises under mean-field as
  `q_t · (log_B_a · q_{t-1})` where `log_B_a` is the element-wise log
  of `B_a` (rows = x_t, cols = x_{t-1}).
  """
  @spec free_energy(hmm_bundle(), [M.vec()], [M.vec()], [atom()]) :: float()
  def free_energy(%{a: a, b: b, d: d}, q_chain, obs_seq, actions) do
    if length(q_chain) != length(obs_seq) do
      raise ArgumentError, "free_energy: |q_chain| must equal |obs_seq|"
    end

    if length(actions) != length(q_chain) - 1 do
      raise ArgumentError, "free_energy: |actions| must equal |q_chain| - 1"
    end

    log_a_t = M.transpose(M.log_eps_mat(a))

    Enum.zip([q_chain, obs_seq, [nil | actions]])
    |> Enum.with_index()
    |> Enum.reduce(0.0, fn {{q_t, y_t, action}, t}, acc ->
      log_q = M.log_eps(q_t)
      log_likelihood = M.matvec(log_a_t, y_t)

      log_prior =
        if t == 0 do
          M.log_eps(d)
        else
          q_prev = Enum.at(q_chain, t - 1)
          b_a = Map.fetch!(b, action)
          # Mean-field cross-term: E_{q_{t-1}}[log B_a[x_t, x_{t-1}]]
          # = sum over x_{t-1} of q_prev[x_{t-1}] * log B_a[x_t, x_{t-1}]
          # = (log_B_a · q_prev)[x_t] — NOT log(B_a · q_prev), which is
          # a Jensen-tighter inequality that does not give the textbook
          # mean-field bound.
          M.matvec(M.log_eps_mat(b_a), q_prev)
        end

      contrib = M.dot(q_t, M.sub(log_q, M.add(log_likelihood, log_prior)))
      acc + contrib
    end)
  end

  @doc """
  ELBO of a recognition `q` chain. Convention: `ELBO = -F[q]`. Pure
  arithmetic identity — this function is just sugar around `free_energy/4`
  to keep the bound-test names readable.
  """
  @spec elbo(hmm_bundle(), [M.vec()], [M.vec()], [atom()]) :: float()
  def elbo(bundle, q_chain, obs_seq, actions) do
    -free_energy(bundle, q_chain, obs_seq, actions)
  end

  # -- Internal ---------------------------------------------------------------

  # P(y_t | x_t = x) where y_t is a one-hot vector.
  defp obs_likelihood(a, x, y_t) do
    a
    |> Enum.with_index()
    |> Enum.reduce(0.0, fn {row, o}, acc ->
      acc + Enum.at(row, x) * Enum.at(y_t, o)
    end)
  end
end
