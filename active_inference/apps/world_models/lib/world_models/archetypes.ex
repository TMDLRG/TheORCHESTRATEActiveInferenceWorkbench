defmodule WorldModels.Archetypes do
  @moduledoc """
  Plan §5 — compositional Builder archetypes.

  An archetype is a *template* the user drops onto the canvas to seed a
  full topology. Each one names the model family it belongs to (an entry
  in `ActiveInferenceCore.Models`) and the primary equations that ground
  it (entries in `ActiveInferenceCore.Equations`).

  `disabled?` is `true` when the archetype is registry-only (the Elixir
  module implementing its math hasn't shipped yet). The Builder still
  lets the user drag such archetypes onto the canvas — but Instantiate
  refuses, and every node carries a `not yet runnable` badge.
  """

  defstruct [
    :id,
    :name,
    :description,
    :family_id,
    :primary_equation_ids,
    :mvp_suitability,
    :disabled?,
    :required_types,
    :default_params
  ]

  @type t :: %__MODULE__{
          id: String.t(),
          name: String.t(),
          description: String.t(),
          family_id: String.t(),
          primary_equation_ids: [String.t()],
          mvp_suitability: atom(),
          disabled?: boolean(),
          required_types: [String.t()],
          default_params: map()
        }

  @spec all() :: [t()]
  def all, do: records()

  @spec fetch(String.t()) :: t() | nil
  def fetch(id), do: Enum.find(all(), &(&1.id == id))

  @spec enabled() :: [t()]
  def enabled, do: Enum.reject(all(), & &1.disabled?)

  @doc """
  Expand an archetype into its default topology. The canvas drops this
  onto an empty graph when the user drags the archetype card.
  """
  @spec seed_topology(t()) :: WorldModels.Spec.Topology.t()
  def seed_topology(%__MODULE__{id: "pomdp_maze"} = a) do
    %{
      nodes: [
        %{id: "n_bundle", type: "bundle", params: a.default_params, position: %{x: 40, y: 80}},
        %{id: "n_perceive", type: "perceive", params: %{n_iters: 8}, position: %{x: 280, y: 40}},
        %{id: "n_plan", type: "plan", params: %{}, position: %{x: 520, y: 40}},
        %{id: "n_act", type: "act", params: %{}, position: %{x: 760, y: 40}}
      ],
      edges: [
        %{from_node: "n_bundle", from_port: "bundle", to_node: "n_perceive", to_port: "bundle"},
        %{from_node: "n_bundle", from_port: "bundle", to_node: "n_plan", to_port: "bundle"},
        %{from_node: "n_perceive", from_port: "beliefs", to_node: "n_plan", to_port: "beliefs"},
        %{from_node: "n_plan", from_port: "action", to_node: "n_act", to_port: "action"}
      ],
      required_types: a.required_types
    }
  end

  def seed_topology(%__MODULE__{} = a) do
    %{nodes: [], edges: [], required_types: a.required_types}
  end

  # -- Registry -------------------------------------------------------------

  defp records do
    [
      %__MODULE__{
        id: "pomdp_maze",
        name: "POMDP maze-solver",
        description:
          "Discrete-time Active Inference for a maze world. State-belief update (eq. 4.13 / B.5) + policy posterior (eq. 4.14 / B.9).",
        family_id: "Partially Observable Markov Decision Process (POMDP)",
        primary_equation_ids: [
          "eq_4_5_pomdp_likelihood",
          "eq_4_6_pomdp_prior_over_states",
          "eq_4_10_efe_linear_algebra",
          "eq_4_11_vfe_linear_algebra",
          "eq_4_13_state_belief_update",
          "eq_4_14_policy_posterior"
        ],
        mvp_suitability: :mvp_primary,
        disabled?: false,
        # A bundle source (either a monolithic `bundle` block or the
        # Phase C matrix-level `bundle_assembler`) plus the three
        # action-loop nodes. Validator treats `bundle` and
        # `bundle_assembler` as interchangeable bundle sources.
        required_types: ["perceive", "plan", "act"],
        default_params: %{
          horizon: 3,
          policy_depth: 3,
          preference_strength: 4.0
        }
      },
      %__MODULE__{
        id: "hmm",
        name: "Hidden Markov Model",
        description: "State-inference only (no action); useful as a baseline.",
        family_id: "Hidden Markov Model (HMM)",
        primary_equation_ids: ["eq_4_5_pomdp_likelihood", "eq_4_6_pomdp_prior_over_states"],
        mvp_suitability: :mvp_secondary,
        # Runnable as of Phase I — HMM reuses the POMDP action set minus
        # the planner, so L-series specs that want a perception-only agent
        # can wire `perceive` without `plan`/`act`.
        disabled?: false,
        required_types: ["perceive"],
        default_params: %{}
      },
      %__MODULE__{
        id: "dirichlet_pomdp",
        name: "Dirichlet-parameterised POMDP",
        description: "POMDP with online Dirichlet learning on A and B (eq. 7.10) — L4.",
        family_id: "Dirichlet-Parameterised POMDP (learning)",
        primary_equation_ids: [
          "eq_7_10_dirichlet_update",
          "eq_4_13_state_belief_update",
          "eq_4_14_policy_posterior"
        ],
        mvp_suitability: :mvp_secondary,
        # Runnable as of Phase H — Dirichlet learners ship.
        disabled?: false,
        required_types: ["perceive", "plan", "act"],
        default_params: %{horizon: 5, policy_depth: 5, preference_strength: 4.0}
      },
      %__MODULE__{
        id: "continuous_generalized_filter",
        name: "Continuous-time generalized filter",
        description:
          "Predictive-coding hierarchy with generalized coordinates. Registry-only; continuous math not yet implemented.",
        family_id: "Continuous-time Generative Model (generalized filtering)",
        primary_equation_ids: [
          "eq_8_1_continuous_generative_model",
          "eq_8_2_continuous_generative_process",
          "eq_B_42_laplace_free_energy_continuous",
          "eq_B_47_predictive_coding_hierarchy"
        ],
        mvp_suitability: :mvp_registry_only,
        disabled?: true,
        required_types: [],
        default_params: %{}
      }
    ]
  end
end
