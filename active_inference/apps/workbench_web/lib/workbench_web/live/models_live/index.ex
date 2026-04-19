defmodule WorkbenchWeb.ModelsLive.Index do
  use WorkbenchWeb, :live_view

  alias ActiveInferenceCore.Models

  @impl true
  def mount(_params, _session, socket) do
    {:ok, assign(socket, page_title: "Models", models: Models.all())}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <h1>Model taxonomy</h1>
    <p style="color:#9cb0d6;">Model-family records. The POMDP row is what powers the maze MVP.</p>

    <%= for m <- @models do %>
      <div class="card">
        <h2><%= m.model_name %></h2>
        <p>
          <.tag value={m.type} />
          <.tag value={m.mvp_suitability} />
        </p>
        <div class="grid-2">
          <div>
            <h3>Variables</h3>
            <ul><%= for v <- m.variables do %><li class="mono"><%= v %></li><% end %></ul>
            <h3>Priors</h3>
            <ul><%= for p <- m.priors do %><li class="mono"><%= p %></li><% end %></ul>
          </div>
          <div>
            <h3>Likelihood</h3>
            <p class="mono"><%= m.likelihood_structure %></p>
            <h3>Transition</h3>
            <p class="mono"><%= m.transition_structure %></p>
            <h3>Inference update</h3>
            <p class="mono"><%= m.inference_update_rule %></p>
            <h3>Planning</h3>
            <p class="mono"><%= m.planning_mechanism %></p>
          </div>
        </div>
        <h3>Grounded in</h3>
        <p>
          <%= for id <- m.source_basis do %>
            <.link navigate={~p"/equations/#{id}"}><code class="inline"><%= id %></code></.link>
          <% end %>
        </p>
        <h3>Future extensibility</h3>
        <p><%= m.future_extensibility %></p>
      </div>
    <% end %>
    """
  end
end
