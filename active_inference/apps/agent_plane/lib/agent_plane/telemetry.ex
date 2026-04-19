defmodule AgentPlane.Telemetry do
  @moduledoc """
  Lightweight pub-sub for agent-plane telemetry events.

  The UI subscribes to a topic and gets every step's (obs, action,
  posterior, beliefs, F, G) tuple. This keeps the agent plane decoupled
  from the UI while still allowing live inspection.
  """

  @registry AgentPlane.Telemetry.Registry

  @doc "Subscribe the calling process to telemetry for a given agent id."
  @spec subscribe(String.t()) :: {:ok, pid()}
  def subscribe(agent_id), do: Registry.register(@registry, agent_id, nil)

  @doc "Unsubscribe the calling process."
  @spec unsubscribe(String.t()) :: :ok
  def unsubscribe(agent_id), do: Registry.unregister(@registry, agent_id)

  @doc "Broadcast a telemetry event to all subscribers of `agent_id`."
  @spec broadcast(String.t(), map()) :: :ok
  def broadcast(agent_id, payload) when is_map(payload) do
    for {pid, _} <- Registry.lookup(@registry, agent_id) do
      send(pid, {:agent_telemetry, agent_id, payload})
    end

    :ok
  end
end
