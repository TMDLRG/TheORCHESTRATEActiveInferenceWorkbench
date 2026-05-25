defmodule AgentPlane.BirdsongMathCrossValidationTest do
  use ExUnit.Case, async: true

  alias ActiveInferenceCore.{DiscreteTime, Math}
  alias AgentPlane.{ActiveInferenceAgent, BirdsongObsAdapter, BirdsongSongbook}
  alias AgentPlane.Actions.{Act, Perceive, Plan}
  alias AgentPlane.BundleBuilder.Birdsong
  alias SharedContracts.{Blanket, ObservationPacket}

  @tag timeout: 120_000
  test "birdsong bundle obeys categorical POMDP normalization and finite free energies" do
    counts = BirdsongSongbook.learn_pairs(nil, [:a, :b, :c, :d], [:d, :c, :a, :b], repetitions: 6)
    bundle = Birdsong.build(policy_depth: 1, action_selection: :argmax, songbook_counts: counts)

    assert column_stochastic?(bundle.a)
    assert Enum.all?(bundle.b, fn {_action, b} -> column_stochastic?(b) end)
    assert simplex?(bundle.d)
    assert log_distribution?(bundle.c)

    beliefs = DiscreteTime.fresh_beliefs(bundle)

    obs =
      Math.one_hot(
        BirdsongObsAdapter.n_obs(),
        BirdsongObsAdapter.obs_index(:b, :call, :none, :none)
      )

    swept =
      DiscreteTime.sweep_state_beliefs(
        beliefs,
        bundle.policies,
        bundle.b,
        bundle.a,
        [obs],
        bundle.d,
        3
      )

    f =
      DiscreteTime.variational_free_energy(
        Map.fetch!(swept, 0),
        Enum.at(bundle.policies, 0),
        bundle.b,
        bundle.a,
        [obs],
        bundle.d
      )

    efe = DiscreteTime.expected_free_energy(Map.fetch!(swept, 0), bundle.a, bundle.c, 0)

    assert finite?(f)
    assert finite?(efe.total)
    assert Enum.all?(efe.per_tau, &finite?/1)
    assert Enum.all?(efe.ambiguity_per_tau, &(&1 >= 0.0 and finite?(&1)))
    assert Enum.all?(efe.risk_per_tau, &finite?/1)
  end

  test "policy posterior uses the documented softmax sign convention" do
    f = [0.0, 1.0, 2.0]
    g = [2.0, 0.5, 0.0]
    e = [0.2, 0.3, 0.5]
    temperature = 0.75

    posterior = DiscreteTime.policy_posterior(f, g, e, temperature: temperature)

    expected =
      e
      |> Math.log_eps()
      |> Math.add(Enum.map(f, &(-&1)))
      |> Math.add(Enum.map(g, &(-&1)))
      |> Enum.map(&(&1 / temperature))
      |> Math.softmax()

    assert_lists_close(posterior, expected, 1.0e-12)
    assert simplex?(posterior)
  end

  @tag timeout: 120_000
  test "learned songbook changes action selection through Jido Plan, not template lookup" do
    counts = BirdsongSongbook.learn_pairs(nil, [:b], [:d], repetitions: 12)

    bundle =
      Birdsong.build(
        policy_depth: 1,
        action_selection: :argmax,
        softmax_temperature: 0.35,
        songbook_counts: counts
      )

    blanket = Blanket.birdsong_default()
    agent = ActiveInferenceAgent.fresh("birdsong-cross-validate", bundle, blanket)

    obs =
      ObservationPacket.new(%{
        t: 0,
        channels: %{
          heard_motif: :b,
          turn_phase: :call,
          self_sang_motif: :none,
          response_fit: :none
        },
        world_run_id: "birdsong-cross-validate",
        terminal?: false,
        blanket: blanket
      })

    {a1, _} = ActiveInferenceAgent.cmd(agent, {Perceive, %{observation: obs}})
    {a2, _} = ActiveInferenceAgent.cmd(a1, Plan)
    {a3, directives} = ActiveInferenceAgent.cmd(a2, Act)

    assert a3.state.last_action == :sing_d
    assert Enum.any?(directives, &match?(%Jido.Agent.Directive.Emit{}, &1))
    assert a3.state.last_g != []
    assert a3.state.last_f != []
    assert simplex?(a3.state.policy_posterior)

    best_policy = Enum.at(bundle.policies, a3.state.last_policy_best_idx)
    assert best_policy == [:sing_d]
  end

  defp column_stochastic?(matrix) do
    matrix
    |> Math.transpose()
    |> Enum.all?(&simplex?/1)
  end

  defp simplex?(vector) do
    Enum.all?(vector, &(&1 >= 0.0 and finite?(&1))) and
      abs(Enum.sum(vector) - 1.0) < 1.0e-6
  end

  defp log_distribution?(log_vector) do
    log_vector
    |> Enum.map(&:math.exp/1)
    |> simplex?()
  end

  defp finite?(x), do: is_number(x) and x == x and x not in [:infinity, :neg_infinity]

  defp assert_lists_close(a, b, eps) do
    assert length(a) == length(b)

    Enum.zip(a, b)
    |> Enum.each(fn {x, y} -> assert_in_delta x, y, eps end)
  end
end
