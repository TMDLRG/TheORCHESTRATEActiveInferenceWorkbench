defmodule AgentPlane.Application do
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      AgentPlane.JidoInstance,
      {Registry, keys: :duplicate, name: AgentPlane.Telemetry.Registry}
    ]

    # Plan §8.6 — forward JIDO's built-in telemetry onto WorldModels.Bus so
    # the Glass Engine sees runtime-level signal/directive lifecycle without
    # any Episode-level instrumentation.
    _ = AgentPlane.Telemetry.Bus.attach()

    Supervisor.start_link(children, strategy: :one_for_one, name: AgentPlane.AppSup)
  end
end
