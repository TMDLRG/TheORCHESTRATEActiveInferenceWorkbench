defmodule ActiveInferenceCore.Model do
  @moduledoc """
  A model-family record following the taxonomy schema in the build brief.
  """

  @enforce_keys [
    :model_name,
    :source_basis,
    :type,
    :variables,
    :priors,
    :likelihood_structure,
    :transition_structure,
    :inference_update_rule,
    :planning_mechanism,
    :required_runtime_objects,
    :mvp_suitability,
    :future_extensibility
  ]

  defstruct @enforce_keys

  @type type :: :discrete | :continuous | :hybrid | :general

  @type mvp_suitability ::
          :mvp_primary
          | :mvp_secondary
          | :mvp_registry_only
          | :future_work

  @type t :: %__MODULE__{
          model_name: String.t(),
          source_basis: [String.t()],
          type: type,
          variables: [String.t()],
          priors: [String.t()],
          likelihood_structure: String.t(),
          transition_structure: String.t(),
          inference_update_rule: String.t(),
          planning_mechanism: String.t(),
          required_runtime_objects: [String.t()],
          mvp_suitability: mvp_suitability,
          future_extensibility: String.t()
        }
end
