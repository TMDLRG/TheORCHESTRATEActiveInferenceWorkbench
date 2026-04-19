defmodule WorkbenchWeb.Components.LevelBadge do
  @moduledoc """
  Reusable AI-UMM level badge.  E1 (plan).

  Maps a level (1..5) to its persona name from LEVEL UP (Polzin).  Reused
  on `/learn`, `/guide/labs`, `/labs` pick lists, and `/cookbook/:slug`.

  Usage:

      <.level_badge level={3} />
      <.level_badge level={5} compact />
  """
  use Phoenix.Component

  attr :level, :integer, required: true, doc: "AI-UMM level 1..5"
  attr :compact, :boolean, default: false, doc: "show number only (no label)"

  def level_badge(assigns) do
    assigns = assign(assigns, :label, label_for(assigns.level))

    ~H"""
    <span class="level-badge" title={"AI-UMM level " <> Integer.to_string(@level) <> " — " <> @label}
          style={"display:inline-block;padding:2px 8px;border-radius:4px;" <>
                 "background:#1a1612;color:#d8b56c;border:1px solid #b3863a;" <>
                 "font-size:11px;font-weight:600;letter-spacing:0.3px;"}>
      L<%= @level %><%= if not @compact, do: " · " <> @label %>
    </span>
    """
  end

  @doc "Return the persona label for a level."
  @spec label_for(integer()) :: String.t()
  def label_for(1), do: "Skeptical Supervisor"
  def label_for(2), do: "Quality Controller"
  def label_for(3), do: "Team Lead"
  def label_for(4), do: "Strategic Director"
  def label_for(5), do: "Amplified Human"
  def label_for(0), do: "Curious Dabbler"
  def label_for(_), do: "Unknown"
end
