defmodule WorldModels.EventLog.Setup do
  @moduledoc """
  Plan §8.5 — boots Mnesia with the schema + `world_models_events` table.

  Safe to call many times; idempotent. Called from
  `WorkbenchWeb.Application.start/2` in dev/prod; tests call it explicitly
  after `WorldModels.MnesiaCase` provides an isolated dir.
  """

  require Logger

  @table :world_models_events
  # Record layout: {table, key, agent_id, type, spec_id, world_run_id, event}
  # Primary key = {ts_usec, id} (ordered_set for monotonic scan).
  @attributes [:key, :agent_id, :type, :spec_id, :world_run_id, :event]

  # Plan §12 Phase 5 — Spec persistence + live-agent directory.
  @specs_table :world_models_specs
  # Record layout: {table, id, archetype_id, family_id, hash, spec_struct}
  @specs_attributes [:id, :archetype_id, :family_id, :hash, :spec]

  @live_agents_table :world_models_live_agents
  # Record layout: {table, agent_id, spec_id, pid, started_at_usec}
  # ram_copies only — live-agent mapping is process-bound, not persisted.
  @live_agents_attributes [:agent_id, :spec_id, :pid, :started_at_usec]

  # Studio S2 -- durable agent-lifecycle directory for the /studio subsystem.
  # Record layout: {table, agent_id, spec_id, source, recipe_slug, pid,
  #                 state, name, started_at_usec, updated_at_usec}
  # disc_copies -- state survives Phoenix restart.  `AgentPlane.Instances`
  # reconciles against live pids on boot and demotes orphaned :live rows
  # to :stopped.  Indexed by state + spec_id for dashboard filters.
  @instances_table :agent_plane_instances
  @instances_attributes [
    :agent_id,
    :spec_id,
    :source,
    :recipe_slug,
    :pid,
    :state,
    :name,
    :started_at_usec,
    :updated_at_usec
  ]

  @spec instances_table() :: atom()
  def instances_table, do: @instances_table

  @spec table() :: atom()
  def table, do: @table

  @spec attributes() :: [atom()]
  def attributes, do: @attributes

  @spec specs_table() :: atom()
  def specs_table, do: @specs_table

  @spec live_agents_table() :: atom()
  def live_agents_table, do: @live_agents_table

  @spec ensure_schema!() :: :ok
  def ensure_schema! do
    # Mnesia does not create the parent dir for its schema files; do it
    # ourselves based on the configured :mnesia, :dir env.
    case Application.get_env(:mnesia, :dir) do
      nil ->
        :ok

      dir when is_list(dir) ->
        File.mkdir_p!(List.to_string(dir))

      dir when is_binary(dir) ->
        File.mkdir_p!(dir)
    end

    # Mnesia may have been auto-started by a transitive dep with a RAM-only
    # schema on the current node; `create_schema/1` is a silent no-op in
    # that case, which then rejects `disc_copies` tables with `:bad_type`.
    # Stop it first so we can create a disc-backed schema from scratch.
    _ = :mnesia.stop()

    case :mnesia.create_schema([node()]) do
      :ok ->
        :ok

      {:error, {_, {:already_exists, _}}} ->
        :ok

      {:error, reason} ->
        if already_exists?(reason) do
          :ok
        else
          raise "Mnesia schema create failed: #{inspect(reason)}"
        end
    end

    :ok = :mnesia.start()

    create_table!(@table,
      attributes: @attributes,
      disc_copies: [node()],
      type: :ordered_set,
      index: [:agent_id, :type]
    )

    # Specs: disc-durable, indexed by archetype + family + hash so the
    # Builder list view + Glass Engine back-traces are O(1) lookups.
    create_table!(@specs_table,
      attributes: @specs_attributes,
      disc_copies: [node()],
      type: :set,
      index: [:archetype_id, :family_id, :hash]
    )

    # Live agents: ephemeral, RAM-only, indexed by spec_id for
    # `live_for_spec/1`.
    create_table!(@live_agents_table,
      attributes: @live_agents_attributes,
      ram_copies: [node()],
      type: :set,
      index: [:spec_id]
    )

    # Studio S2 -- durable agent-lifecycle instances.
    create_table!(@instances_table,
      attributes: @instances_attributes,
      disc_copies: [node()],
      type: :set,
      index: [:state, :spec_id]
    )

    :ok =
      :mnesia.wait_for_tables(
        [@table, @specs_table, @live_agents_table, @instances_table],
        5_000
      )

    :ok
  end

  defp create_table!(name, opts) do
    case :mnesia.create_table(name, opts) do
      {:atomic, :ok} -> :ok
      {:aborted, {:already_exists, ^name}} -> :ok
      {:aborted, other} -> raise "Mnesia table create failed (#{name}): #{inspect(other)}"
    end
  end

  defp already_exists?(reason) do
    reason
    |> :erlang.term_to_binary()
    |> :binary.match("already_exists")
    |> case do
      :nomatch -> false
      _ -> true
    end
  end

  # Supervision-tree child spec — exits after running ensure_schema!/0 so
  # later children can start knowing Mnesia is up.
  def child_spec(_opts) do
    %{
      id: __MODULE__,
      start: {Task, :start_link, [&__MODULE__.ensure_schema!/0]},
      restart: :transient,
      type: :worker
    }
  end
end
