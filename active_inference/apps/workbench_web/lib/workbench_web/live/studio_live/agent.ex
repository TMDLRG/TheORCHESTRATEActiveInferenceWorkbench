defmodule WorkbenchWeb.StudioLive.Agent do
  @moduledoc """
  Studio S9 -- per-agent lifecycle panel.

  Shows the agent's state badge, source + spec + recipe provenance,
  and all legal transition buttons (Stop / Archive / Trash / Restore /
  Restart).  Also provides the "Open in Glass" link and a link to
  start a new run against this agent.
  """
  use WorkbenchWeb, :live_view

  alias AgentPlane.{Instance, Instances, Runtime}

  @impl true
  def mount(%{"agent_id" => agent_id}, _session, socket) do
    {:ok, assign_instance(socket, agent_id)}
  end

  defp assign_instance(socket, agent_id) do
    qwen_common = [
      qwen_page_type: :studio_agent,
      qwen_page_key: agent_id,
      qwen_page_title: "Agent · " <> agent_id
    ]

    case Instances.get(agent_id) do
      {:ok, %Instance{} = instance} ->
        assign(
          socket,
          [
            page_title: instance.name || agent_id,
            agent_id: agent_id,
            instance: instance,
            error: nil
          ] ++ qwen_common
        )

      :error ->
        assign(
          socket,
          [
            page_title: agent_id,
            agent_id: agent_id,
            instance: nil,
            error: "Agent not found in Studio registry."
          ] ++ qwen_common
        )
    end
  end

  @impl true
  def handle_event("stop", _, socket) do
    handle_lifecycle(socket, &Runtime.stop_tracked/1)
  end

  def handle_event("archive", _, socket) do
    handle_lifecycle(socket, &Runtime.archive/1)
  end

  def handle_event("trash", _, socket) do
    handle_lifecycle(socket, &Runtime.trash/1)
  end

  def handle_event("restore", _, socket) do
    handle_lifecycle(socket, &Runtime.restore/1)
  end

  def handle_event("restart", _, socket) do
    # Recompile the bundle via SpecCompiler against a default maze; keeps
    # agent_plane free of the workbench_web dep.  The actual world to run
    # against is chosen when the user attaches in Studio/New.
    with {:ok, %Instance{spec_id: spec_id}} <- Instances.get(socket.assigns.agent_id),
         {:ok, spec} <- WorldModels.AgentRegistry.fetch_spec(spec_id),
         {:ok, bundle, _opts} <-
           WorkbenchWeb.SpecCompiler.compile(
             spec,
             WorldPlane.Worlds.tiny_open_goal(),
             blanket: SharedContracts.Blanket.maze_default()
           ),
         {:ok, _instance, _pid} <-
           Runtime.restart_tracked(socket.assigns.agent_id, bundle: bundle) do
      {:noreply, assign_instance(socket, socket.assigns.agent_id)}
    else
      {:error, reason} -> {:noreply, assign(socket, error: humanise(reason))}
      :error -> {:noreply, assign(socket, error: "Spec not found; cannot restart.")}
      other -> {:noreply, assign(socket, error: "Unexpected: #{inspect(other)}")}
    end
  end

  defp handle_lifecycle(socket, fun) do
    case fun.(socket.assigns.agent_id) do
      {:ok, _instance} -> {:noreply, assign_instance(socket, socket.assigns.agent_id)}
      {:error, reason} -> {:noreply, assign(socket, error: humanise(reason))}
    end
  end

  defp humanise(:invalid_transition), do: "That transition is not legal from this state."
  defp humanise(:not_found), do: "Agent no longer tracked."
  defp humanise({:invalid_state, s}), do: "Agent is in state #{inspect(s)}."
  defp humanise(other), do: inspect(other)

  @impl true
  def render(%{instance: nil} = assigns) do
    ~H"""
    <p><.link navigate={~p"/studio"}>&larr; Studio</.link></p>
    <h1>Agent not found</h1>
    <p style="color:#fb7185;"><%= @error %></p>
    """
  end

  def render(assigns) do
    ~H"""
    <p><.link navigate={~p"/studio"}>&larr; Studio</.link></p>
    <h1><%= @instance.name || @agent_id %></h1>
    <p style="color:#9cb0d6;">
      <.state_badge state={@instance.state} />
      &middot; source: <code class="inline"><%= @instance.source %></code>
      &middot; spec: <code class="inline"><%= @instance.spec_id %></code>
      <%= if @instance.recipe_slug do %>
        &middot; recipe:
        <.link navigate={~p"/cookbook/#{@instance.recipe_slug}"}><%= @instance.recipe_slug %></.link>
      <% end %>
    </p>

    <%= if @error do %>
      <div class="card" style="border-color:#fb7185;">
        <p style="color:#fb7185;"><%= @error %></p>
      </div>
    <% end %>

    <div class="card">
      <h2>Lifecycle</h2>
      <p>
        <%= for action <- legal_actions(@instance.state) do %>
          <button phx-click={Atom.to_string(action)} class="btn">
            <%= action_label(action) %>
          </button>
        <% end %>
      </p>
    </div>

    <div class="card">
      <h2>Navigate</h2>
      <p>
        <.link navigate={~p"/studio/new?agent=#{@agent_id}"} class="btn">
          New run with this agent &rarr;
        </.link>
        <a href={"/glass/agent/" <> @agent_id} target="_blank" rel="noopener noreferrer" class="btn">
          Open in Glass &rarr;
        </a>
      </p>
    </div>

    <div class="card">
      <h2>Metadata</h2>
      <table>
        <tbody>
          <tr><th>agent_id</th><td><code class="inline"><%= @instance.agent_id %></code></td></tr>
          <tr><th>spec_id</th><td><code class="inline"><%= @instance.spec_id %></code></td></tr>
          <tr><th>source</th><td><%= @instance.source %></td></tr>
          <tr><th>state</th><td><%= @instance.state %></td></tr>
          <tr><th>name</th><td><%= @instance.name || "-" %></td></tr>
          <tr><th>pid</th><td><code class="inline"><%= inspect(@instance.pid) %></code></td></tr>
          <tr><th>started</th><td><%= format_ts(@instance.started_at_usec) %></td></tr>
          <tr><th>updated</th><td><%= format_ts(@instance.updated_at_usec) %></td></tr>
        </tbody>
      </table>
    </div>
    """
  end

  attr :state, :atom, required: true

  defp state_badge(assigns) do
    color =
      case assigns.state do
        :live -> "#5eead4"
        :stopped -> "#9cb0d6"
        :archived -> "#fde68a"
        :trashed -> "#fb7185"
      end

    assigns = assign(assigns, :color, color)

    ~H"""
    <span style={"display:inline-block;padding:2px 8px;border-radius:4px;background:rgba(0,0,0,0.2);color:#{@color};border:1px solid #{@color};font-size:11px;font-weight:600;"}>
      <%= @state %>
    </span>
    """
  end

  defp legal_actions(:live), do: [:stop, :archive, :trash]
  defp legal_actions(:stopped), do: [:restart, :archive, :trash]
  defp legal_actions(:archived), do: [:restore, :trash]
  defp legal_actions(:trashed), do: [:restore]

  defp action_label(:stop), do: "Stop"
  defp action_label(:archive), do: "Archive"
  defp action_label(:trash), do: "Trash"
  defp action_label(:restore), do: "Restore (→ stopped)"
  defp action_label(:restart), do: "Restart (→ live)"

  defp format_ts(nil), do: "-"
  defp format_ts(usec) do
    DateTime.from_unix!(div(usec, 1000), :millisecond) |> DateTime.to_string()
  end
end
