defmodule ActiveInferenceCore.Math do
  @moduledoc """
  Low-level numerical primitives used by the discrete-time Active Inference core.

  All operations are on plain Elixir lists (vectors) and lists-of-lists (matrices).
  We deliberately avoid a binding to Nx / external tensor libraries so the
  workbench compiles on a bare Elixir/OTP install — the maze MVP fits easily
  in pure BEAM math.
  """

  @typedoc "A probability vector (1-D)."
  @type vec :: [float()]

  @typedoc "A matrix as a list of row vectors."
  @type mat :: [vec()]

  @eps 1.0e-16

  # ---------------------------------------------------------------------------
  # Vector / matrix utilities
  # ---------------------------------------------------------------------------

  @doc "Element-wise natural log with `@eps` floor to prevent −∞."
  @spec log_eps(vec()) :: vec()
  def log_eps(v) when is_list(v), do: Enum.map(v, fn x -> :math.log(max(x, @eps)) end)

  @doc "Element-wise natural log of a matrix."
  @spec log_eps_mat(mat()) :: mat()
  def log_eps_mat(m), do: Enum.map(m, &log_eps/1)

  @doc "Element-wise product of two equal-length vectors."
  @spec hadamard(vec(), vec()) :: vec()
  def hadamard(a, b), do: Enum.zip_with(a, b, &(&1 * &2))

  @doc "Dot product of two vectors."
  @spec dot(vec(), vec()) :: float()
  def dot(a, b), do: Enum.zip_with(a, b, &(&1 * &2)) |> Enum.sum()

  @doc "Sum of a vector."
  @spec sum(vec()) :: float()
  def sum(v), do: Enum.sum(v)

  @doc "Vector scaling."
  @spec scale(vec(), number()) :: vec()
  def scale(v, k), do: Enum.map(v, &(&1 * k))

  @doc "Vector addition."
  @spec add(vec(), vec()) :: vec()
  def add(a, b), do: Enum.zip_with(a, b, &(&1 + &2))

  @doc "Vector subtraction."
  @spec sub(vec(), vec()) :: vec()
  def sub(a, b), do: Enum.zip_with(a, b, &(&1 - &2))

  @doc "Matrix transpose."
  @spec transpose(mat()) :: mat()
  def transpose([]), do: []
  def transpose([[] | _]), do: []

  def transpose(m) do
    m
    |> Enum.zip()
    |> Enum.map(&Tuple.to_list/1)
  end

  @doc "Matrix-vector product: M (n×m) × v (m) -> (n)."
  @spec matvec(mat(), vec()) :: vec()
  def matvec(m, v), do: Enum.map(m, fn row -> dot(row, v) end)

  @doc "Element-wise log of a matrix times a vector: ln(M) · v."
  @spec log_matvec(mat(), vec()) :: vec()
  def log_matvec(m, v), do: matvec(log_eps_mat(m), v)

  # ---------------------------------------------------------------------------
  # Probability-simplex utilities
  # ---------------------------------------------------------------------------

  @doc "Normalise a vector so its entries sum to 1. Empty vector returns itself."
  @spec normalise(vec()) :: vec()
  def normalise([]), do: []

  def normalise(v) do
    s = sum(v)
    if s <= 0.0, do: Enum.map(v, fn _ -> 1.0 / length(v) end), else: scale(v, 1.0 / s)
  end

  @doc """
  Softmax: σ(v)_i = exp(v_i) / Σ_j exp(v_j). Uses the standard max-shift trick.
  """
  @spec softmax(vec()) :: vec()
  def softmax([]), do: []

  def softmax(v) do
    m = Enum.max(v)
    ex = Enum.map(v, fn x -> :math.exp(x - m) end)
    z = Enum.sum(ex)
    Enum.map(ex, &(&1 / z))
  end

  @doc "Shannon entropy H[p] = −Σ p_i ln p_i."
  @spec entropy(vec()) :: float()
  def entropy(p), do: -dot(p, log_eps(p))

  @doc "KL divergence D_KL[q || p]."
  @spec kl(vec(), vec()) :: float()
  def kl(q, p), do: dot(q, sub(log_eps(q), log_eps(p)))

  @doc """
  Per-state ambiguity vector used in expected free energy:

      H ≜ −diag(A · ln A)         (eq. 4.10 / B.29)

  Returns a vector of length equal to the number of columns (states) of A.
  """
  @spec ambiguity_vector(mat()) :: vec()
  def ambiguity_vector(a) do
    # for each column j: -sum_i A_{ij} ln A_{ij}
    cols = transpose(a)

    Enum.map(cols, fn col ->
      -dot(col, log_eps(col))
    end)
  end

  # ---------------------------------------------------------------------------
  # Convenience: build categorical distributions
  # ---------------------------------------------------------------------------

  @doc "One-hot vector of dimension `n` with a 1 at 0-based index `i`."
  @spec one_hot(non_neg_integer(), non_neg_integer()) :: vec()
  def one_hot(n, i) do
    for k <- 0..(n - 1), do: if(k == i, do: 1.0, else: 0.0)
  end

  @doc "Uniform probability vector of dimension `n`."
  @spec uniform(non_neg_integer()) :: vec()
  def uniform(n), do: List.duplicate(1.0 / n, n)
end
