defmodule CompositionRuntime.Registry do
  @moduledoc """
  In-memory directory of deployed compositions.

  Kept as a plain GenServer (not Elixir's built-in Registry) so we can
  store the list of agents + wires per composition for introspection
  from the Glass Engine and the Builder.
  """

  use GenServer

  @spec start_link(any()) :: GenServer.on_start()
  def start_link(_opts), do: GenServer.start_link(__MODULE__, %{}, name: __MODULE__)

  @spec put(String.t(), [map()], [map()]) :: :ok
  def put(id, agents, wires), do: GenServer.call(__MODULE__, {:put, id, agents, wires})

  @spec delete(String.t()) :: :ok
  def delete(id), do: GenServer.call(__MODULE__, {:delete, id})

  @spec fetch(String.t()) ::
          {:ok, %{composition_id: String.t(), agents: [map()], wires: [map()]}} | :error
  def fetch(id), do: GenServer.call(__MODULE__, {:fetch, id})

  @spec list() :: [%{composition_id: String.t(), agents: [map()], wires: [map()]}]
  def list, do: GenServer.call(__MODULE__, :list)

  # -- GenServer ------------------------------------------------------------

  @impl true
  def init(state), do: {:ok, state}

  @impl true
  def handle_call({:put, id, agents, wires}, _from, state) do
    entry = %{composition_id: id, agents: agents, wires: wires}
    {:reply, :ok, Map.put(state, id, entry)}
  end

  def handle_call({:delete, id}, _from, state), do: {:reply, :ok, Map.delete(state, id)}

  def handle_call({:fetch, id}, _from, state) do
    case Map.fetch(state, id) do
      {:ok, entry} -> {:reply, {:ok, entry}, state}
      :error -> {:reply, :error, state}
    end
  end

  def handle_call(:list, _from, state), do: {:reply, Map.values(state), state}
end
