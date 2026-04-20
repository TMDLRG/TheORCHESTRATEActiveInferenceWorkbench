defmodule WorkbenchWeb.EquationsLive.Index do
  use WorkbenchWeb, :live_view

  alias ActiveInferenceCore.Equations

  @impl true
  def mount(_params, _session, socket) do
    equations = Equations.all()

    {:ok,
     socket
     |> assign(
       page_title: "Equations",
       equations: equations,
       filter_type: :all,
       filter_family: nil,
       families: equations |> Enum.map(& &1.model_family) |> Enum.uniq() |> Enum.sort(),
       qwen_page_type: :equations_index,
       qwen_page_key: nil,
       qwen_page_title: "Equation registry"
     )}
  end

  @impl true
  def handle_event("filter", %{"type" => type}, socket) do
    {:noreply, assign(socket, filter_type: String.to_existing_atom(type))}
  end

  def handle_event("filter_family", %{"family" => ""}, socket),
    do: {:noreply, assign(socket, filter_family: nil)}

  def handle_event("filter_family", %{"family" => family}, socket),
    do: {:noreply, assign(socket, filter_family: family)}

  @impl true
  def render(assigns) do
    assigns =
      assign(
        assigns,
        :visible,
        filter(assigns.equations, assigns.filter_type, assigns.filter_family)
      )

    ~H"""
    <h1>Equation registry</h1>
    <p style="color:#9cb0d6;">Every record preserves the verbatim source equation alongside normalized LaTeX, symbols, verification status, and an implementation role.</p>

    <div class="card">
      <label>Filter by model type</label>
      <form phx-change="filter">
        <select name="type">
          <option value="all" selected={@filter_type == :all}>All</option>
          <option value="discrete" selected={@filter_type == :discrete}>Discrete-time</option>
          <option value="continuous" selected={@filter_type == :continuous}>Continuous-time</option>
          <option value="hybrid" selected={@filter_type == :hybrid}>Hybrid</option>
          <option value="general" selected={@filter_type == :general}>General / foundational</option>
        </select>
      </form>

      <label style="margin-top: 10px;">Filter by model family</label>
      <form phx-change="filter_family">
        <select name="family">
          <option value="">All families</option>
          <%= for f <- @families do %>
            <option value={f} selected={@filter_family == f}><%= f %></option>
          <% end %>
        </select>
      </form>
    </div>

    <table>
      <thead>
        <tr>
          <th>Eq. #</th>
          <th>Family</th>
          <th>Type</th>
          <th>Role</th>
          <th>Verification</th>
          <th>Inspect</th>
        </tr>
      </thead>
      <tbody>
        <%= for eq <- @visible do %>
          <tr>
            <td class="mono"><%= eq.equation_number %></td>
            <td><%= eq.model_family %></td>
            <td><.tag value={eq.model_type} /></td>
            <td style="max-width: 360px;"><%= eq.conceptual_role %></td>
            <td><.tag value={eq.verification_status} /></td>
            <td><.link navigate={~p"/equations/#{eq.id}"}>open →</.link></td>
          </tr>
        <% end %>
      </tbody>
    </table>
    """
  end

  defp filter(equations, :all, nil), do: equations
  defp filter(equations, :all, family), do: Enum.filter(equations, &(&1.model_family == family))
  defp filter(equations, type, nil), do: Enum.filter(equations, &(&1.model_type == type))

  defp filter(equations, type, family),
    do: Enum.filter(equations, &(&1.model_type == type and &1.model_family == family))
end
