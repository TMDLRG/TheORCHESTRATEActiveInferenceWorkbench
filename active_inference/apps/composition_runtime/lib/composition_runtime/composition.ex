defmodule CompositionRuntime.Composition do
  @moduledoc """
  Supervisor for a single composition — one `SignalBroker` plus every
  agent process (supervised via `AgentPlane.Runtime.start_agent/1`).

  The supervisor strategy is `:one_for_one`: a crashing agent doesn't
  topple its siblings. The broker is a permanent child; if it dies,
  in-flight cross-agent signals vanish but the agents themselves keep
  running (they can be reconnected to a fresh broker on restart).
  """

  use Supervisor

  alias AgentPlane.Runtime
  alias CompositionRuntime.SignalBroker

  @spec start_link(map()) :: Supervisor.on_start()
  def start_link(%{composition_id: id} = spec) do
    Supervisor.start_link(__MODULE__, spec, name: via(id))
  end

  @impl true
  def init(%{composition_id: id, agents: agents, wires: wires}) do
    children = [
      {SignalBroker, composition_id: id, wires: wires},
      %{
        id: {:boot, id},
        start: {Task, :start_link, [fn -> boot_agents(id, agents) end]},
        restart: :transient
      }
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end

  defp via(id),
    do: {:via, Elixir.Registry, {CompositionRuntime.NameRegistry, {:composition, id}}}

  defp boot_agents(composition_id, agents) do
    Enum.each(agents, fn agent ->
      case Runtime.start_agent(agent) do
        {:ok, agent_id, pid} ->
          SignalBroker.register_agent(composition_id, agent_id, pid)

        {:error, reason} ->
          require Logger

          Logger.error(
            "composition=#{composition_id} failed to start agent=#{agent.agent_id}: #{inspect(reason)}"
          )
      end
    end)
  end
end
