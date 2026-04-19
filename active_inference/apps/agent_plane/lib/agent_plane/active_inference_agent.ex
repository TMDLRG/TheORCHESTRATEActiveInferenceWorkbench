defmodule AgentPlane.ActiveInferenceAgent do
  @moduledoc """
  Native JIDO agent implementing discrete-time Active Inference (POMDP).

  This module uses the actual `Jido.Agent` behaviour from the JIDO library
  checked out in the umbrella's parent worktree. It is *not* a custom
  GenServer wearing a JIDO label.

  ## State schema

  The agent state carries every quantity the inference loop needs:

    * `:agent_id` — string, stable identifier.
    * `:bundle` — map, generative-model bundle (see `AgentPlane.BundleBuilder`).
    * `:blanket` — `SharedContracts.Blanket.t()` — the configured blanket.
    * `:beliefs` — `%{policy_index => belief()}` — state beliefs under each
       policy, belief being a list of categorical vectors, one per τ.
    * `:obs_history` — list of categorical observation vectors observed so far.
    * `:t` — integer time-step of the next observation to be processed.
    * `:policy_posterior` — current π (vector), recomputed every step.
    * `:last_action` — last atom emitted, or `nil`.
    * `:telemetry` — list of per-step telemetry maps (most recent first).
    * `:goal_idx` — 0-based index the agent considers the goal (for UI).

  ## Actions

  Three JIDO actions drive the loop:

    * `AgentPlane.Actions.Perceive` — sweeps state beliefs (eq. 4.13 / B.5).
    * `AgentPlane.Actions.Plan` — computes F, G, π (eq. 4.14 / B.9).
    * `AgentPlane.Actions.Act` — selects action, returns `Directive.Emit`
      for the `SharedContracts.ActionPacket` signal.

  Under JIDO's `cmd/2` contract, a user who just wants to advance one full
  tick can pass `[Perceive, Plan, Act]` or the convenience `Step` action which
  invokes the same sequence internally.
  """

  use Jido.Agent,
    name: "active_inference_agent",
    description: "Discrete-time Active Inference POMDP agent (Parr, Pezzulo, Friston 2022)",
    category: "inference",
    tags: ["active-inference", "pomdp", "maze"],
    schema: [
      agent_id: [type: :string, default: "active-inference-agent"],
      bundle: [type: :map, default: %{}],
      blanket: [type: :any, default: nil],
      beliefs: [type: :map, default: %{}],
      obs_history: [type: {:list, :any}, default: []],
      t: [type: :integer, default: -1],
      policy_posterior: [type: {:list, :float}, default: []],
      last_action: [type: :atom, default: nil],
      last_policy_best_idx: [type: :integer, default: 0],
      last_f: [type: {:list, :float}, default: []],
      last_g: [type: {:list, :float}, default: []],
      marginal_state_belief: [type: {:list, :float}, default: []],
      # Phase L — belief chain of the winning policy, for the trajectory overlay.
      best_policy_chain: [type: {:list, :any}, default: []],
      goal_idx: [type: :integer, default: 0],
      telemetry: [type: {:list, :any}, default: []],

      # Plan §7.1 / §10.3 — provenance fields copied from the bundle at fresh/4.
      # Glass Engine resolves these to equation + family records at render time.
      spec_id: [type: {:or, [:string, nil]}, default: nil],
      bundle_id: [type: {:or, [:string, nil]}, default: nil],
      family_id: [type: {:or, [:string, nil]}, default: nil],
      primary_equation_ids: [type: {:list, :string}, default: []],
      verification_status: [type: :atom, default: :unverified]
    ]

  @doc """
  Create a fresh agent initialised for a given bundle and blanket.

  This helper sits atop the JIDO-provided `new/1` and pre-populates the
  belief tensor via `ActiveInferenceCore.DiscreteTime.fresh_beliefs/1` so
  the very first `Perceive` call has something to update.
  """
  @spec fresh(String.t(), map(), SharedContracts.Blanket.t(), keyword()) :: struct()
  def fresh(agent_id, bundle, blanket, opts \\ []) do
    goal_idx = Keyword.get(opts, :goal_idx, 0)

    # Plan §8.4 — fresh_beliefs drives `rollout_forward` for every policy,
    # so the spans deserve provenance. The agent doesn't exist yet in the
    # Jido sense, but all provenance keys are already on the bundle.
    beliefs =
      AgentPlane.Telemetry.Context.with_agent_context(
        %{
          agent_id: agent_id,
          spec_id: Map.get(bundle, :spec_id),
          bundle_id: Map.get(bundle, :bundle_id),
          family_id: Map.get(bundle, :family_id),
          verification_status: Map.get(bundle, :verification_status)
        },
        fn -> ActiveInferenceCore.DiscreteTime.fresh_beliefs(bundle) end
      )

    new(
      id: agent_id,
      state: %{
        agent_id: agent_id,
        bundle: bundle,
        blanket: blanket,
        beliefs: beliefs,
        obs_history: [],
        t: -1,
        policy_posterior: [],
        last_action: nil,
        last_policy_best_idx: 0,
        last_f: [],
        last_g: [],
        marginal_state_belief: bundle.d,
        best_policy_chain: [],
        goal_idx: goal_idx,
        telemetry: [],

        # Plan §7.1 provenance — copy foreign keys from bundle so Glass
        # Engine can follow signal → agent_id → bundle_id → family_id → equation_ids.
        spec_id: Map.get(bundle, :spec_id),
        bundle_id: Map.get(bundle, :bundle_id),
        family_id: Map.get(bundle, :family_id),
        primary_equation_ids: Map.get(bundle, :primary_equation_ids, []),
        verification_status: Map.get(bundle, :verification_status, :unverified)
      }
    )
  end

  # Plan §12 Phase 3 — route signals driven by `AgentPlane.Runtime` onto
  # the three Active Inference actions. Unmatched signals fall through to
  # Jido's default `{signal.type, signal.data}` behavior.
  @doc false
  def signal_routes(_ctx) do
    [
      {"active_inference.perceive", AgentPlane.Actions.Perceive},
      {"active_inference.plan", AgentPlane.Actions.Plan},
      {"active_inference.act", AgentPlane.Actions.Act},
      {"active_inference.step", AgentPlane.Actions.Step}
    ]
  end
end
