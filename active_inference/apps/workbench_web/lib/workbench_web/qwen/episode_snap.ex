defmodule WorkbenchWeb.Qwen.EpisodeSnap do
  @moduledoc """
  Live snapshot of a running `WorkbenchWeb.Episode`, shaped for inclusion in
  the Qwen tutor's system prompt.

  Calls `:inspect_state` with a 500 ms timeout so a stuck planner never
  blocks the drawer, and prunes the policy posterior to top-3 so the packet
  stays small.

  `:inspect_state` is a pure `{:reply, summary, state}` handler — no side
  effects, safe at any frequency.
  """

  @timeout_ms 500
  @registry WorkbenchWeb.Episode.Registry

  @type snap :: %{
          session_id: String.t(),
          agent_id: String.t() | nil,
          steps: non_neg_integer(),
          max_steps: non_neg_integer(),
          terminal?: boolean(),
          last_action: atom() | nil,
          last_f: float() | nil,
          last_g: float() | nil,
          top_policies: [%{idx: non_neg_integer(), p: float()}],
          planned_actions: [atom()],
          goal_reached?: boolean()
        }

  @doc """
  Snapshot an episode by session_id. Returns `nil` if the episode is not
  running, has exited, or times out.
  """
  @spec from_session_id(String.t()) :: snap() | nil
  def from_session_id(session_id) when is_binary(session_id) do
    try do
      ref = {:via, Registry, {@registry, session_id}}
      state = GenServer.call(ref, :inspect_state, @timeout_ms)
      shape(session_id, state)
    rescue
      ArgumentError -> nil
      _ -> nil
    catch
      :exit, _ -> nil
    end
  end

  def from_session_id(_), do: nil

  # --- private -------------------------------------------------------------

  defp shape(session_id, state) when is_map(state) do
    agent = Map.get(state, :agent) || %{}

    %{
      session_id: session_id,
      agent_id: Map.get(agent, :agent_id),
      steps: Map.get(state, :steps, 0),
      max_steps: Map.get(state, :max_steps, 0),
      terminal?: Map.get(state, :terminal?, false),
      goal_reached?: Map.get(state, :goal_reached?, false) or Map.get(agent, :goal_reached?, false),
      last_action: last_action(agent),
      last_f: number_or_nil(Map.get(agent, :best_f)),
      last_g: number_or_nil(Map.get(agent, :best_g)),
      top_policies: top_policies(Map.get(agent, :policy_posterior)),
      planned_actions: planned_actions(agent)
    }
  end

  defp shape(_, _), do: nil

  defp last_action(agent) do
    case Map.get(agent, :last_action) do
      nil -> List.first(Map.get(agent, :best_policy_actions) || [])
      a -> a
    end
  end

  defp planned_actions(agent) do
    case Map.get(agent, :best_policy_actions) do
      nil -> []
      list when is_list(list) -> Enum.take(list, 5)
      _ -> []
    end
  end

  defp top_policies(nil), do: []

  defp top_policies(posterior) when is_list(posterior) do
    posterior
    |> Enum.with_index()
    |> Enum.map(fn {p, i} -> %{idx: i, p: to_float(p)} end)
    |> Enum.sort_by(& &1.p, :desc)
    |> Enum.take(3)
  end

  defp top_policies(tensor) when is_struct(tensor) do
    # Handle Nx.Tensor (and similar) without a compile-time dep.
    nx = Nx
    if Code.ensure_loaded?(nx) and function_exported?(nx, :to_flat_list, 1) do
      top_policies(apply(nx, :to_flat_list, [tensor]))
    else
      []
    end
  end

  defp top_policies(_), do: []

  defp to_float(n) when is_float(n), do: n
  defp to_float(n) when is_integer(n), do: n * 1.0
  defp to_float(_), do: 0.0

  defp number_or_nil(n) when is_number(n), do: n * 1.0
  defp number_or_nil(_), do: nil
end
