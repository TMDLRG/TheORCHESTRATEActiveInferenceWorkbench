defmodule WorkbenchWeb.GuideLive.Examples do
  @moduledoc """
  Catalogue of the five prebuilt examples — a maze-based Active Inference
  capability gradient.

  Each example is a saved `WorldModels.Spec` seeded into Mnesia at boot and
  deployable with one click.
  """
  use WorkbenchWeb, :live_view

  alias WorkbenchWeb.GuideLive.ExampleCatalog

  @impl true
  def mount(params, _session, socket) do
    slug = params["slug"]

    socket =
      socket
      |> assign(page_title: "Examples", slug: slug, examples: ExampleCatalog.all())

    {:ok, socket}
  end

  @impl true
  def render(%{slug: nil} = assigns) do
    ~H"""
    <h1>Five prebuilt Active Inference examples</h1>
    <p style="color:#9cb0d6;max-width:780px;">
      All five run inside the maze family of worlds — chosen to teach a progression
      of capabilities. Every block is a real JIDO action, skill, or agent; every
      signal is traced in Glass back to the book equation that produced it.
      <strong>No LLMs, no external AI.</strong>
    </p>

    <table>
      <thead>
        <tr>
          <th style="width:120px;">Level</th>
          <th>Name</th>
          <th>World</th>
          <th>Teaches</th>
          <th></th>
        </tr>
      </thead>
      <tbody>
        <%= for ex <- @examples do %>
          <tr>
            <td><span class="tag verified"><%= ex.level %></span></td>
            <td><strong><%= ex.name %></strong></td>
            <td><code class="inline"><%= ex.world %></code></td>
            <td><%= ex.teaches %></td>
            <td style="white-space: nowrap;">
              <.link navigate={~p"/guide/examples/#{ex.slug}"} class="btn">Walkthrough</.link>
              <%= if ex.spec_id do %>
                <.link
                  navigate={~p"/labs/run?spec_id=#{ex.spec_id}&world_id=#{ex.world}"}
                  class="btn primary">
                  Run it →
                </.link>
              <% end %>
            </td>
          </tr>
        <% end %>
      </tbody>
    </table>

    <div class="card">
      <h3>The gradient</h3>
      <ol>
        <li><strong>L1 Hello POMDP</strong> — the core Perceive→Plan→Act loop on a 1-step maze.</li>
        <li><strong>L2 Epistemic explorer</strong> — zero-pragmatic preference; agent seeks information.</li>
        <li><strong>L3 Sophisticated planner</strong> — deep-horizon policy search that can solve the deceptive dead-end the naïve planner cannot.</li>
        <li><strong>L4 Dirichlet learner</strong> — agent starts with wrong A/B priors and <em>learns its world model</em> online (eq 7.10).</li>
        <li><strong>L5 Hierarchical composition</strong> — a meta-agent sets the preference vector of a sub-agent; two Jido agents coordinate through the signal broker.</li>
      </ol>
    </div>
    """
  end

  def render(%{slug: _} = assigns) do
    assigns = assign(assigns, :example, ExampleCatalog.fetch(assigns.slug))

    ~H"""
    <p><.link navigate={~p"/guide/examples"}>← All examples</.link></p>
    <%= if @example do %>
      <h1><%= @example.level %> · <%= @example.name %></h1>
      <p style="color:#9cb0d6;"><%= @example.tagline %></p>

      <div class="grid-2">
        <div class="card">
          <h3>World</h3>
          <p><code class="inline"><%= @example.world %></code></p>
          <p><%= @example.world_note %></p>
        </div>

        <div class="card">
          <h3>Blocks used</h3>
          <ul>
            <%= for block <- @example.blocks do %>
              <li><code class="inline"><%= block %></code></li>
            <% end %>
          </ul>
        </div>
      </div>

      <div class="card">
        <h3>What it teaches</h3>
        <p><%= @example.teaches %></p>
        <%= if @example.equations != [] do %>
          <p><strong>Grounded in equations:</strong></p>
          <ul>
            <%= for eq <- @example.equations do %>
              <li><.link navigate={~p"/equations/#{eq}"}><code class="inline"><%= eq %></code></.link></li>
            <% end %>
          </ul>
        <% end %>
      </div>

      <div class="card">
        <h3>Run this agent</h3>
        <%= if @example.spec_id do %>
          <p>Pick a maze to run this spec against — the <code class="inline">SpecCompiler</code>
          will adapt the bundle to the world you choose:</p>
          <div style="display:flex;gap:8px;flex-wrap:wrap;">
            <%= for world_id <- ~w(tiny_open_goal corridor_turns forked_paths deceptive_dead_end hierarchical_maze) do %>
              <.link
                navigate={~p"/labs/run?spec_id=#{@example.spec_id}&world_id=#{world_id}"}
                class={"btn " <> if world_id == @example.world, do: "primary", else: ""}>
                <%= world_id %>
              </.link>
            <% end %>
          </div>
          <p style="margin-top: 10px;">
            Or inspect the composition in the Builder:
            <.link navigate={~p"/builder/#{@example.spec_id}"} class="btn">Open in Builder →</.link>
          </p>
        <% else %>
          <span class="tag uncertain">seeded spec coming online</span> —
          this example is wired in the runtime but its seed spec will
          land with the block library.
        <% end %>
      </div>
    <% else %>
      <h1>Unknown example</h1>
      <p>See <.link navigate={~p"/guide/examples"}>the catalogue</.link>.</p>
    <% end %>
    """
  end
end
