defmodule AgentPlane.Hierarchical do
  @moduledoc """
  Two-level hierarchical composition of `AgentPlane.ActiveInferenceAgent`.
  G5 (RUNTIME_GAPS.md).  Cookbook recipes that teach hierarchical active
  inference use this as their Jido entry point.

  Topology:

      meta_agent (upper)      <-- context, slower -->
         |
         | modulates -> c_preference_override on lower bundle
         v
      base_agent (lower)      <-- observations, faster -->

  The meta-agent selects a *context* (one of K contexts).  Each context
  maps to a C-preference vector for the base agent.  When the meta
  changes context, the base's C is swapped on the next step.  This is
  the minimal pattern that satisfies Ch 10's "context gates goals"
  interpretation without requiring a full Jido.Pod deployment.

  The module is pure -- callers own the actual `Jido.Agent` instances
  and step them via the standard actions; `Hierarchical.step/2` is a
  convenience that sequences one upper tick + one lower tick.
  """

  alias AgentPlane.BundleBuilder

  @enforce_keys [:meta_bundle, :base_bundle, :contexts, :current_context]
  defstruct [
    :meta_bundle,
    :base_bundle,
    :contexts,
    :current_context,
    steps_in_context: 0
  ]

  @type context_id :: atom()
  @type t :: %__MODULE__{
          meta_bundle: map(),
          base_bundle: map(),
          # Context -> per-observation C-preference logits (length n_obs).
          contexts: %{context_id() => [float()]},
          current_context: context_id(),
          steps_in_context: non_neg_integer()
        }

  @doc """
  Build a 2-level hierarchy.

  Options:
    * `:base_opts` (keyword) -- passed to `BundleBuilder.for_maze/1` for the lower level.
    * `:meta_opts` (keyword, optional) -- upper-level bundle options.  When
      omitted, the meta uses the same maze as the base at half the horizon.
    * `:contexts` (required) -- `%{atom() => [float()]}` mapping each
      context to a C-preference-override vector.
    * `:initial_context` (atom) -- key in `:contexts`.
  """
  @spec new(keyword()) :: t()
  def new(opts) do
    base_opts = Keyword.fetch!(opts, :base_opts)
    contexts = Keyword.fetch!(opts, :contexts)
    initial = Keyword.fetch!(opts, :initial_context)

    unless Map.has_key?(contexts, initial),
      do: raise(ArgumentError, "initial_context #{inspect(initial)} missing from contexts map")

    # Lower bundle starts under the initial context.
    lower_opts =
      Keyword.put(base_opts, :c_preference_override, Map.fetch!(contexts, initial))

    base_bundle = BundleBuilder.for_maze(lower_opts)

    meta_opts =
      opts
      |> Keyword.get(:meta_opts, base_opts)
      |> Keyword.update(:horizon, 3, fn h -> max(div(h, 2), 2) end)
      |> Keyword.update(:policy_depth, 2, fn d -> max(div(d, 2), 1) end)

    meta_bundle = BundleBuilder.for_maze(meta_opts)

    %__MODULE__{
      meta_bundle: meta_bundle,
      base_bundle: base_bundle,
      contexts: contexts,
      current_context: initial,
      steps_in_context: 0
    }
  end

  @doc """
  Switch context.  Returns a new hierarchy with the base bundle's C
  swapped to the target context's preference vector.  The meta-agent
  (caller) decides when to call this; the canonical trigger is a
  detected mismatch between meta-level prediction and base-level
  observation sequence.
  """
  @spec switch_context(t(), context_id()) :: t()
  def switch_context(%__MODULE__{contexts: ctxs} = h, target) do
    unless Map.has_key?(ctxs, target),
      do: raise(ArgumentError, "unknown context #{inspect(target)}")

    new_c = Map.fetch!(ctxs, target)
    updated_base = update_bundle_c(h.base_bundle, new_c)

    %__MODULE__{h | base_bundle: updated_base, current_context: target, steps_in_context: 0}
  end

  @doc "Increment the `steps_in_context` counter (called after each base step)."
  @spec tick(t()) :: t()
  def tick(%__MODULE__{steps_in_context: n} = h),
    do: %__MODULE__{h | steps_in_context: n + 1}

  # Replace the C vector on a bundle in place.  Mirrors BundleBuilder's
  # softmax+log normalization so the downstream actions see C in the same
  # space they expect.
  defp update_bundle_c(bundle, logits) do
    require ActiveInferenceCore.Math, as: M
    c_vec = M.softmax(logits)
    c_log = Enum.map(c_vec, &:math.log(max(&1, 1.0e-16)))
    %{bundle | c: c_log}
  end
end
