defmodule AgentPlane.BundleBuilder.CueTask do
  @moduledoc """
  Week-12 capstone generative model — a cue-guided T-maze.

  Hidden state factors the location with the reward context:

      0:(C,l) 1:(C,r) 2:(K,l) 3:(K,r) 4:(L,l) 5:(L,r) 6:(R,l) 7:(R,r)

  where location ∈ {C center, K cue, L left arm, R right arm} and context ∈
  {l reward-left, r reward-right}. The context is fixed within an episode and
  unknown at the start (`D` is uniform over it). Visiting the **cue** K yields an
  observation that identifies the context; the **arms** pay `:reward` in the
  matching context and `:loss` otherwise. Crucially `C` prefers the **reward
  outcome, not the cue** — the only reason to visit the cue is informational.

  This satisfies the Week-12 setup conditions and is the substrate for the five
  ablations (see `AgentPlane.BundleBuilder.CueTask` options and the capstone
  tests). Outcomes: `0 :neutral, 1 :cue_l, 2 :cue_r, 3 :reward, 4 :loss`.

  ## Options

    * `:cue_informative` — `true` (default) makes the cue reveal the context;
      `false` (ablation 1) makes both cue states emit `:neutral`.
    * `:preference_strength` — reward logit magnitude for `C` (default 4.0);
      `0.0` flattens `C` (ablation 3).
    * `:loss_strength` — magnitude of the **loss** penalty in `C` (default
      `2 × preference_strength`). The default makes `C` loss-averse, which is
      what makes the safe, informative cue strictly preferable to gambling on an
      arm under unknown context — i.e. what produces robust explore-then-exploit
      (the spec's parameter regime). Tying the default to `preference_strength`
      means flattening `C` zeroes both reward and loss together.
    * `:policy_depth` / `:horizon` — default 2; `1` is too short to seek the cue
      and then use it (ablation 4).
    * `:habit_action` + `:habit_strength` — when set, `E` strongly favours
      policies starting with that action (ablation 5); default `E = nil`.
    * `:efe_ambiguity` — `false` drops the EFE information term (ablation 2).
    * `:noise` — likelihood smoothing ε (default 0.02) so ambiguity is non-zero.
  """

  alias ActiveInferenceCore.Math, as: M

  @actions [:go_center, :go_cue, :go_left, :go_right]
  @n_states 8
  @n_obs 5

  @doc "Build a cue-task bundle. See the module doc for options."
  @spec build(keyword()) :: map()
  def build(opts \\ []) do
    informative? = Keyword.get(opts, :cue_informative, true)
    pref = Keyword.get(opts, :preference_strength, 4.0)
    loss = Keyword.get(opts, :loss_strength, 2.0 * pref)
    depth = Keyword.get(opts, :policy_depth, 2)
    horizon = Keyword.get(opts, :horizon, depth)
    noise = Keyword.get(opts, :noise, 0.02)

    %{
      a: likelihood(informative?, noise),
      b: transitions(),
      c: M.log_eps(M.softmax([0.0, 0.0, 0.0, pref, -loss])),
      d: [0.5, 0.5, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0],
      e: habit(opts, depth),
      actions: @actions,
      policies: enumerate_policies(@actions, depth),
      horizon: horizon,
      dims: %{n_states: @n_states, n_obs: @n_obs},
      action_selection: Keyword.get(opts, :action_selection, :argmax),
      softmax_temperature: Keyword.get(opts, :softmax_temperature, 1.0),
      efe_ambiguity: Keyword.get(opts, :efe_ambiguity, true),
      family_id: "cue_task_t_maze"
    }
  end

  @doc "Outcome index for a named outcome atom."
  @spec obs_index(atom()) :: non_neg_integer()
  def obs_index(:neutral), do: 0
  def obs_index(:cue_l), do: 1
  def obs_index(:cue_r), do: 2
  def obs_index(:reward), do: 3
  def obs_index(:loss), do: 4

  @doc "Indices of states whose context is `:l` (even) — used to read P(ctx=l)."
  @spec left_context_states() :: [non_neg_integer()]
  def left_context_states, do: [0, 2, 4, 6]

  # — internals —

  # Base deterministic likelihood columns (per state, distribution over 5 outcomes).
  defp likelihood(informative?, noise) do
    cue_l = if informative?, do: [0, 1.0, 0, 0, 0], else: [1.0, 0, 0, 0, 0]
    cue_r = if informative?, do: [0, 0, 1.0, 0, 0], else: [1.0, 0, 0, 0, 0]

    [
      # C: neutral
      [1.0, 0, 0, 0, 0],
      [1.0, 0, 0, 0, 0],
      # K: cue (informative ⇒ reveals context)
      cue_l,
      cue_r,
      # L arm: reward in ctx l, loss in ctx r
      [0, 0, 0, 1.0, 0],
      [0, 0, 0, 0, 1.0],
      # R arm: loss in ctx l, reward in ctx r
      [0, 0, 0, 0, 1.0],
      [0, 0, 0, 1.0, 0]
    ]
    |> Enum.map(&smooth(&1, noise))
    |> M.transpose()
  end

  defp smooth(col, eps), do: Enum.map(col, fn x -> x * (1.0 - eps) + eps / @n_obs end)

  # Deterministic location change, context preserved.
  defp transitions do
    %{
      go_center: b_to_location(0),
      go_cue: b_to_location(1),
      go_left: b_to_location(2),
      go_right: b_to_location(3)
    }
  end

  defp b_to_location(dest_loc) do
    for s_dest <- 0..(@n_states - 1) do
      for s_src <- 0..(@n_states - 1) do
        if div(s_dest, 2) == dest_loc and rem(s_dest, 2) == rem(s_src, 2),
          do: 1.0,
          else: 0.0
      end
    end
  end

  defp habit(opts, depth) do
    case Keyword.get(opts, :habit_action) do
      nil ->
        nil

      action ->
        strength = Keyword.get(opts, :habit_strength, 6.0)
        policies = enumerate_policies(@actions, depth)

        policies
        |> Enum.map(fn policy -> if List.first(policy) == action, do: strength, else: 0.0 end)
        |> M.softmax()
    end
  end

  defp enumerate_policies(actions, depth) do
    Enum.reduce(1..depth, [[]], fn _, acc ->
      for prefix <- acc, a <- actions, do: prefix ++ [a]
    end)
  end
end
