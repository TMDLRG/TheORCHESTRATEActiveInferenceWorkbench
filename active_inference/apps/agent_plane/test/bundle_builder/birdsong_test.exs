defmodule AgentPlane.BundleBuilder.BirdsongTest do
  use ExUnit.Case, async: true

  alias AgentPlane.{ActiveInferenceAgent, BirdsongObsAdapter, BirdsongSongbook}
  alias AgentPlane.Actions.{Act, Perceive, Plan}
  alias AgentPlane.BundleBuilder.Birdsong
  alias SharedContracts.{Blanket, ObservationPacket}

  @tag timeout: 120_000
  test "builds a normalized POMDP bundle for the birdsong lab" do
    bundle = Birdsong.build(action_selection: :argmax)

    assert bundle.dims.n_obs == BirdsongObsAdapter.n_obs()
    assert bundle.dims.n_states == 360
    assert bundle.actions == [:listen, :sing_a, :sing_b, :sing_c, :sing_d]
    assert length(bundle.policies) == 25
    assert bundle.obs_adapter == BirdsongObsAdapter
    assert bundle.family_id =~ "POMDP"
    assert bundle.birdsong_meta.representation == :symbolic_motif_sequence

    assert length(bundle.a) == 360
    assert Enum.all?(bundle.a, &(length(&1) == 360))
    assert columns_sum_to_one?(bundle.a)

    Enum.each(bundle.b, fn {_action, mat} ->
      assert length(mat) == 360
      assert Enum.all?(mat, &(length(&1) == 360))
      assert columns_sum_to_one?(mat)
    end)

    assert_in_delta Enum.sum(bundle.d), 1.0, 1.0e-6
    assert_in_delta bundle.c |> Enum.map(&:math.exp/1) |> Enum.sum(), 1.0, 1.0e-6
  end

  @tag timeout: 120_000
  test "Jido Perceive Plan Act emits a blanket-valid response action" do
    bundle = Birdsong.build(action_selection: :argmax, softmax_temperature: 0.35)
    blanket = Blanket.birdsong_default()
    agent = ActiveInferenceAgent.fresh("birdsong-smoke", bundle, blanket)

    obs =
      ObservationPacket.new(%{
        t: 0,
        channels: %{
          heard_motif: :a,
          turn_phase: :response_due,
          self_sang_motif: :none,
          response_fit: :none
        },
        world_run_id: "birdsong-smoke",
        terminal?: false,
        blanket: blanket
      })

    {a1, _} = ActiveInferenceAgent.cmd(agent, {Perceive, %{observation: obs}})
    {a2, _} = ActiveInferenceAgent.cmd(a1, Plan)
    {a3, dirs} = ActiveInferenceAgent.cmd(a2, Act)

    assert a3.state.last_action in bundle.actions
    assert is_list(a3.state.policy_posterior)
    assert_in_delta Enum.sum(a3.state.policy_posterior), 1.0, 1.0e-6
    assert Enum.any?(dirs, &match?(%Jido.Agent.Directive.Emit{}, &1))
  end

  @tag timeout: 120_000
  test "learned songbook can drive a non-complement response through EFE planning" do
    counts = BirdsongSongbook.learn_pairs(nil, [:b], [:d], repetitions: 12)

    bundle =
      Birdsong.build(
        action_selection: :argmax,
        softmax_temperature: 0.35,
        songbook_counts: counts
      )

    blanket = Blanket.birdsong_default()
    agent = ActiveInferenceAgent.fresh("birdsong-learned", bundle, blanket)

    obs =
      ObservationPacket.new(%{
        t: 0,
        channels: %{
          heard_motif: :b,
          turn_phase: :call,
          self_sang_motif: :none,
          response_fit: :none
        },
        world_run_id: "birdsong-learned",
        terminal?: false,
        blanket: blanket
      })

    {a1, _} = ActiveInferenceAgent.cmd(agent, {Perceive, %{observation: obs}})
    {a2, _} = ActiveInferenceAgent.cmd(a1, Plan)

    assert a2.state.last_action == :sing_d
  end

  test "state encoding is reversible" do
    idx = Birdsong.state_index(:a, :response_due, :complement, :b)
    assert Birdsong.decode_state(idx) == {:a, :response_due, :complement, :b}
  end

  defp columns_sum_to_one?(matrix) do
    matrix
    |> transpose()
    |> Enum.all?(fn col -> abs(Enum.sum(col) - 1.0) < 1.0e-6 end)
  end

  defp transpose([]), do: []
  defp transpose([[] | _]), do: []

  defp transpose(m) do
    m
    |> Enum.zip()
    |> Enum.map(&Tuple.to_list/1)
  end
end
