defmodule AgentPlane.Meadow.ExperimentTwoTest do
  @moduledoc """
  EXPERIMENT 2 — Singing co-occurrence in mutually-audible birds.

  Hypothesis (audit-honest, smoke-scale): two ConvergentBirds within
  mutual hearing range, both preferring the same song token, sing at
  non-trivial rates and produce a measurable lagged dependence
  between bird A's emissions at t and bird B's emissions at t+1.

  The original plan named "call-response" as the target, requiring
  temporal anticipation of the partner's response. True call-response
  needs a partner-token-aware bundle (Complex/Resonant) at policy
  depth ≥ 2, which exceeds the default Jido per-action timeout (60 s)
  on 1000-dim observation matvecs in pure Elixir at experimental
  scale. This experiment verifies the *measurement pipeline* (mutual
  information computation between lagged song-emission sequences) on
  ConvergentBird at depth 1, which fits comfortably in budget. The
  full-scale call-response claim with ComplexBird depth ≥ 2 is left
  open pending an Nx-backed math path (documented in
  `project_bird_meadow.md` as future work).

  ## Measure

  Mutual information between
  `A_sang_at_t ∈ {true, false}` and `B_sang_at_{t+1} ∈ {true, false}`,
  computed over the full run as a 2×2 joint histogram.

  ## Scale

  Tagged `:slow_experiment`. Smoke (default): 3 seeds × 30 ticks.
  Quick (`MEADOW_EXPERIMENT_SCALE=quick`): 8 seeds × 80 ticks.
  Full (`MEADOW_EXPERIMENT_SCALE=full`): 20 seeds × 200 ticks.
  """

  use ExUnit.Case, async: false

  alias AgentPlane.{ActiveInferenceAgent, BundleBuilder.Meadow}
  alias AgentPlane.Actions.{Act, Perceive, Plan}
  alias Jido.Agent.Directive
  alias SharedContracts.{ActionPacket, Blanket}
  alias WorldPlane.Worlds.BirdMeadow

  @blanket Blanket.meadow_default()

  defp scale do
    case System.get_env("MEADOW_EXPERIMENT_SCALE") do
      "full" -> %{seeds: 20, ticks: 200}
      "quick" -> %{seeds: 8, ticks: 80}
      _ -> %{seeds: 3, ticks: 30}
    end
  end

  @tag :slow_experiment
  @tag timeout: 600_000
  test "two ConvergentBirds in mutual hearing range produce measurable singing co-occurrence" do
    %{seeds: n_seeds, ticks: n_ticks} = scale()

    results =
      for seed <- 1..n_seeds do
        run_seed(seed, ticks: n_ticks)
      end

    mi_observed = Enum.map(results, fn {mi, _, _} -> mi end)
    n_a_sangs = Enum.map(results, fn {_, a, _} -> a end)
    n_b_sangs = Enum.map(results, fn {_, _, b} -> b end)

    IO.puts("\nExperiment 2 — Singing co-occurrence (#{n_seeds} seeds × #{n_ticks} ticks)")

    IO.puts(
      "  observed MI per seed (nats): #{inspect(Enum.map(mi_observed, &Float.round(&1, 4)))}"
    )

    IO.puts("  bird A sang count per seed:  #{Enum.join(n_a_sangs, ", ")}")
    IO.puts("  bird B sang count per seed:  #{Enum.join(n_b_sangs, ", ")}")

    # At smoke scale we just confirm the measure produces a valid number for
    # every seed and that birds DID sing (no degenerate runs).
    Enum.each(mi_observed, fn mi ->
      assert is_float(mi)
      assert mi >= -1.0e-6, "MI must be non-negative; got #{mi}"
    end)

    # Birds must actually sing for the experiment to be meaningful.
    assert Enum.any?(n_a_sangs, &(&1 > 0)) or Enum.any?(n_b_sangs, &(&1 > 0)),
           "Neither bird sang in any seed — experiment is degenerate"
  end

  # -- Helpers ----------------------------------------------------------------

  defp run_seed(seed, opts) do
    ticks = Keyword.fetch!(opts, :ticks)
    :rand.seed(:exsss, {seed, seed * 11, seed * 17})

    {:ok, meadow} = BirdMeadow.start_link(width: 4, height: 4)
    bundle_a = Meadow.convergent(width: 4, height: 4, preferred_token: :t1)
    bundle_b = Meadow.convergent(width: 4, height: 4, preferred_token: :t1)

    :ok = BirdMeadow.add_bird(meadow, "alice", {0, 1})
    :ok = BirdMeadow.add_bird(meadow, "bob", {3, 1})

    agent_a = ActiveInferenceAgent.fresh("alice", bundle_a, @blanket)
    agent_b = ActiveInferenceAgent.fresh("bob", bundle_b, @blanket)

    {sang_a, sang_b, _, _} =
      Enum.reduce(1..ticks, {[], [], agent_a, agent_b}, fn _t, {sa, sb, a_a, a_b} ->
        {:ok, obs_a} = BirdMeadow.observe(meadow, "alice")
        {:ok, obs_b} = BirdMeadow.observe(meadow, "bob")
        {a_a2, action_a} = perceive_plan_act(a_a, obs_a)
        {a_b2, action_b} = perceive_plan_act(a_b, obs_b)

        actions = %{
          "alice" =>
            ActionPacket.new(%{t: 0, action: action_a, agent_id: "alice", blanket: @blanket}),
          "bob" => ActionPacket.new(%{t: 0, action: action_b, agent_id: "bob", blanket: @blanket})
        }

        {:ok, _} = BirdMeadow.multi_step(meadow, actions)
        {[sang?(action_a) | sa], [sang?(action_b) | sb], a_a2, a_b2}
      end)

    GenServer.stop(meadow)

    sang_a = Enum.reverse(sang_a)
    sang_b = Enum.reverse(sang_b)

    mi = mutual_information_lagged(sang_a, sang_b)
    {mi, Enum.count(sang_a, & &1), Enum.count(sang_b, & &1)}
  end

  defp perceive_plan_act(agent, obs) do
    {a1, _} = ActiveInferenceAgent.cmd(agent, {Perceive, %{observation: obs}})
    {a2, _} = ActiveInferenceAgent.cmd(a1, Plan)
    {a3, dirs} = ActiveInferenceAgent.cmd(a2, Act)

    action =
      case Enum.find(dirs || [], &match?(%Directive.Emit{}, &1)) do
        %Directive.Emit{signal: %{data: %{action: a}}} -> a
        _ -> a3.state.last_action
      end

    {a3, action}
  end

  defp sang?(action) when is_atom(action) do
    str = Atom.to_string(action)
    String.starts_with?(str, "sing_")
  end

  # MI between A_sang_at_t and B_sang_at_{t+1} — over all valid (t, t+1) pairs.
  defp mutual_information_lagged(a_seq, b_seq) do
    pairs = Enum.zip(a_seq, tl(b_seq))
    n = length(pairs) * 1.0

    if n == 0 do
      0.0
    else
      counts =
        Enum.reduce(
          pairs,
          %{{true, true} => 0, {true, false} => 0, {false, true} => 0, {false, false} => 0},
          fn {a, b}, acc ->
            Map.update!(acc, {a, b}, &(&1 + 1))
          end
        )

      p_joint = Enum.into(counts, %{}, fn {k, v} -> {k, v / n} end)

      p_a = %{
        true => p_joint[{true, true}] + p_joint[{true, false}],
        false => p_joint[{false, true}] + p_joint[{false, false}]
      }

      p_b = %{
        true => p_joint[{true, true}] + p_joint[{false, true}],
        false => p_joint[{true, false}] + p_joint[{false, false}]
      }

      Enum.reduce(p_joint, 0.0, fn {{a, b}, p_ab}, acc ->
        denom = p_a[a] * p_b[b]

        if p_ab > 0.0 and denom > 0.0 do
          acc + p_ab * :math.log(p_ab / denom)
        else
          acc
        end
      end)
    end
  end
end
