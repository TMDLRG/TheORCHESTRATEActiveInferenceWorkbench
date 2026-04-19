defmodule WorkbenchWeb.CoreComponents do
  @moduledoc """
  Reusable HEEx components for the workbench. Deliberately tiny — just enough
  to render tags, formulas, and probability bars without pulling in tailwind
  or heex_additional.
  """

  use Phoenix.Component

  attr :value, :any, required: true

  def tag(%{value: v} = assigns) do
    assigns = assign(assigns, :class, class_for(v))

    ~H"""
    <span class={"tag " <> @class}><%= to_label(@value) %></span>
    """
  end

  defp class_for(:discrete), do: "discrete"
  defp class_for(:continuous), do: "continuous"
  defp class_for(:hybrid), do: "hybrid"
  defp class_for(:general), do: "general"
  defp class_for(:verified_against_source_and_appendix), do: "verified"
  defp class_for(:verified_against_source), do: "verified"
  defp class_for(:extracted_uncertain), do: "uncertain"
  defp class_for(_), do: "general"

  defp to_label(:verified_against_source_and_appendix), do: "verified (ch+app)"
  defp to_label(:verified_against_source), do: "verified"
  defp to_label(:extracted_uncertain), do: "uncertain"
  defp to_label(v) when is_atom(v), do: Atom.to_string(v)
  defp to_label(v), do: to_string(v)

  attr :probs, :list, required: true
  attr :labels, :list, default: nil
  attr :width, :integer, default: 300

  def prob_bars(assigns) do
    assigns =
      assigns
      |> assign_new(:labels, fn ->
        Enum.map(1..length(assigns.probs), fn i -> "#{i - 1}" end)
      end)

    ~H"""
    <div>
      <%= for {p, label} <- Enum.zip(@probs, @labels) do %>
        <div style="margin: 2px 0; display: flex; align-items: center; gap: 6px;">
          <span class="mono" style="width: 80px; font-size: 11px; color: #9cb0d6;"><%= label %></span>
          <span class="bar" style={"width: #{trunc(@width * p)}px"}></span>
          <span class="mono" style="font-size: 11px; color: #cbd5e1;"><%= fmt(p) %></span>
        </div>
      <% end %>
    </div>
    """
  end

  attr :latex, :string, required: true
  attr :caption, :string, default: nil

  def formula(assigns) do
    ~H"""
    <div class="card">
      <%= if @caption do %>
        <div style="font-size: 12px; color: #9cb0d6; margin-bottom: 6px;"><%= @caption %></div>
      <% end %>
      <pre style="white-space: pre-wrap; font-family: ui-monospace, Menlo, Consolas, monospace;"><%= @latex %></pre>
    </div>
    """
  end

  defp fmt(x) when is_float(x), do: :erlang.float_to_binary(x, decimals: 3)
  defp fmt(x), do: inspect(x)
end
