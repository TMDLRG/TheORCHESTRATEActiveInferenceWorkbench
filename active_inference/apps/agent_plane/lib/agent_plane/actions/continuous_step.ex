defmodule AgentPlane.Actions.ContinuousStep do
  @moduledoc """
  Jido action: single step of a continuous-time active-inference agent.
  G4 (RUNTIME_GAPS.md) -- cookbook recipes that teach continuous-time
  inference (generalised coordinates) use this.

  Like the discrete-time `Actions.Perceive`, this action does not reach
  into the world plane -- the observation `y` is passed in.  Callers
  (cookbook recipe harnesses, tests) sample their
  `WorldPlane.ContinuousWorlds.t()` and pass the scalar observation
  through.  This preserves the Markov-blanket invariant (CLAUDE.md).
  """

  use Jido.Action,
    name: "continuous_step",
    description:
      "One continuous-time inference step (generalised coordinates; 1 state, 1 sensor, 2 orders).",
    schema: [
      y: [type: :float, required: true, doc: "observation sampled from the world"],
      t: [type: :float, required: true],
      dt: [type: :float, default: 0.05, doc: "integration step"],
      x: [type: :float, default: 0.0],
      v: [type: :float, default: 0.0],
      pi_s: [type: :float, default: 10.0],
      pi_f: [type: :float, default: 1.0],
      kappa: [type: :float, default: 0.5]
    ]

  alias AgentPlane.Skills.GeneralizedFilter

  @impl true
  def run(
        %{
          y: y,
          t: t,
          dt: dt,
          x: x,
          v: v,
          pi_s: pi_s,
          pi_f: pi_f,
          kappa: kappa
        },
        _ctx
      ) do
    {:ok, filter_result} =
      GeneralizedFilter.run(
        %{
          y: y,
          x: x,
          v: v,
          pi_s: pi_s,
          pi_f: pi_f,
          kappa: kappa,
          dt: dt,
          f_prior: 0.0
        },
        %{}
      )

    {:ok,
     %{
       t: t + dt,
       y: y,
       x: filter_result.x,
       v: filter_result.v,
       err_sensor: filter_result.err_sensor,
       err_dynamics: filter_result.err_dynamics,
       f: filter_result.f
     }}
  end
end
