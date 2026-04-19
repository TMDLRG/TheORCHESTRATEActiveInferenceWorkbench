defmodule AgentPlane.Actions.PredictiveCodingPassTest do
  @moduledoc """
  G3 DONE: "Action exists; unit test runs 2 levels, shows top-down prediction
  + bottom-up error flow."
  """
  use ExUnit.Case, async: true

  alias AgentPlane.Actions.PredictiveCodingPass

  test "single pass computes both errors and non-zero free energy" do
    {:ok, r} =
      PredictiveCodingPass.run(
        %{observation: 1.0, mu1: 0.0, mu2: 0.0, pi1: 1.0, pi2: 1.0, learning_rate: 0.1},
        %{}
      )

    assert r.err_obs == 1.0
    assert r.err_top_down == 0.0
    assert r.mu1 > 0.0, "bottom-up error should pull mu1 toward the observation"
    assert r.mu2 == 0.0, "without top-down error, mu2 is unchanged"
    assert r.f_total > 0.0
  end

  test "sweep converges mu1 and mu2 toward the observation" do
    %{mus: trajectory, final_f: final_f} =
      PredictiveCodingPass.sweep(1.0, 0.0, 0.0, 1.0, 1.0, 0.2, 100)

    {final_mu1, final_mu2} = List.last(trajectory)
    assert abs(final_mu1 - 1.0) < 0.05, "mu1 converges to the observation"
    assert abs(final_mu2 - 1.0) < 0.1, "mu2 converges toward mu1"
    assert final_f < 0.01, "free energy drops toward zero at equilibrium"
  end

  test "higher pi1 makes mu1 follow the observation more tightly" do
    %{mus: high_pi} = PredictiveCodingPass.sweep(1.0, 0.0, 0.0, 10.0, 1.0, 0.05, 50)
    %{mus: low_pi} = PredictiveCodingPass.sweep(1.0, 0.0, 0.0, 1.0, 1.0, 0.05, 50)

    {high_mu1, _} = List.last(high_pi)
    {low_mu1, _} = List.last(low_pi)
    assert high_mu1 > low_mu1, "higher sensor precision pulls mu1 closer to y"
  end
end
