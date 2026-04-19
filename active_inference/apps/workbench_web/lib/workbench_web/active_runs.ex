defmodule WorkbenchWeb.ActiveRuns do
  @moduledoc """
  Live enumeration of running `WorkbenchWeb.Episode` sessions.

  Queries the `WorkbenchWeb.Episode.Registry` for every registered
  session and optionally asks each Episode for a terse summary
  (agent id, step count, terminal status).  Used by the "Running" chip
  in the global nav so the user can navigate anywhere and return to any
  in-progress run.

  Resilient: an Episode that crashes or disappears between the registry
  lookup and the `GenServer.call` is silently dropped from the result.
  """

  @registry WorkbenchWeb.Episode.Registry

  @type summary :: %{
          session_id: String.t(),
          agent_id: String.t() | nil,
          steps: non_neg_integer(),
          max_steps: non_neg_integer(),
          terminal?: boolean()
        }

  @doc "List every active episode's session_id."
  @spec session_ids() :: [String.t()]
  def session_ids do
    Registry.select(@registry, [{{:"$1", :"$2", :"$3"}, [], [:"$1"]}])
  end

  @doc "Count active episodes.  O(1)-ish over the ETS registry scan."
  @spec count() :: non_neg_integer()
  def count, do: Registry.count(@registry)

  @doc """
  List every active episode with a terse summary (agent_id, steps).
  Calls into each Episode with a short timeout so a slow one doesn't
  block the dashboard.  Dead entries are silently dropped.
  """
  @spec list() :: [summary()]
  def list do
    for session_id <- session_ids(), summary = safe_summary(session_id), not is_nil(summary) do
      summary
    end
    |> Enum.sort_by(& &1.session_id)
  end

  defp safe_summary(session_id) do
    try do
      # Short timeout so a compute-heavy planner doesn't lock the chip.
      s = GenServer.call(via(session_id), :inspect_state, 1_000)

      %{
        session_id: session_id,
        agent_id: get_in(s, [:agent, :agent_id]),
        steps: Map.get(s, :steps, 0),
        max_steps: Map.get(s, :max_steps, 0),
        terminal?: Map.get(s, :terminal?, false)
      }
    rescue
      _ -> nil
    catch
      :exit, _ -> nil
    end
  end

  defp via(session_id), do: {:via, Registry, {@registry, session_id}}
end
