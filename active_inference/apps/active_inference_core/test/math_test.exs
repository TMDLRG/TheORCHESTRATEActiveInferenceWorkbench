defmodule ActiveInferenceCore.MathTest do
  use ExUnit.Case, async: true

  alias ActiveInferenceCore.Math

  # Euler–Mascheroni constant: ψ(1) = −γ.
  @euler_gamma 0.5772156649015329

  describe "digamma/1 (ψ — expected-log sufficient statistic)" do
    test "ψ(1) = −γ (Euler–Mascheroni)" do
      assert_in_delta Math.digamma(1.0), -@euler_gamma, 1.0e-9
    end

    test "ψ(2) = 1 − γ" do
      assert_in_delta Math.digamma(2.0), 1.0 - @euler_gamma, 1.0e-9
    end

    test "ψ(1/2) = −γ − 2 ln 2" do
      assert_in_delta Math.digamma(0.5), -@euler_gamma - 2.0 * :math.log(2.0), 1.0e-9
    end

    test "recurrence ψ(x+1) = ψ(x) + 1/x holds across the positive axis" do
      for x <- [0.3, 0.9, 1.7, 2.5, 5.9, 6.1, 12.4, 40.0] do
        assert_in_delta Math.digamma(x + 1.0), Math.digamma(x) + 1.0 / x, 1.0e-10
      end
    end

    test "ψ is strictly increasing on the positive axis" do
      xs = [0.2, 0.5, 1.0, 2.0, 5.0, 6.0, 10.0, 100.0]
      vals = Enum.map(xs, &Math.digamma/1)

      Enum.zip(vals, tl(vals))
      |> Enum.each(fn {a, b} -> assert a < b end)
    end

    test "large argument matches the leading asymptotic ln x − 1/(2x)" do
      for x <- [50.0, 500.0, 5000.0] do
        assert_in_delta Math.digamma(x), :math.log(x) - 0.5 / x, 1.0e-4
      end
    end
  end

  describe "dirichlet_expected_log/1 (E[ln A] = ψ(α) − ψ(Σα), column-wise)" do
    test "single-column worked example reduces to exact rationals" do
      # Column counts [3, 1]: E[ln A_0] = ψ(3) − ψ(4) = −1/3;
      #                       E[ln A_1] = ψ(1) − ψ(4) = −(1 + 1/2 + 1/3) = −11/6.
      [[e0], [e1]] = Math.dirichlet_expected_log([[3.0], [1.0]])
      assert_in_delta e0, -1.0 / 3.0, 1.0e-9
      assert_in_delta e1, -11.0 / 6.0, 1.0e-9
    end

    test "two-state worked example normalises over outcomes per column" do
      # col0 = [2,1] (Σ=3): [ψ(2)−ψ(3), ψ(1)−ψ(3)] = [−1/2, −3/2]
      # col1 = [1,5] (Σ=6): [ψ(1)−ψ(6), ψ(5)−ψ(6)] = [−(1+½+⅓+¼+⅕), −1/5]
      [[a00, a01], [a10, a11]] =
        Math.dirichlet_expected_log([[2.0, 1.0], [1.0, 5.0]])

      assert_in_delta a00, -0.5, 1.0e-9
      assert_in_delta a10, -1.5, 1.0e-9
      assert_in_delta a01, -(1.0 + 0.5 + 1.0 / 3.0 + 0.25 + 0.2), 1.0e-9
      assert_in_delta a11, -0.2, 1.0e-9
    end

    test "preserves matrix shape" do
      alpha = [[2.0, 1.0, 4.0], [1.0, 5.0, 2.0]]
      elog = Math.dirichlet_expected_log(alpha)
      assert length(elog) == 2
      assert Enum.all?(elog, &(length(&1) == 3))
    end

    test "Jensen: E[ln A] ≤ ln E[A] entrywise" do
      alpha = [[2.0, 1.0], [1.0, 5.0], [3.0, 2.0]]
      elog = Math.dirichlet_expected_log(alpha)

      # ln of the Dirichlet mean = ln of the column-normalised counts.
      log_mean =
        alpha
        |> Math.transpose()
        |> Enum.map(&Math.normalise/1)
        |> Enum.map(&Math.log_eps/1)
        |> Math.transpose()

      Enum.zip(List.flatten(elog), List.flatten(log_mean))
      |> Enum.each(fn {e, lm} -> assert e <= lm + 1.0e-12 end)
    end

    test "gap to the log-mean shrinks as evidence concentrates" do
      base = [[3.0], [1.0]]
      heavy = [[300.0], [100.0]]

      gap = fn alpha ->
        [elog] = alpha |> Math.dirichlet_expected_log() |> Math.transpose()

        [logmean] =
          alpha |> Math.transpose() |> Enum.map(&Math.normalise/1) |> Enum.map(&Math.log_eps/1)

        Enum.zip(elog, logmean)
        |> Enum.map(fn {e, lm} -> abs(lm - e) end)
        |> Enum.sum()
      end

      assert gap.(heavy) < gap.(base)
    end

    test "floors zero counts instead of returning −∞" do
      [[e0], [e1]] = Math.dirichlet_expected_log([[5.0], [0.0]])
      # Both entries are ordinary finite floats — the @eps floor keeps ψ in
      # its domain, so no IEEE −∞ and no NaN (NaN would fail `x == x`).
      assert is_float(e0) and e0 == e0
      assert is_float(e1) and e1 == e1
      # The unseen outcome is driven very negative (floor ⇒ ψ(1e-16) ≈ −1e16)
      # but remains finite, and is far below the well-supported outcome.
      assert e1 < e0
      assert e1 < -1.0e10
    end
  end
end
