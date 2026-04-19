defmodule WorldModels.Bus do
  @moduledoc """
  Plan §8.1 — single versioned topic family over `Phoenix.PubSub` named
  `WorldModels.Bus`.

      events:global                          all events
      events:agent:<agent_id>                per-agent stream
      events:world:<world_run_id>            per-world episode
      events:spec:<spec_id>                  per-spec audit

  Messages arrive as `{:world_event, %WorldModels.Event{}}`.

  Publishing is non-blocking; EventLog persistence happens separately (see
  §8.5). Both fan out from `EventLog.append/1`.
  """

  alias WorldModels.Event

  @pubsub WorldModels.Bus

  @doc "Subscribe to the global firehose."
  @spec subscribe_global() :: :ok | {:error, term()}
  def subscribe_global, do: Phoenix.PubSub.subscribe(@pubsub, "events:global")

  @doc "Subscribe to events for one agent."
  @spec subscribe_agent(String.t()) :: :ok | {:error, term()}
  def subscribe_agent(agent_id) when is_binary(agent_id),
    do: Phoenix.PubSub.subscribe(@pubsub, "events:agent:" <> agent_id)

  @doc "Subscribe to events for one world run."
  @spec subscribe_world(String.t()) :: :ok | {:error, term()}
  def subscribe_world(world_run_id) when is_binary(world_run_id),
    do: Phoenix.PubSub.subscribe(@pubsub, "events:world:" <> world_run_id)

  @doc "Subscribe to events for one spec."
  @spec subscribe_spec(String.t()) :: :ok | {:error, term()}
  def subscribe_spec(spec_id) when is_binary(spec_id),
    do: Phoenix.PubSub.subscribe(@pubsub, "events:spec:" <> spec_id)

  @doc "Fan out an event to every relevant topic."
  @spec broadcast(Event.t()) :: :ok
  def broadcast(%Event{provenance: p} = event) do
    msg = {:world_event, event}

    :ok = Phoenix.PubSub.broadcast(@pubsub, "events:global", msg)

    if aid = Map.get(p, :agent_id),
      do: Phoenix.PubSub.broadcast(@pubsub, "events:agent:" <> aid, msg)

    if wid = Map.get(p, :world_run_id),
      do: Phoenix.PubSub.broadcast(@pubsub, "events:world:" <> wid, msg)

    if sid = Map.get(p, :spec_id),
      do: Phoenix.PubSub.broadcast(@pubsub, "events:spec:" <> sid, msg)

    :ok
  end

  @doc "True if the named Phoenix.PubSub is running (lets Episode no-op gracefully)."
  @spec running?() :: boolean()
  def running? do
    Process.whereis(@pubsub) != nil
  end
end
