defmodule AgentPlane.Meadow.NxBenchmarkTest do
  @moduledoc """
  AUDIT REGRESSION (external review W1, v1+v2) — the substrate finding.

  ## What this measures

  Single-tick wall-clock time for ComplexBird at policy_depth = 2 on
  the meadow's 1000-dim observation space. Pure-Elixir baseline only.

  ## Why this no longer compares pure-Elixir vs Nx through the agent

  The minimum-viable Nx port (`ActiveInferenceCore.Math.Nx`) proved
  primitive-level equivalence to `1.0e-9` (see
  `apps/active_inference_core/test/math_nx_test.exs`). Wiring it via a
  config-flag dispatch on `Math.matvec/2` and `Math.softmax/1` was
  prototyped and **measured as a regression**: ~5× slower than pure-
  Elixir under the default BinaryBackend on the meadow inner sweep,
  with accumulated summation-order divergence above the 1e-6 threshold
  on long sums after the log_eps + matvec composition.

  The honest finding: drop-in primitive replacement is the wrong
  design. Per-call `Nx.tensor(...)` / `Nx.to_list(...)` boundary
  conversions dominate when the kernel itself is small (single matvec
  on a few thousand elements) and is invoked thousands of times per
  Plan. To deliver a speedup, the inner sweep must be tensorised as a
  whole — batched matvec across policies, `defn`-compiled kernels,
  and an EXLA / Torchx backend so conversion cost amortises. That is
  multi-week work tracked in `OPS.md` §4 as `v2.1`.

  ## What this file ships

  This file ships as an **audit anchor** for the substrate finding:
  it measures and reports the pure-Elixir baseline so future work has
  a fixed-point reference, and asserts only that the baseline runs
  without timing out (the basic `Plan` correctness gate). Acceptance
  on the 5s-per-tick gate from `OPS.md` §4 is **not currently met by
  pure-Elixir at 4×4 meadow scale either** — that gate is for the
  redesigned Nx path, not the reference implementation.

  Tagged `:slow_experiment`. Skips on CI by default.
  """

  use ExUnit.Case, async: false

  alias AgentPlane.{ActiveInferenceAgent, BundleBuilder.Meadow}
  alias AgentPlane.Actions.{Perceive, Plan}
  alias SharedContracts.{Blanket, ObservationPacket}

  @blanket Blanket.meadow_default()

  @tag :slow_experiment
  @tag timeout: 600_000
  test "ComplexBird depth-2 single tick: pure-Elixir baseline measurement" do
    bundle = Meadow.complex(width: 4, height: 4, preferred_token: :t1, policy_depth: 2)

    obs = make_obs()

    {agent, us} = bench_one_tick(bundle, obs)
    seconds = us / 1_000_000

    IO.puts("\n" <> String.duplicate("=", 70))
    IO.puts("Substrate baseline — ComplexBird depth-2 single tick (pure-Elixir)")
    IO.puts("  Bundle: 4×4 meadow, n_states=#{bundle.dims.n_states}, n_obs=#{bundle.dims.n_obs}")
    IO.puts("  Policies: #{length(bundle.policies)}")
    IO.puts(String.duplicate("-", 70))
    IO.puts("  Pure Elixir tick:     #{Float.round(seconds, 2)}s")
    IO.puts("  Acceptance gate:      5.00s  (OPS.md §4 — for v2.1 Nx redesign, not pure path)")
    IO.puts("  Jido per-action gate: 60.00s (must clear; pure path does)")
    IO.puts(String.duplicate("-", 70))

    cond do
      seconds < 5.0 ->
        IO.puts("  STATUS: ✅ Pure-Elixir under v2.1 acceptance gate (unexpected — note in OPS.md)")

      seconds < 60.0 ->
        IO.puts("  STATUS: 🟡 Pure-Elixir under Jido per-action timeout. v2.1 Nx redesign needed for 5s gate.")

      true ->
        IO.puts("  STATUS: 🔴 Pure-Elixir EXCEEDS Jido 60s timeout — substrate ceiling reached.")
    end

    IO.puts(String.duplicate("=", 70))

    # Sanity: the pure path produced a valid marginal_state_belief.
    marginal = agent.state.marginal_state_belief
    assert is_list(marginal) and length(marginal) > 0,
           "Pure-Elixir Plan must produce a marginal_state_belief"

    sum = Enum.sum(marginal)
    assert_in_delta sum, 1.0, 1.0e-6,
                    "marginal_state_belief must sum to 1 (normalised posterior)"

    # Document the substrate finding by committing the threshold:
    # baseline must clear the Jido per-action timeout (otherwise the
    # workbench is broken at meadow scale). The 5s gate is a
    # forward-looking target for the v2.1 Nx redesign, NOT a hard
    # assertion against pure-Elixir at this scale.
    assert us < 60_000_000,
           "Pure-Elixir tick exceeded 60s Jido per-action timeout — substrate ceiling reached at this scale. See OPS.md §4."
  end

  defp bench_one_tick(bundle, obs) do
    agent = ActiveInferenceAgent.fresh("nx-bench", bundle, @blanket)

    # Warm-up: one Perceive+Plan to populate beliefs.
    {a1, _} = ActiveInferenceAgent.cmd(agent, {Perceive, %{observation: obs}})
    {a2, _} = ActiveInferenceAgent.cmd(a1, Plan)

    # Measured tick: another Perceive+Plan with timing.
    {us, agent_after} =
      :timer.tc(fn ->
        {a3, _} = ActiveInferenceAgent.cmd(a2, {Perceive, %{observation: obs}})
        {a4, _} = ActiveInferenceAgent.cmd(a3, Plan)
        a4
      end)

    {agent_after, us}
  end

  defp make_obs do
    ObservationPacket.new(%{
      t: 0,
      channels: %{
        wall_sig: :open,
        hearing_amp: :loud,
        hearing_token: :t1,
        hearing_bearing: :east,
        self_sang_token: :none
      },
      world_run_id: "nx-bench",
      terminal?: false,
      blanket: @blanket
    })
  end
end
