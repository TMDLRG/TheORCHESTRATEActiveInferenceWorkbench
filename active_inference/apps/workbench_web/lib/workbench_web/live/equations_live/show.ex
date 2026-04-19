defmodule WorkbenchWeb.EquationsLive.Show do
  use WorkbenchWeb, :live_view

  alias ActiveInferenceCore.Equations

  @impl true
  def mount(%{"id" => id}, _session, socket) do
    case Equations.fetch(id) do
      nil ->
        {:ok, push_navigate(socket, to: ~p"/equations")}

      eq ->
        {:ok, assign(socket, page_title: eq.equation_number, eq: eq)}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <.link navigate={~p"/equations"}>← Back to registry</.link>
    <h1>Equation <%= @eq.equation_number %></h1>
    <p style="color:#9cb0d6;">
      <code class="inline"><%= @eq.chapter %></code> · <code class="inline"><%= @eq.section %></code>
    </p>
    <p>
      <.tag value={@eq.model_type} />
      <.tag value={@eq.verification_status} />
      <span class="tag general"><%= @eq.model_family %></span>
    </p>

    <div class="grid-2">
      <div class="card">
        <h3>Source form (verbatim)</h3>
        <pre><%= @eq.source_text_equation %></pre>
      </div>

      <div class="card">
        <h3>Normalized LaTeX</h3>
        <pre><%= @eq.normalized_latex %></pre>
      </div>
    </div>

    <div class="card">
      <h3>Symbols</h3>
      <%= if @eq.symbols == [] do %>
        <p style="color:#9cb0d6;">Symbols are defined inline in surrounding paragraphs — see Source.</p>
      <% else %>
        <table>
          <%= for s <- @eq.symbols do %>
            <tr><td class="mono" style="width:120px"><%= s.name %></td><td><%= s.meaning %></td></tr>
          <% end %>
        </table>
      <% end %>
    </div>

    <div class="grid-2">
      <div class="card">
        <h3>Conceptual role</h3>
        <p><%= @eq.conceptual_role %></p>
      </div>
      <div class="card">
        <h3>Implementation role</h3>
        <p><%= @eq.implementation_role %></p>
      </div>
    </div>

    <div class="card">
      <h3>Dependencies</h3>
      <%= if @eq.dependencies == [] do %>
        <p style="color:#9cb0d6;">None.</p>
      <% else %>
        <ul>
          <%= for d <- @eq.dependencies do %>
            <li><.link navigate={~p"/equations/#{d}"}><%= d %></.link></li>
          <% end %>
        </ul>
      <% end %>
    </div>

    <div class="card">
      <h3>Verification</h3>
      <p><.tag value={@eq.verification_status} /></p>
      <p><%= @eq.verification_notes %></p>
    </div>
    """
  end
end
