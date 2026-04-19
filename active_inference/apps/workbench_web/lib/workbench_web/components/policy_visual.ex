defmodule WorkbenchWeb.Components.PolicyVisual do
  @moduledoc """
  Expansion Phase L — shared policy posterior visual used by
  `/world`, `/run`, and `/labs/run`.

  Two views on the same posterior:

    * `.policy_bars/1` — a per-direction bar chart (↑/↓/→/←) showing
      aggregated probability mass over every policy whose first action
      is that direction. The winning direction is highlighted.

    * `.trajectory_overlay/1` — a maze-grid overlay that shows the top-π
      policy's predicted belief trajectory across the next H steps.

  Both components are stateless — they render from `summary.agent`
  (policy_posterior + policies + marginal_state_belief + best_policy_chain).
  """
  use Phoenix.Component

  attr :summary, :any, required: true

  def policy_bars(assigns) do
    summary = assigns.summary
    policies = get_in(summary, [:agent, :policies]) || []
    pi_post = get_in(summary, [:agent, :policy_posterior]) || []

    buckets =
      policies
      |> Enum.zip(pi_post)
      |> Enum.reduce(%{}, fn {policy, p}, acc ->
        first = List.first(policy) || :unknown
        Map.update(acc, first, p, &(&1 + p))
      end)

    rows =
      [:move_north, :move_south, :move_east, :move_west]
      |> Enum.map(fn a -> {a, Map.get(buckets, a, 0.0)} end)

    winner =
      case rows do
        [] -> nil
        _ -> Enum.max_by(rows, fn {_a, p} -> p end) |> elem(0)
      end

    assigns = assign(assigns, rows: rows, winner: winner)

    ~H"""
    <div class="policy-bars">
      <%= for {a, p} <- @rows do %>
        <div class={"policy-bar " <> if a == @winner, do: "winner", else: ""}>
          <div class="label"><%= direction_glyph(a) %>&nbsp;<%= a %></div>
          <div class="bar-container">
            <div class="bar-fill" style={"width: #{min(100, trunc(p * 100))}%;"}></div>
          </div>
          <div class="val"><%= fmt(p) %></div>
        </div>
      <% end %>
    </div>

    <style>
      .policy-bars { display: flex; flex-direction: column; gap: 6px; }
      .policy-bar { display: grid; grid-template-columns: 120px 1fr 60px; align-items: center; gap: 8px; font-size: 13px; }
      .policy-bar .label { color: #9cb0d6; }
      .policy-bar .bar-container { background: #0a1226; border: 1px solid #1e2a48; height: 16px; border-radius: 3px; }
      .policy-bar .bar-fill { background: #60a5fa; height: 100%; border-radius: 2px; transition: width 150ms ease-out; }
      .policy-bar.winner .bar-fill { background: #34d399; }
      .policy-bar .val { font-family: ui-monospace, Menlo, Consolas, monospace; color: #cbd5e1; }
    </style>
    """
  end

  attr :maze, :any, required: true
  attr :summary, :any, required: true

  @doc """
  Renders a planned-trajectory overlay on the maze grid. For each τ ≥ 1
  in the best policy's rollout, picks the argmax belief tile and places a
  stepping marker (1, 2, 3, …) there.

  Reads `summary.agent.best_policy_chain` when present (filled in by
  `Plan` / `SophisticatedPlan` after Phase L plumbing). Gracefully
  renders an empty overlay when the chain is missing.
  """
  def trajectory_overlay(assigns) do
    maze = assigns.maze
    actions = get_in(assigns.summary, [:agent, :best_policy_actions]) || []
    start_pos = get_in(assigns.summary, [:world, :pos])

    # Anchor the predicted trajectory at the **world's actual position**
    # and project the agent's chosen policy through the maze geometry.
    # Using ground-truth position means the arrows always line up with
    # the @ glyph the user sees, even when the agent's belief is
    # uncertain. This is the honest "what does the planner intend to
    # do next?" view — a UX choice, not an inference shortcut.
    markers =
      case start_pos do
        {_, _} = pos -> project_path(pos, actions, maze)
        _ -> []
      end

    assigns = assign(assigns, :markers, markers)

    ~H"""
    <%= if @markers != [] do %>
      <div class="traj-overlay">
        <p style="color:#9cb0d6;font-size:12px;margin:0 0 6px;">
          Predicted trajectory — the numbered tiles are where the top-π policy
          says the agent will be in the next steps, anchored at its current
          position (wall-bumps are shown in place).
        </p>
        <div class="maze-grid" style={"grid-template-columns: repeat(#{@maze.width}, 24px);"}>
          <%= for r <- 0..(@maze.height - 1), c <- 0..(@maze.width - 1) do %>
            <.traj_cell
              tile={Map.get(@maze.grid, {c, r}, :empty)}
              marker={marker_at(@markers, c, r)} />
          <% end %>
        </div>
      </div>
    <% end %>

    <style>
      .traj-overlay { margin-top: 8px; }
      .maze-cell.traj {
        color: #fff !important; font-size: 10px; font-weight: 600;
        background: #1d4ed8 !important;
      }
      .maze-cell.traj.revisit { background: #7c3aed !important; }
    </style>
    """
  end

  attr :tile, :atom, required: true
  attr :marker, :any, required: true

  # `marker` is `nil`, or `{leading_tau, revisit?}` — revisit when the
  # same tile is predicted to be visited more than once (e.g. because
  # the policy wall-bumps and "stays" for a step).
  defp traj_cell(assigns) do
    ~H"""
    <%= case @marker do %>
      <% nil -> %>
        <div class={"maze-cell " <> Atom.to_string(@tile)}></div>
      <% {tau, revisit?} -> %>
        <div class={"maze-cell " <> Atom.to_string(@tile) <> " traj" <> if revisit?, do: " revisit", else: ""}>
          <%= tau %>
        </div>
    <% end %>
    """
  end

  defp project_path({c0, r0}, actions, maze) do
    actions
    |> Enum.with_index(1)
    |> Enum.reduce({{c0, r0}, %{}}, fn {action, tau}, {{c, r}, markers} ->
      {nc, nr} = step_with_walls(c, r, action, maze)
      revisit? = Map.has_key?(markers, {nc, nr})
      marker = {tau, revisit?}
      {{nc, nr}, Map.put_new(markers, {nc, nr}, marker)}
    end)
    |> elem(1)
    |> Enum.map(fn {{c, r}, marker} -> {c, r, marker} end)
  end

  defp step_with_walls(c, r, action, maze) do
    {dc, dr} =
      case action do
        :move_north -> {0, -1}
        :move_south -> {0, 1}
        :move_east -> {1, 0}
        :move_west -> {-1, 0}
        _ -> {0, 0}
      end

    target = {c + dc, r + dr}
    tile = Map.get(maze.grid, target, :wall)

    cond do
      elem(target, 0) < 0 or elem(target, 1) < 0 -> {c, r}
      elem(target, 0) >= maze.width or elem(target, 1) >= maze.height -> {c, r}
      tile == :wall -> {c, r}
      true -> target
    end
  end

  defp marker_at(markers, c, r) do
    case Enum.find(markers, fn {mc, mr, _} -> mc == c and mr == r end) do
      nil -> nil
      {_, _, marker} -> marker
    end
  end

  defp direction_glyph(:move_north), do: "↑"
  defp direction_glyph(:move_south), do: "↓"
  defp direction_glyph(:move_east), do: "→"
  defp direction_glyph(:move_west), do: "←"
  defp direction_glyph(_), do: "·"

  defp fmt(x) when is_float(x), do: :erlang.float_to_binary(x, decimals: 3)
  defp fmt(x), do: to_string(x)
end
