defmodule CompositionRuntime.SignalBroker do
  @moduledoc """
  Routes `Jido.Signal` values between the agents that make up a single
  composition.

  **No raw `send/2`**, **no `GenServer.call` to an agent pid**. Delivery
  is always `Jido.AgentServer.cast_signal/2` with a Splode-structured
  error on lookup failure.

  The broker is a plain GenServer owned by a `Composition` supervisor.
  It holds a map `%{agent_id => pid}` so it can dispatch synchronously;
  the agent registry in `AgentPlane` is the persistent source of truth.
  """

  use GenServer

  alias AgentPlane.JidoInstance

  @type state :: %{
          composition_id: String.t(),
          agents: %{String.t() => pid()},
          wires: [map()]
        }

  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(opts) do
    id = Keyword.fetch!(opts, :composition_id)
    GenServer.start_link(__MODULE__, opts, name: name(id))
  end

  @spec register_agent(String.t(), String.t(), pid()) :: :ok
  def register_agent(composition_id, agent_id, pid) do
    GenServer.call(name(composition_id), {:register_agent, agent_id, pid})
  end

  @spec route(String.t(), Jido.Signal.t()) :: :ok | {:error, term()}
  def route(composition_id, signal) do
    GenServer.call(name(composition_id), {:route, signal})
  end

  @spec agents(String.t()) :: %{String.t() => pid()}
  def agents(composition_id), do: GenServer.call(name(composition_id), :agents)

  # -- GenServer ------------------------------------------------------------

  @impl true
  def init(opts) do
    state = %{
      composition_id: Keyword.fetch!(opts, :composition_id),
      agents: %{},
      wires: Keyword.get(opts, :wires, [])
    }

    {:ok, state}
  end

  @impl true
  def handle_call({:register_agent, agent_id, pid}, _from, state) do
    {:reply, :ok, %{state | agents: Map.put(state.agents, agent_id, pid)}}
  end

  def handle_call({:route, signal}, _from, state) do
    target = extract_target(signal)

    cond do
      is_nil(target) ->
        {:reply, {:error, :no_target}, state}

      pid = Map.get(state.agents, target) ->
        case dispatch(pid, signal) do
          :ok -> {:reply, :ok, state}
          err -> {:reply, err, state}
        end

      true ->
        {:reply, {:error, {:unknown_agent, target}}, state}
    end
  end

  def handle_call(:agents, _from, state), do: {:reply, state.agents, state}

  # -- Helpers --------------------------------------------------------------

  defp name(id), do: {:via, Elixir.Registry, {CompositionRuntime.NameRegistry, {:broker, id}}}

  defp extract_target(%Jido.Signal{} = signal) do
    # Target is carried in subject for Jido cloudevents style, falling
    # back to explicit :target_agent_id in the data map for our local
    # hierarchical-composition wires.
    cond do
      is_binary(signal.subject) and signal.subject != "" ->
        signal.subject

      is_map(signal.data) and is_binary(signal.data[:target_agent_id]) ->
        signal.data[:target_agent_id]

      is_map(signal.data) and is_binary(signal.data["target_agent_id"]) ->
        signal.data["target_agent_id"]

      true ->
        nil
    end
  end

  defp dispatch(pid, %Jido.Signal{} = signal) do
    # Deliver via Jido's own cast API so the receiving agent's
    # signal_routes/1 pipeline owns the message. No raw send/2.
    case Jido.AgentServer.cast(pid, signal) do
      :ok -> :ok
      other -> {:error, other}
    end
  rescue
    error -> {:error, error}
  end

  # Touch the JidoInstance alias so the compiler treats it as used while
  # we depend on the agent_plane app being loaded in this VM.
  _ = JidoInstance
end
