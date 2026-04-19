defmodule ActiveInferenceCore.Models do
  @moduledoc """
  Taxonomy of Active Inference model families present in the registry.

  Each record points at equation IDs in `ActiveInferenceCore.Equations` that
  ground it. The UI uses this file to let the user filter by family / type.
  """

  alias ActiveInferenceCore.Model

  @doc "All model families."
  @spec all() :: [Model.t()]
  def all, do: records()

  @doc "Filter by type: :discrete | :continuous | :hybrid | :general"
  @spec by_type(Model.type()) :: [Model.t()]
  def by_type(type), do: Enum.filter(all(), &(&1.type == type))

  @doc "Lookup by model_name."
  @spec fetch(String.t()) :: Model.t() | nil
  def fetch(name), do: Enum.find(all(), &(&1.model_name == name))

  # ---------------------------------------------------------------------------
  # Registry
  # ---------------------------------------------------------------------------

  defp records do
    [
      %Model{
        model_name: "Foundational Bayesian Identity",
        source_basis: ["eq_2_1_bayes_rule", "eq_2_2_marginal_likelihood"],
        type: :general,
        variables: ["x (hidden state)", "y (observation)"],
        priors: ["P(x)"],
        likelihood_structure: "P(y|x) arbitrary",
        transition_structure: "not applicable",
        inference_update_rule: "exact Bayes: P(x|y) = P(x) P(y|x) / P(y)",
        planning_mechanism: "not applicable",
        required_runtime_objects: ["categorical distributions over x"],
        mvp_suitability: :mvp_secondary,
        future_extensibility:
          "Baseline against which approximate variational posteriors are compared."
      },
      %Model{
        model_name: "Variational Free Energy (general)",
        source_basis: [
          "eq_2_5_variational_free_energy",
          "eq_3_2_fe_surprise_evidence",
          "eq_B_2_free_energy_per_policy"
        ],
        type: :general,
        variables: ["x", "y", "Q(x) approximate posterior"],
        priors: ["P(x)"],
        likelihood_structure: "P(y|x) arbitrary",
        transition_structure: "not applicable",
        inference_update_rule: "Q* = argmin_Q F[Q, y]",
        planning_mechanism: "not applicable",
        required_runtime_objects: ["Q(x)", "evaluator of F"],
        mvp_suitability: :mvp_primary,
        future_extensibility:
          "Underlies every specific Active Inference algorithm, discrete or continuous."
      },
      %Model{
        model_name: "Expected Free Energy (general)",
        source_basis: [
          "eq_2_6_expected_free_energy",
          "eq_7_4_efe_epistemic_pragmatic",
          "eq_B_30_efe_per_time"
        ],
        type: :general,
        variables: ["π (policy)", "x̃, ỹ (trajectories)"],
        priors: ["C (preferences)"],
        likelihood_structure: "P(ỹ|x̃)",
        transition_structure: "Q(x̃|π) via generative model",
        inference_update_rule: "G(π) evaluated per policy; P(π) ∝ exp(-G)",
        planning_mechanism: "Policies scored by G; posterior over π via softmax.",
        required_runtime_objects: ["policy set", "C vector", "G evaluator"],
        mvp_suitability: :mvp_primary,
        future_extensibility:
          "Habit term E, precision γ, novelty term for learning all plug in via B.7 / B.14 / 7.11."
      },
      %Model{
        model_name: "Hidden Markov Model (HMM)",
        source_basis: ["eq_4_5_pomdp_likelihood", "eq_4_6_pomdp_prior_over_states"],
        type: :discrete,
        variables: ["s_τ (hidden state)", "o_τ (observation)"],
        priors: ["D — initial state prior"],
        likelihood_structure: "Categorical with matrix A",
        transition_structure: "Categorical with matrix B (un-conditioned on policy)",
        inference_update_rule: "Variational message passing on mean-field Q(s̃) (eq. 4.13)",
        planning_mechanism: "not applicable — HMM has no action",
        required_runtime_objects: ["A", "B", "D"],
        mvp_suitability: :mvp_secondary,
        future_extensibility: "Upgrade to POMDP by making B conditional on π and adding C, E."
      },
      %Model{
        model_name: "Partially Observable Markov Decision Process (POMDP)",
        source_basis: [
          "eq_4_5_pomdp_likelihood",
          "eq_4_6_pomdp_prior_over_states",
          "eq_4_7_policy_prior_and_efe",
          "eq_4_10_efe_linear_algebra",
          "eq_4_11_vfe_linear_algebra",
          "eq_4_13_state_belief_update",
          "eq_4_14_policy_posterior",
          "eq_B_5_gradient_descent_states",
          "eq_B_9_policy_posterior_update",
          "eq_B_30_efe_per_time"
        ],
        type: :discrete,
        variables: ["s_τ", "o_τ", "π"],
        priors: ["D (initial state)", "C (preferred outcomes)", "E (habit)"],
        likelihood_structure: "Cat(A), A_{ij}=P(o=i|s=j)",
        transition_structure: "Cat(B^π_τ) — policy-conditioned",
        inference_update_rule: "State beliefs via eq. 4.13 / B.5; policy via eq. 4.14 / B.9.",
        planning_mechanism: "EFE-based prior over policies with per-time-step G summed.",
        required_runtime_objects: [
          "A (likelihood)",
          "B_π (transitions per action)",
          "C (preferences)",
          "D (initial state)",
          "policy set (sequences of actions)"
        ],
        mvp_suitability: :mvp_primary,
        future_extensibility:
          "Factorise states / outcomes; add Dirichlet learning (eq. 7.10 / B.12); add precision (B.13–B.20)."
      },
      %Model{
        model_name: "Dirichlet-Parameterised POMDP (learning)",
        source_basis: ["eq_7_10_dirichlet_update"],
        type: :discrete,
        variables: ["s_τ", "o_τ", "π", "a (Dirichlet counts)"],
        priors: ["Dir(a) over A, Dir(b) over B, Dir(c) over C, Dir(d) over D, Dir(e) over E"],
        likelihood_structure: "Cat(A) with A drawn from Dir(a)",
        transition_structure: "Cat(B^π_τ) with B drawn from Dir(b)",
        inference_update_rule: "Eqs. 4.13 + 7.10 / B.10–B.12 for Dirichlet pseudo-count updates.",
        planning_mechanism: "Same as POMDP, plus novelty term (eq. 7.11).",
        required_runtime_objects: ["Dirichlet count tensors", "digamma implementation"],
        mvp_suitability: :mvp_registry_only,
        future_extensibility:
          "Scaffolded via a `:learning` flag on the agent; not enabled in the maze MVP."
      },
      %Model{
        model_name: "Continuous-time Generative Model (generalized filtering)",
        source_basis: [
          "eq_8_1_continuous_generative_model",
          "eq_8_2_continuous_generative_process",
          "eq_8_5_newtonian_attractor",
          "eq_8_6_lotka_volterra",
          "eq_B_42_laplace_free_energy_continuous",
          "eq_B_47_predictive_coding_hierarchy",
          "eq_B_48_continuous_action"
        ],
        type: :continuous,
        variables: ["x (continuous state)", "v (causes)", "y"],
        priors: ["p(v) = N(η̃, Π̃_v^{-1})"],
        likelihood_structure: "y = g(x) + ω_y",
        transition_structure: "ẋ = f(x, v) + ω_x",
        inference_update_rule:
          "Generalised gradient descent on Laplace-approximated F (eq. B.47).",
        planning_mechanism:
          "Action fulfils proprioceptive predictions: u̇ = −∇_u ỹ · Π̃_y ε̃_y (eq. B.48).",
        required_runtime_objects: [
          "generalised-coordinates solver",
          "Laplace precision tensors",
          "hierarchical graph"
        ],
        mvp_suitability: :mvp_registry_only,
        future_extensibility:
          "Agent-plane adapter hook exists (continuous-time behaviour module) but maze MVP uses discrete-time POMDP."
      },
      %Model{
        model_name: "Hybrid (mixed discrete/continuous)",
        source_basis: ["eq_B_42_laplace_free_energy_continuous"],
        type: :hybrid,
        variables: ["categorical + continuous parameters"],
        priors: ["Normal for continuous component, Categorical for discrete"],
        likelihood_structure: "Mixed; evaluated via Bayesian Model Reduction.",
        transition_structure: "As POMDP for discrete, as continuous-time SDE for continuous.",
        inference_update_rule:
          "Bayesian Model Reduction (B.40 / B.41) links the two representations.",
        planning_mechanism: "Categorical component selects among continuous sub-models.",
        required_runtime_objects: ["both runtimes"],
        mvp_suitability: :future_work,
        future_extensibility:
          "A future plugin can register a hybrid behaviour — the registry is already taxonomically aware."
      }
    ]
  end
end
