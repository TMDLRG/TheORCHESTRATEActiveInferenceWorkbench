defmodule AgentPlane.Actions.GreedyLoudest do
  @moduledoc """
  Audit-isolation action (external review GW1, v1.3-falsifiability):
  greedy-toward-highest-predicted-pragmatic-value action selection.

  ## What this is and why

  `Plan` selects actions via the full Active Inference machinery:
  variational message passing on per-policy belief chains, EFE
  decomposition into epistemic + pragmatic, softmax over policies,
  sample (or argmax) from the policy posterior.

  `GreedyLoudest` runs on the **same bundle** but replaces the EFE
  machinery with a one-step greedy rule:

      score(a) = E_{q(s_t+1 | a)}[ ln C(o) ]
              = (A · (B[a] · q_t)) · ln C

  Pick argmax. This is pure pragmatic value — *no epistemic value,
  no per-policy belief sweep, no softmax over policies*. The
  variational/EFE machinery is bypassed; the bundle's prior structure
  (A, B, C, D) is the same.

  ## Why this matters for falsifiability

  Wolpert/Gershman in v2 review: ConvergentBird's `partner_bearing`
  factor is a hand-built geometric prior. The matching/orthogonal
  control isolates C-vector contribution; **it doesn't isolate the
  contribution of the inference machinery itself.** If `GreedyLoudest`
  on the same bundle achieves similar convergence to `Plan`, then the
  prior structure (B-matrix bearing transitions) is doing the work,
  not Active Inference.

  Used as Arm 2 in `experiment_one_v2_test.exs`:
    Arm 1: ConvergentBird + Plan (full Active Inference)
    Arm 2: ConvergentBird + GreedyLoudest (pragmatic-greedy)
    Arm 3: Random walk

  Arm 1 ≈ Arm 2 → bundle structure does the work (NFL escape).
  Arm 1 > Arm 2 → EFE machinery contributes specifically.

  ## Math is honest about what gets bypassed

  No mean-field VMP. No KL between predicted and preferred observations
  (epistemic value). No habit-prior weighting. The policy posterior is
  a one-hot at the argmax of the pragmatic score. This is **not** an
  Active Inference algorithm — it is the comparison baseline that
  isolates the contribution of the variational machinery.
  """

  use Jido.Action,
    name: "greedy_loudest",
    description: "Argmax action selection by predicted pragmatic value (GW1 baseline).",
    schema: []

  alias ActiveInferenceCore.Math, as: M
  alias AgentPlane.Telemetry.Context

  @impl true
  def run(_params, context) do
    state = context.state
    bundle = state.bundle

    # Use the agent's current marginal as the prior, falling back to D on
    # tick 0 — same convention as Plan.
    q_curr =
      case state.marginal_state_belief do
        [] -> bundle.d
        [_ | _] = vec -> vec
      end

    log_c =
      case bundle.c do
        [h | _] = list when is_list(h) -> Enum.at(list, 0)
        vec when is_list(vec) -> vec
      end

    # Score each action: predicted next-state = B[a] · q_curr;
    # predicted obs = A · predicted next-state; score = predicted_obs · log_C.
    scores =
      Context.with_agent_context(state, fn ->
        Enum.map(bundle.actions, fn action ->
          b_a = Map.fetch!(bundle.b, action)
          predicted_state = M.matvec(b_a, q_curr)
          predicted_obs = M.matvec(bundle.a, predicted_state)

          # Pragmatic value: dot product of predicted_obs with log_C
          # (high when predicted obs distribution mass falls on preferred
          # observations).
          score =
            Enum.zip(predicted_obs, log_c)
            |> Enum.reduce(0.0, fn {p, lc}, acc -> acc + p * lc end)

          {action, score, predicted_state}
        end)
      end)

    {best_action, _best_score, best_predicted_state} =
      Enum.max_by(scores, fn {_a, score, _p} -> score end)

    # One-hot policy posterior at the chosen action's index.
    n_actions = length(bundle.actions)
    best_idx = Enum.find_index(bundle.actions, &(&1 == best_action))

    pi_post =
      for i <- 0..(n_actions - 1), do: if(i == best_idx, do: 1.0, else: 0.0)

    {:ok,
     %{
       last_action: best_action,
       policy_posterior: pi_post,
       last_policy_best_idx: best_idx,
       # No F or G under greedy — these stay empty so downstream
       # telemetry can distinguish a Plan tick from a GreedyLoudest tick.
       last_f: [],
       last_g: [],
       marginal_state_belief: best_predicted_state,
       # Greedy doesn't compute a per-policy chain — leave empty.
       best_policy_chain: []
     }}
  end
end
