defmodule AgentPlane.Skills.GeneralizedFilter do
  @moduledoc """
  Continuous-time generalized-coordinate filter.  G4 (RUNTIME_GAPS.md).

  State is carried in generalised coordinates up to 2 orders -- position
  `x` and velocity `x'`.  One step of the filter predicts via the shift
  operator D and updates via precision-weighted prediction errors:

      x   <- x  + dt * (x' - kappa * pi_s * (x - y))
      x'  <- x' + dt * (f'(x) - kappa * pi_f * (x' - f(x)))

  For the cookbook's sinusoid-tracker fixture, f(x) = 0 (a free particle
  prior), so the second update collapses to a smoothing term on x'.

  Scope is deliberately narrow (1 hidden state, 1 sensor, 2 orders) per
  the plan's G4 DONE criterion.
  """

  use Jido.Action,
    name: "generalized_filter_step",
    description: "One step of a continuous-time generalised-coordinate filter (eq 8.1 regime).",
    schema: [
      y: [type: :float, required: true, doc: "observation at time t"],
      x: [type: :float, required: true, doc: "position belief (order 0)"],
      v: [type: :float, required: true, doc: "velocity belief (order 1)"],
      pi_s: [type: :float, default: 10.0, doc: "sensor precision"],
      pi_f: [type: :float, default: 1.0, doc: "dynamics precision"],
      kappa: [type: :float, default: 0.5, doc: "learning rate"],
      dt: [type: :float, default: 0.05],
      f_prior: [type: :float, default: 0.0, doc: "f(x) prior drift; 0 = free particle"]
    ]

  @impl true
  def run(
        %{
          y: y,
          x: x,
          v: v,
          pi_s: pi_s,
          pi_f: pi_f,
          kappa: kappa,
          dt: dt,
          f_prior: fp
        },
        _ctx
      ) do
    err_sensor = x - y
    err_dynamics = v - fp

    x_new = x + dt * (v - kappa * pi_s * err_sensor)
    v_new = v - dt * kappa * pi_f * err_dynamics

    # Gaussian free energy approximation for diagnostics.
    f = 0.5 * (pi_s * err_sensor * err_sensor + pi_f * err_dynamics * err_dynamics)

    {:ok,
     %{
       x: x_new,
       v: v_new,
       err_sensor: err_sensor,
       err_dynamics: err_dynamics,
       f: f
     }}
  end

  @doc """
  Run `n` integration steps, given a caller-supplied `sampler_fn(t) -> y`.
  Returns the trajectory of (t, y_observed, x_est, v_est, f).  Keeping the
  sampler as a closure preserves the Markov-blanket invariant (agent-plane
  code never reaches into the world plane directly; callers do the
  sampling and pass observations in).
  """
  @spec trajectory((float() -> float()), keyword()) :: [
          %{t: float(), y: float(), x: float(), v: float(), f: float()}
        ]
  def trajectory(sampler_fn, opts \\ []) when is_function(sampler_fn, 1) do
    steps = Keyword.get(opts, :steps, 200)
    pi_s = Keyword.get(opts, :pi_s, 10.0)
    pi_f = Keyword.get(opts, :pi_f, 1.0)
    kappa = Keyword.get(opts, :kappa, 0.5)
    dt = Keyword.get(opts, :dt, 0.05)

    Enum.reduce(0..(steps - 1), %{x: 0.0, v: 0.0, acc: []}, fn k, acc ->
      t = k * dt
      y = sampler_fn.(t)

      {:ok, r} =
        run(
          %{
            y: y,
            x: acc.x,
            v: acc.v,
            pi_s: pi_s,
            pi_f: pi_f,
            kappa: kappa,
            dt: dt,
            f_prior: 0.0
          },
          %{}
        )

      %{
        x: r.x,
        v: r.v,
        acc: acc.acc ++ [%{t: t, y: y, x: r.x, v: r.v, f: r.f}]
      }
    end)
    |> Map.fetch!(:acc)
  end
end
