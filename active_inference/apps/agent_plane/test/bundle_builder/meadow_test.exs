defmodule AgentPlane.BundleBuilder.MeadowTest do
  use ExUnit.Case, async: true

  alias AgentPlane.{ActiveInferenceAgent, MeadowObsAdapter}
  alias AgentPlane.Actions.{Act, Perceive, Plan}
  alias AgentPlane.BundleBuilder.Meadow
  alias SharedContracts.{Blanket, ObservationPacket}

  describe "Meadow.simple/1 bundle shape" do
    test "produces a bundle compatible with ActiveInferenceCore.DiscreteTime" do
      bundle = Meadow.simple(width: 4, height: 4, preferred_token: :t1)

      assert bundle.dims.n_obs == MeadowObsAdapter.n_obs()
      assert bundle.dims.n_states == 16
      assert bundle.dims.tier == :simple

      # Action vocabulary is the canonical 9.
      assert bundle.actions == Meadow.meadow_actions()
      assert length(bundle.actions) == 9

      # Policies are depth-1 sequences of single actions by default.
      assert length(bundle.policies) == 9
      assert Enum.all?(bundle.policies, &(length(&1) == 1))

      # A is n_obs × n_states, columns sum to 1.
      assert length(bundle.a) == bundle.dims.n_obs

      Enum.each(bundle.a, fn row -> assert length(row) == bundle.dims.n_states end)

      assert columns_sum_to_one?(bundle.a)

      # B has one entry per action; each is square n_states × n_states with cols summing to 1.
      assert Map.keys(bundle.b) |> Enum.sort() == Enum.sort(bundle.actions)

      Enum.each(bundle.b, fn {_a, mat} ->
        assert length(mat) == bundle.dims.n_states
        Enum.each(mat, fn row -> assert length(row) == bundle.dims.n_states end)
        assert columns_sum_to_one?(mat)
      end)

      # C is a normalised log distribution over n_obs.
      assert length(bundle.c) == bundle.dims.n_obs
      c_vec = Enum.map(bundle.c, &:math.exp/1)
      assert_in_delta Enum.sum(c_vec), 1.0, 1.0e-6

      # D is a normalised distribution over n_states.
      assert length(bundle.d) == bundle.dims.n_states
      assert_in_delta Enum.sum(bundle.d), 1.0, 1.0e-6

      # Provenance + adapter wiring
      assert bundle.obs_adapter == MeadowObsAdapter
      assert bundle.family_id =~ "POMDP"
      assert bundle.verification_status == :verified_against_source
    end

    test "C peaks on the preferred token across all amp/bearing/self combinations" do
      bundle = Meadow.simple(width: 4, height: 4, preferred_token: :t2)
      c_vec = Enum.map(bundle.c, &:math.exp/1)

      # Sum over every observation index where token == :t2 vs token == :t3.
      sum_for_token = fn target ->
        c_vec
        |> Enum.with_index()
        |> Enum.reduce(0.0, fn {p, idx}, acc ->
          {_ws, _amp, tok, _br, _self} = MeadowObsAdapter.decode_index(idx)
          if tok == target, do: acc + p, else: acc
        end)
      end

      assert sum_for_token.(:t2) > sum_for_token.(:t3)
      assert sum_for_token.(:t2) > sum_for_token.(:t1)
    end

    test "rejects bad preferred_token" do
      assert_raise ArgumentError, fn ->
        Meadow.simple(width: 4, height: 4, preferred_token: :not_a_token)
      end
    end
  end

  describe "Meadow.complex/1 bundle shape" do
    test "factor cardinalities and normalisation" do
      bundle = Meadow.complex(width: 4, height: 4, preferred_token: :t1)

      assert bundle.dims.tier == :complex
      assert bundle.dims.n_pos == 16
      assert bundle.dims.n_token == 5
      assert bundle.dims.n_pres == 2
      assert bundle.dims.n_states == 16 * 5 * 2

      # A and B columns normalised.
      assert columns_sum_to_one?(bundle.a)

      Enum.each(bundle.b, fn {_a, mat} ->
        assert columns_sum_to_one?(mat)
      end)

      assert_in_delta Enum.sum(bundle.d), 1.0, 1.0e-6

      # Default policy_depth == 2 for Complex.
      assert length(bundle.policies) == 9 * 9
    end

    test "D weakly biases partner_token toward the bird's preferred token" do
      bundle = Meadow.complex(width: 4, height: 4, preferred_token: :t1)
      d = bundle.d
      tokens = MeadowObsAdapter.token_values()
      n_token = length(tokens)
      n_pres = bundle.dims.n_pres

      # Marginalise D over (position, partner_present), keeping partner_token.
      pt_marg =
        Enum.reduce(0..(length(d) - 1), List.duplicate(0.0, n_token), fn s, acc ->
          {_pos, pt_idx, _pp_idx} = Meadow.decode_state(s, n_token, n_pres)
          List.update_at(acc, pt_idx, &(&1 + Enum.at(d, s)))
        end)

      pref_idx = Enum.find_index(tokens, &(&1 == :t1))
      none_idx = Enum.find_index(tokens, &(&1 == :none))

      pref_mass = Enum.at(pt_marg, pref_idx)
      none_mass = Enum.at(pt_marg, none_idx)
      other_mass = Enum.at(pt_marg, Enum.find_index(tokens, &(&1 == :t2)))

      assert pref_mass > none_mass
      assert pref_mass > other_mass
    end
  end

  describe "Meadow.resonant/1 bundle" do
    test "extends Complex with resonant_meta context map" do
      bundle = Meadow.resonant(width: 4, height: 4, preferred_token: :t1)

      assert bundle.dims.tier == :resonant
      assert is_map(bundle.resonant_meta)
      assert Map.has_key?(bundle.resonant_meta.contexts, :explore)
      assert Map.has_key?(bundle.resonant_meta.contexts, :duet)
      assert bundle.resonant_meta.initial_context == :explore

      # Each context is a length-n_obs log distribution.
      Enum.each(bundle.resonant_meta.contexts, fn {_ctx, c} ->
        assert length(c) == bundle.dims.n_obs
        c_vec = Enum.map(c, &:math.exp/1)
        assert_in_delta Enum.sum(c_vec), 1.0, 1.0e-6
      end)
    end
  end

  describe "Meadow.convergent/1 bundle shape" do
    test "5-state partner_bearing factor, normalised A/B/D/C" do
      bundle = Meadow.convergent(width: 4, height: 4, preferred_token: :t1)

      assert bundle.dims.tier == :convergent
      assert bundle.dims.n_states == 5
      assert bundle.dims.bearings == [:none, :north, :east, :south, :west]

      assert columns_sum_to_one?(bundle.a)

      Enum.each(bundle.b, fn {_a, mat} ->
        assert columns_sum_to_one?(mat)
      end)

      assert_in_delta Enum.sum(bundle.d), 1.0, 1.0e-6

      c_vec = Enum.map(bundle.c, &:math.exp/1)
      assert_in_delta Enum.sum(c_vec), 1.0, 1.0e-6
    end

    test "B encodes the EFE-relevant gradient: aligned movement preserves bearing more than anti-aligned" do
      # Core scientific test: P(stay aligned) > P(stay anti-aligned).
      # If this fails, EFE will not produce convergent behaviour.
      assert Meadow.bearing_transition_prob(:move_north, :north, :north) >
               Meadow.bearing_transition_prob(:move_south, :north, :north)

      assert Meadow.bearing_transition_prob(:move_east, :east, :east) >
               Meadow.bearing_transition_prob(:move_west, :east, :east)

      # And the dual: anti-aligned movement loses the source more often.
      assert Meadow.bearing_transition_prob(:move_south, :north, :none) >
               Meadow.bearing_transition_prob(:move_north, :north, :none)
    end

    test ":stay and :sing_* are near-identity (bearing should not silently drift)" do
      assert Meadow.bearing_transition_prob(:stay, :east, :east) >= 0.9
      assert Meadow.bearing_transition_prob(:sing_t1, :east, :east) >= 0.9
    end
  end

  describe "end-to-end Perceive → Plan → Act on each tier (smoke test)" do
    test "SimpleBird tick" do
      assert_one_tick(Meadow.simple(width: 4, height: 4, preferred_token: :t1))
    end

    test "ComplexBird tick" do
      assert_one_tick(Meadow.complex(width: 4, height: 4, preferred_token: :t1))
    end

    test "ResonantBird tick" do
      assert_one_tick(Meadow.resonant(width: 4, height: 4, preferred_token: :t1))
    end

    test "ConvergentBird tick" do
      assert_one_tick(Meadow.convergent(width: 4, height: 4, preferred_token: :t1))
    end
  end

  defp assert_one_tick(bundle) do
    blanket = Blanket.meadow_default()
    agent = ActiveInferenceAgent.fresh("smoke", bundle, blanket)

    obs =
      ObservationPacket.new(%{
        t: 0,
        channels: %{
          wall_sig: :open,
          hearing_amp: :loud,
          hearing_token: :t1,
          hearing_bearing: :east,
          self_sang_token: :none
        },
        world_run_id: "smoke",
        terminal?: false,
        blanket: blanket
      })

    {agent1, _} = ActiveInferenceAgent.cmd(agent, {Perceive, %{observation: obs}})
    {agent2, _} = ActiveInferenceAgent.cmd(agent1, Plan)
    {agent3, dirs} = ActiveInferenceAgent.cmd(agent2, Act)

    assert agent3.state.last_action in bundle.actions
    assert is_list(agent3.state.policy_posterior)
    assert_in_delta Enum.sum(agent3.state.policy_posterior), 1.0, 1.0e-6
    assert Enum.any?(dirs, &match?(%Jido.Agent.Directive.Emit{}, &1))
  end

  defp columns_sum_to_one?(matrix) do
    cols = transpose(matrix)

    Enum.all?(cols, fn col ->
      s = Enum.sum(col)
      abs(s - 1.0) < 1.0e-6
    end)
  end

  defp transpose([]), do: []
  defp transpose([[] | _]), do: []

  defp transpose(m) do
    m
    |> Enum.zip()
    |> Enum.map(&Tuple.to_list/1)
  end
end
