defmodule CompositionRuntime do
  @moduledoc """
  Lego-uplift Phase E — host multi-agent compositions on pure Jido.

  A composition is N Jido agents + M world engines + one `SignalBroker`
  that routes `Jido.Signal` values between the agents. Agents never talk
  via raw `send/2`; every cross-agent message is a `Jido.Signal` with a
  `:target_agent_id` metadata key that the broker uses to look up the
  destination pid from the live-agent directory.

  The public surface is deliberately thin: `deploy/1` takes a
  composition-spec map and returns `{:ok, composition_id}`. The returned
  id is the primary key in `CompositionRuntime.Registry`.
  """

  alias CompositionRuntime.{Composition, Registry, SignalBroker}

  @type agent_spec :: %{
          required(:agent_id) => String.t(),
          required(:role) => :meta | :sub | :single,
          required(:bundle) => map(),
          required(:blanket) => SharedContracts.Blanket.t(),
          optional(:spec_id) => String.t() | nil
        }

  @type wire :: %{
          required(:from_agent_id) => String.t(),
          required(:to_agent_id) => String.t(),
          required(:signal_type) => String.t(),
          optional(:transform) => (map() -> map())
        }

  @type composition :: %{
          required(:composition_id) => String.t(),
          required(:agents) => [agent_spec()],
          required(:wires) => [wire()]
        }

  @spec deploy(composition()) :: {:ok, String.t()} | {:error, term()}
  def deploy(%{composition_id: id, agents: agents, wires: wires}) do
    # Start a dedicated supervisor + broker for this composition so a
    # crash in one composition doesn't take down others.
    case DynamicSupervisor.start_child(
           CompositionRuntime.RootSupervisor,
           {Composition, %{composition_id: id, agents: agents, wires: wires}}
         ) do
      {:ok, _pid} ->
        Registry.put(id, agents, wires)
        {:ok, id}

      {:error, {:already_started, _}} ->
        {:ok, id}

      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Forward a Jido.Signal to its `:target_agent_id` destination.

  Called from an agent's `on_emit/2` callback or from the broker itself
  when it picks up signals off the shared bus. No raw `send/2`.
  """
  @spec route(String.t(), Jido.Signal.t()) :: :ok | {:error, term()}
  def route(composition_id, signal) do
    SignalBroker.route(composition_id, signal)
  end

  @doc "List deployed compositions."
  @spec list() :: [%{composition_id: String.t(), agents: [agent_spec()], wires: [wire()]}]
  def list, do: Registry.list()

  @doc "Look up a composition by id."
  @spec fetch(String.t()) ::
          {:ok, %{composition_id: String.t(), agents: [agent_spec()], wires: [wire()]}} | :error
  def fetch(id), do: Registry.fetch(id)
end
