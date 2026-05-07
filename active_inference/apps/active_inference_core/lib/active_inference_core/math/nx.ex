defmodule ActiveInferenceCore.Math.Nx do
  @moduledoc """
  Nx-backed implementations of the math primitives that dominate hot
  paths in `ActiveInferenceCore.DiscreteTime`.

  ## Status: equivalence proven, drop-in dispatch deferred

  This module exists to **prove primitive-level numerical equivalence**
  to the pure-Elixir reference (`ActiveInferenceCore.Math`) under Nx's
  default BinaryBackend. `test/math_nx_test.exs` asserts equivalence to
  within `1.0e-9` on random inputs at meadow scale (1000 × 1152) and
  edge cases.

  Drop-in dispatch — wiring `Math.matvec/2` and `Math.softmax/1` to call
  through this module via a config flag — was prototyped and **measured
  as a regression**: see `apps/agent_plane/test/meadow/nx_benchmark_test.exs`.
  The minimum-viable port wraps each call with `Nx.tensor(...)` /
  `Nx.to_list(...)` boundary conversions; on the Active Inference inner
  sweep (thousands of small matvecs per Plan), per-call conversion
  overhead dominates the kernel cost. Pure-Elixir wins by ~5× under the
  default BinaryBackend.

  The honest finding: **drop-in primitive replacement is the wrong
  design**. To deliver a speedup, the inner sweep must be tensorised as
  a whole — batched matvec across policies, `defn`-compiled kernels,
  and an EXLA or Torchx backend so the conversion cost amortises across
  many ops. That is multi-week work tracked in `OPS.md` §4 as `v2.1`.

  This module ships as the **proof of equivalence** that the future
  redesign builds on. The Math module's public path remains pure-Elixir.

  ## Audit credit

  External review W1 (Wolpert) named the substrate as the limit. The v2
  delta review escalated it to "load-bearing capability constraint." The
  scoping above is the honest response: equivalence proven, perf
  refuted, redesign documented.
  """

  alias ActiveInferenceCore.Math

  @doc """
  Matrix-vector product `M × v`. Same shape contract as
  `ActiveInferenceCore.Math.matvec/2`.

  Converts `M` and `v` to `Nx.tensor`s, computes `Nx.dot/2`, converts
  back to a list. Equivalence to the pure-Elixir path is asserted to
  `1.0e-9` by `test/math_nx_test.exs`.
  """
  @spec matvec(Math.mat(), Math.vec()) :: Math.vec()
  def matvec(matrix, vector) when is_list(matrix) and is_list(vector) do
    m_tensor = Nx.tensor(matrix, type: :f64)
    v_tensor = Nx.tensor(vector, type: :f64)

    Nx.dot(m_tensor, v_tensor)
    |> Nx.to_list()
  end

  @doc """
  Softmax with the standard max-shift trick. Same shape contract as
  `ActiveInferenceCore.Math.softmax/1`.

  Empty vectors return `[]` for parity with the pure-Elixir version.
  Equivalence asserted to `1.0e-9` by `test/math_nx_test.exs`.
  """
  @spec softmax(Math.vec()) :: Math.vec()
  def softmax([]), do: []

  def softmax(vector) when is_list(vector) do
    t = Nx.tensor(vector, type: :f64)
    max = Nx.reduce_max(t)
    shifted = Nx.subtract(t, max)
    exp = Nx.exp(shifted)
    z = Nx.sum(exp)

    Nx.divide(exp, z)
    |> Nx.to_list()
  end
end
