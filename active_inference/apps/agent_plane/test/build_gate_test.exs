defmodule AgentPlane.BuildGateTest do
  @moduledoc """
  The Weeks 8–12 **9-point build gate**, executable.

  Mirrors `curriculum_app/content/lessons/weeks-08-12-build-gate.md` — UNI's
  governing correction layer. Each `describe` block is one gate; the suite is
  the machine-checkable form of "no Week 8–12 lesson OR lab ships until the gate
  holds." Where a gate depends on a still-open workstream (the (lnB)s/ln(Bs)
  ruling routed to UNI via W-1; the full 5-ablation capstone in W-6) the
  dependent assertion is a tagged, deliberately-skipped test so the suite never
  falsely greens it.
  """
  use ExUnit.Case, async: true

  alias ActiveInferenceCore.{DiscreteTime, Math}
  alias AgentPlane.BundleBuilder
  alias AgentPlane.BundleBuilder.CueTask
  alias SharedContracts.{ActionPacket, Blanket, ObservationPacket}

  defp maze_bundle(extra \\ []) do
    blanket = Blanket.maze_default()

    base = [
      width: 3,
      height: 1,
      start_idx: 0,
      goal_idx: 2,
      walls: [],
      blanket: blanket,
      horizon: 2,
      policy_depth: 2
    ]

    BundleBuilder.for_maze(extra ++ base)
  end

  # ── Gate 1 — notation: natural logs (nats); q ≠ p(η|y,m); model ≠ process ──
  describe "Gate 1 — notation (nats)" do
    test "logs and entropy are in nats, not bits" do
      assert_in_delta hd(Math.log_eps([:math.exp(1.0)])), 1.0, 1.0e-12
      # A fair coin carries ln 2 nats (≈0.693), not 1 bit.
      assert_in_delta Math.entropy([0.5, 0.5]), :math.log(2.0), 1.0e-12
    end
  end

  # ── Gate 2 — bound: F[q] ≥ −ln p(o|m), never the reverse ──
  describe "Gate 2 — variational free energy upper-bounds surprise" do
    test "F[q] ≥ −ln p(o|m) for any q, with equality at the exact posterior" do
      a = [[0.9, 0.2], [0.1, 0.8]]
      d = [0.5, 0.5]
      b = %{stay: [[1.0, 0.0], [0.0, 1.0]]}
      o = [1.0, 0.0]

      # Model evidence p(o) = Σ_s P(o|s) D_s = (A·D)[0]; surprise = −ln p(o).
      p_o = DiscreteTime.predict_obs(a, d) |> Math.dot(o)
      surprise = -:math.log(p_o)

      f = fn q -> DiscreteTime.variational_free_energy([q], [:stay], b, a, [o], d) end

      # Exact posterior q*_s ∝ P(o|s) D_s.
      joint = Enum.zip(hd(a), d) |> Enum.map(fn {ai, di} -> ai * di end)
      q_star = Math.normalise(joint)

      for q <- [[0.5, 0.5], [0.9, 0.1], [0.2, 0.8], q_star] do
        assert f.(q) >= surprise - 1.0e-9
      end

      assert_in_delta f.(q_star), surprise, 1.0e-9
    end
  end

  # ── Gate 3 — POMDP: A,B column-stochastic; C outcome prior; D,E normalize ──
  describe "Gate 3 — POMDP structural constraints" do
    test "a built bundle's A,B are column-stochastic; C is an outcome prior; D,E normalize" do
      bundle = maze_bundle()

      assert column_stochastic?(bundle.a)
      assert Enum.all?(bundle.b, fn {_u, m} -> column_stochastic?(m) end)
      # C is stored as ln C (the value scale); exp(C) is the outcome prior.
      assert_in_delta Enum.sum(Enum.map(bundle.c, &:math.exp/1)), 1.0, 1.0e-6
      assert length(bundle.c) == length(bundle.a)
      assert simplex?(bundle.d)
      assert is_nil(bundle.e) or simplex?(bundle.e)
    end
  end

  # ── Gate 4 — inference path declared; (lnB)s not blended with ln(Bs) ──
  describe "Gate 4 — declared inference path" do
    test "the core declares one of the three recognised inference paths" do
      assert DiscreteTime.inference_path() in [
               :one_step_exact,
               :mean_field_vmp,
               :marginal_message_passing
             ]

      assert DiscreteTime.inference_path() == :mean_field_vmp
    end

    @tag skip: "pending UNI ruling (W-1): (lnB)s [update] vs ln(Bs) [VFE] transition-term form"
    test "update vs VFE transition-term share one form" do
      flunk("awaiting UNI ruling routed via W-1")
    end
  end

  # ── Gate 5 — EFE: risk + ambiguity in nats, distinct from VFE ──
  describe "Gate 5 — expected free energy = ambiguity + risk" do
    test "EFE total decomposes into per-τ ambiguity (≥0) + risk, in nats" do
      a = [[0.9, 0.1], [0.1, 0.9]]
      c_log = Math.log_eps([0.1, 0.9])
      s = [0.3, 0.7]

      efe = DiscreteTime.expected_free_energy([s], a, c_log, -1)

      assert_in_delta efe.total,
                      Enum.sum(efe.ambiguity_per_tau) + Enum.sum(efe.risk_per_tau),
                      1.0e-9

      assert Enum.all?(efe.ambiguity_per_tau, &(&1 >= 0.0))
    end
  end

  # ── Gate 6 — action from marginal Q(uₜ)=Σ_{π:πₜ=u} Q(π), not raw G ──
  describe "Gate 6 — action from the marginalized policy posterior" do
    test "the chosen argmax action equals argmax_u of the action marginal" do
      bundle =
        maze_bundle()
        |> Map.put(:action_selection, :argmax)
        |> Map.put(:softmax_temperature, 1.0)

      result = DiscreteTime.choose_action(bundle, %{}, [], -1)

      # Recompute Q(uₜ) independently from Q(π) and the policies.
      marginal =
        bundle.policies
        |> Enum.zip(result.policy_posterior)
        |> Enum.reduce(%{}, fn {policy, p}, acc ->
          Map.update(acc, List.first(policy), p, &(&1 + p))
        end)

      {best_u, _} = Enum.max_by(marginal, fn {_u, p} -> p end)

      assert result.action == best_u
      assert_in_delta Enum.sum(Map.values(result.action_marginal)), 1.0, 1.0e-9
    end
  end

  # ── Gate 7 — learned A uses E[ln A] (digamma), not ln E[A] ──
  describe "Gate 7 — learned-likelihood uses E[ln A]" do
    test "inference_log_a returns ψ(α)−ψ(Σα), strictly below ln(mean A)" do
      counts = [[8.0, 1.0], [2.0, 9.0]]

      e_log_a =
        DiscreteTime.inference_log_a(%{learning_enabled: true, dirichlet_a_counts: counts})

      assert e_log_a == Math.dirichlet_expected_log(counts)

      # ln of the Dirichlet mean — the WRONG quantity the gate guards against.
      log_mean =
        counts
        |> Math.transpose()
        |> Enum.map(&Math.normalise/1)
        |> Enum.map(&Math.log_eps/1)
        |> Math.transpose()

      # Jensen: E[ln A] ≤ ln E[A] everywhere, and strictly below on a column
      # carrying finite evidence (so the two are genuinely different).
      pairs = Enum.zip(List.flatten(e_log_a), List.flatten(log_mean))
      assert Enum.all?(pairs, fn {e, lm} -> e <= lm + 1.0e-12 end)
      assert Enum.any?(pairs, fn {e, lm} -> e < lm - 1.0e-6 end)
    end
  end

  # ── Gate 8 — blanket: no reach-through into another agent's internals ──
  describe "Gate 8 — Markov-blanket boundary is enforced" do
    test "an observation packet exposes only blanket-interface fields" do
      blanket = Blanket.maze_default()

      packet =
        ObservationPacket.new(%{
          t: 0,
          channels: %{tile: :start, goal_cue: :unknown, wall_hit: :clear},
          world_run_id: "gate8",
          terminal?: false,
          blanket: blanket
        })

      # The struct carries nothing beyond the senses-in interface — no beliefs,
      # bundle, policy posterior, or raw world state can ride across.
      assert Map.keys(packet) |> Enum.sort() ==
               [:__struct__, :channels, :t, :terminal?, :world_run_id]
    end

    test "pushing a channel the blanket does not expose is rejected at the boundary" do
      blanket = Blanket.maze_default()

      assert_raise ArgumentError, ~r/blanket violation/, fn ->
        ObservationPacket.new(%{
          t: 0,
          channels: %{hidden_world_state: :leaked},
          world_run_id: "gate8",
          terminal?: false,
          blanket: blanket
        })
      end
    end

    test "an action packet carries only actions-out — no belief/policy/FE leaks" do
      blanket = Blanket.maze_default()

      packet =
        ActionPacket.new(%{t: 0, action: :move_east, agent_id: "gate8", blanket: blanket})

      assert Map.keys(packet) |> Enum.sort() == [:__struct__, :action, :agent_id, :t]
    end

    test "emitting an action outside the blanket's vocabulary is rejected" do
      blanket = Blanket.maze_default()

      assert_raise ArgumentError, ~r/blanket violation/, fn ->
        ActionPacket.new(%{t: 0, action: :teleport, agent_id: "gate8", blanket: blanket})
      end
    end
  end

  # ── Gate 9 — ablation: capstone behaviour fails in the predicted ways ──
  # The full five-ablation capstone lives in `AgentPlane.BundleBuilder.CueTaskTest`
  # (W-6). These are the gate-level smoke checks that it is wired and breaks.
  describe "Gate 9 — capstone ablations break in the predicted ways" do
    test "the cue's information is real: informative cue sharpens context, uninformative does not" do
      prior = [0.0, 0.0, 0.5, 0.5, 0.0, 0.0, 0.0, 0.0]
      obs = Math.one_hot(5, CueTask.obs_index(:cue_l))
      pl = fn b -> CueTask.left_context_states() |> Enum.map(&Enum.at(b, &1)) |> Enum.sum() end

      inf =
        DiscreteTime.update_state_beliefs(nil, prior, nil, obs, CueTask.build().a, nil, nil, 1.0)

      unf =
        DiscreteTime.update_state_beliefs(
          nil,
          prior,
          nil,
          obs,
          CueTask.build(cue_informative: false).a,
          nil,
          nil,
          1.0
        )

      assert pl.(inf) > 0.9
      assert_in_delta pl.(unf), 0.5, 0.05
    end

    test "context-resolved agent exploits; flattening C weakens that pursuit" do
      ctx_l = [1.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0]
      sharp = %{CueTask.build(preference_strength: 4.0) | d: ctx_l}
      flat = %{CueTask.build(preference_strength: 0.0) | d: ctx_l}

      assert DiscreteTime.choose_action(sharp, %{}, [], -1).action == :go_left

      assert Map.get(DiscreteTime.choose_action(sharp, %{}, [], -1).action_marginal, :go_left) >
               Map.get(DiscreteTime.choose_action(flat, %{}, [], -1).action_marginal, :go_left)
    end
  end

  # ── helpers ──
  defp column_stochastic?(matrix) do
    matrix
    |> Math.transpose()
    |> Enum.all?(&simplex?/1)
  end

  defp simplex?(vector) do
    Enum.all?(vector, &(&1 >= 0.0 and is_number(&1))) and abs(Enum.sum(vector) - 1.0) < 1.0e-6
  end
end
