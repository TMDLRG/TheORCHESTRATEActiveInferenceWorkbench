defmodule WorldPlane.Application do
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      {Registry, keys: :unique, name: WorldPlane.Registry},
      {DynamicSupervisor, strategy: :one_for_one, name: WorldPlane.Supervisor}
    ]

    Supervisor.start_link(children, strategy: :one_for_one, name: WorldPlane.AppSup)
  end
end
