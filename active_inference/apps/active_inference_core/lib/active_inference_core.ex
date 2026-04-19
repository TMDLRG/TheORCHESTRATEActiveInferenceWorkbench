defmodule ActiveInferenceCore do
  @moduledoc """
  Pure mathematical core for the Active Inference Workbench.

  This app contains:

    * `ActiveInferenceCore.Equation`    — source-traced equation records.
    * `ActiveInferenceCore.Equations`   — the full extracted equation registry.
    * `ActiveInferenceCore.Model`       — model-family records (taxonomy).
    * `ActiveInferenceCore.Models`      — prebuilt model definitions.
    * `ActiveInferenceCore.Math`        — low-level tensor / vector ops.
    * `ActiveInferenceCore.DiscreteTime`— POMDP Active Inference primitives.

  This app deliberately has zero dependence on `WorldPlane` or `AgentPlane`.
  It is a pure library that both planes may read. It never touches processes.
  """

  alias ActiveInferenceCore.{Equations, Models}

  @doc "Return all extracted equations."
  defdelegate all_equations, to: Equations, as: :all

  @doc "Return all registered model families."
  defdelegate all_models, to: Models, as: :all
end
