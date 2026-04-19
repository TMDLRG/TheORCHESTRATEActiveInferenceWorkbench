defmodule CompositionRuntime.Application do
  @moduledoc false
  use Application

  @impl true
  def start(_type, _args) do
    children = [
      # Global name registry shared by every composition's broker.
      {Elixir.Registry, keys: :unique, name: CompositionRuntime.NameRegistry},
      {DynamicSupervisor, strategy: :one_for_one, name: CompositionRuntime.RootSupervisor},
      CompositionRuntime.Registry
    ]

    Supervisor.start_link(children, strategy: :one_for_one, name: CompositionRuntime.AppSup)
  end
end
