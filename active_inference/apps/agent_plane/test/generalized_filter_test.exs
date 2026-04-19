defmodule AgentPlane.Skills.GeneralizedFilterTest do
  @moduledoc """
  G4 DONE: "Skill + action exist; unit test reproduces eq 8.1 dynamics on a
  tiny sinusoidal world."
  """
  use ExUnit.Case, async: true

  alias AgentPlane.Actions.ContinuousStep
  alias AgentPlane.Skills.GeneralizedFilter

  test "single step pulls x toward the observation under high sensor precision" do
    {:ok, r} =
      GeneralizedFilter.run(
        %{y: 1.0, x: 0.0, v: 0.0, pi_s: 10.0, pi_f: 1.0, kappa: 0.5, dt: 0.1, f_prior: 0.0},
        %{}
      )

    assert r.err_sensor == -1.0
    assert r.x > 0.0, "x increases toward 1.0 under positive sensor error"
    assert r.f > 0.0, "free energy positive when x deviates from y"
  end

  test "filter tracks a constant signal (degenerate case of the sinusoid)" do
    sampler = fn _t -> 2.0 + 0.05 * :rand.normal() end
    :rand.seed(:exsss, {1, 2, 3})

    traj = GeneralizedFilter.trajectory(sampler, steps: 500, pi_s: 20.0, dt: 0.05)

    %{x: final_x} = List.last(traj)
    assert abs(final_x - 2.0) < 0.15, "filter converges to the constant signal mean"
  end

  test "filter smooths a clean sinusoid (eq 8.1 regime)" do
    # Noise-free observation of sin(t) at dt=0.05: the filter should stay
    # within a small envelope of the true signal once warm.
    sampler = fn t -> :math.sin(t) end
    traj = GeneralizedFilter.trajectory(sampler, steps: 400, pi_s: 50.0, dt: 0.05)

    # After a warm-up, the filter should closely track the signal.
    warm = Enum.drop(traj, 200)
    errors = Enum.map(warm, fn %{x: x, t: t} -> abs(x - :math.sin(t)) end)
    mean_err = Enum.sum(errors) / length(errors)

    assert mean_err < 0.2, "mean tracking error after warm-up ≤ 0.2 (got #{mean_err})"
  end

  test "ContinuousStep action wraps the filter with dt bookkeeping" do
    {:ok, r} =
      ContinuousStep.run(
        %{
          y: 0.5,
          t: 0.0,
          dt: 0.05,
          x: 0.0,
          v: 0.0,
          pi_s: 10.0,
          pi_f: 1.0,
          kappa: 0.5
        },
        %{}
      )

    assert r.t == 0.05
    assert r.x > 0.0
    assert is_float(r.f)
  end
end
