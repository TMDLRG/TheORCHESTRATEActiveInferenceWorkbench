defmodule WorldModels.AgentRegistry do
  @moduledoc """
  Plan §10.7 — the hinge between Builder (specs) and Runtime (live agents).

  Specs live in the Mnesia `world_models_specs` table (disc-durable); the
  live-agent directory lives in `world_models_live_agents` (ram-only).

  Glass Engine consumes both:
  - signal → spec_id → `fetch_spec/1` → verbatim composition
  - spec_id → `live_for_spec/1` → every running agent instantiated from it
  """

  alias WorldModels.EventLog.Setup
  alias WorldModels.Spec

  @specs Setup.specs_table()
  @live Setup.live_agents_table()

  # -- Spec persistence -----------------------------------------------------

  @spec register_spec(Spec.t()) :: {:ok, Spec.t()} | {:error, term()}
  def register_spec(%Spec{id: id} = spec) when is_binary(id) do
    spec = ensure_hash(spec)
    record = {@specs, spec.id, spec.archetype_id, spec.family_id, spec.hash, spec}

    case :mnesia.sync_transaction(fn -> :mnesia.write(record) end) do
      {:atomic, :ok} -> {:ok, spec}
      {:aborted, reason} -> {:error, reason}
    end
  end

  @spec fetch_spec(String.t()) :: {:ok, Spec.t()} | :error
  def fetch_spec(id) when is_binary(id) do
    case :mnesia.dirty_read(@specs, id) do
      [{@specs, ^id, _archetype, _family, _hash, %Spec{} = spec}] -> {:ok, spec}
      _ -> :error
    end
  end

  @spec list_specs() :: [Spec.t()]
  def list_specs do
    :mnesia.dirty_select(@specs, [{{@specs, :_, :_, :_, :_, :"$1"}, [], [:"$1"]}])
  end

  @spec delete_spec(String.t()) :: :ok | {:error, {:live_agents, [String.t()]}} | {:error, term()}
  def delete_spec(id) when is_binary(id) do
    case live_for_spec(id) do
      [] ->
        case :mnesia.sync_transaction(fn -> :mnesia.delete({@specs, id}) end) do
          {:atomic, :ok} -> :ok
          {:aborted, reason} -> {:error, reason}
        end

      live ->
        {:error, {:live_agents, live}}
    end
  end

  # -- Live-agent directory -------------------------------------------------

  @spec attach_live(String.t(), String.t()) :: :ok | {:error, :unknown_spec}
  def attach_live(agent_id, spec_id) when is_binary(agent_id) and is_binary(spec_id) do
    case fetch_spec(spec_id) do
      :error ->
        {:error, :unknown_spec}

      {:ok, _} ->
        pid = self()
        started = System.system_time(:microsecond)
        record = {@live, agent_id, spec_id, pid, started}
        :mnesia.dirty_write(record)
        :ok
    end
  end

  @spec detach_live(String.t()) :: :ok
  def detach_live(agent_id) when is_binary(agent_id) do
    :mnesia.dirty_delete(@live, agent_id)
    :ok
  end

  @spec live_for_spec(String.t()) :: [String.t()]
  def live_for_spec(spec_id) when is_binary(spec_id) do
    :mnesia.dirty_index_read(@live, spec_id, :spec_id)
    |> Enum.map(fn {@live, agent_id, _spec_id, _pid, _started} -> agent_id end)
  end

  @spec list_live_agents() :: [{String.t(), String.t()}]
  def list_live_agents do
    :mnesia.dirty_select(@live, [
      {{@live, :"$1", :"$2", :_, :_}, [], [{{:"$1", :"$2"}}]}
    ])
  end

  @spec fetch_live(String.t()) ::
          {:ok,
           %{agent_id: String.t(), spec_id: String.t(), pid: pid(), started_at_usec: integer()}}
          | :error
  def fetch_live(agent_id) when is_binary(agent_id) do
    case :mnesia.dirty_read(@live, agent_id) do
      [{@live, ^agent_id, spec_id, pid, started}] ->
        {:ok, %{agent_id: agent_id, spec_id: spec_id, pid: pid, started_at_usec: started}}

      _ ->
        :error
    end
  end

  # -- Helpers --------------------------------------------------------------

  defp ensure_hash(%Spec{hash: h} = s) when is_binary(h) and byte_size(h) > 0, do: s
  defp ensure_hash(%Spec{} = s), do: %{s | hash: Spec.provenance_hash(s)}
end
