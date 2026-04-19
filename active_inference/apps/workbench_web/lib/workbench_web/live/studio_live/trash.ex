defmodule WorkbenchWeb.StudioLive.Trash do
  @moduledoc """
  Studio S10 -- trashed-agent list with Restore, Permanent delete, and
  Empty trash.  Confirm-guarded: every destructive action writes a
  `:pending_confirm` flag on the socket and the button label changes
  to "Confirm delete" -- a second click completes the transaction.
  """
  use WorkbenchWeb, :live_view

  alias AgentPlane.{Instance, Instances, Runtime}

  @impl true
  def mount(_params, _session, socket) do
    {:ok, assign_list(socket)}
  end

  defp assign_list(socket) do
    assign(socket,
      page_title: "Trash",
      trashed: Instances.list(states: [:trashed]),
      pending_confirm: nil,
      flash_msg: nil
    )
  end

  @impl true
  def handle_event("restore", %{"agent_id" => id}, socket) do
    case Runtime.restore(id) do
      {:ok, _} -> {:noreply, assign_list(socket) |> put_flash(:info, "Restored #{id} to :stopped.")}
      {:error, reason} -> {:noreply, put_flash(socket, :error, inspect(reason))}
    end
  end

  def handle_event("confirm_delete", %{"agent_id" => id}, socket) do
    {:noreply, assign(socket, pending_confirm: {:delete, id})}
  end

  def handle_event("delete", %{"agent_id" => id}, socket) do
    case socket.assigns.pending_confirm do
      {:delete, ^id} ->
        case Instances.purge(id) do
          :ok -> {:noreply, assign_list(socket) |> put_flash(:info, "Permanently deleted #{id}.")}
          {:error, reason} -> {:noreply, put_flash(socket, :error, inspect(reason))}
        end

      _ ->
        {:noreply, assign(socket, pending_confirm: {:delete, id})}
    end
  end

  def handle_event("cancel_confirm", _, socket) do
    {:noreply, assign(socket, pending_confirm: nil)}
  end

  def handle_event("confirm_empty", _, socket) do
    {:noreply, assign(socket, pending_confirm: :empty)}
  end

  def handle_event("empty_trash", _, socket) do
    case socket.assigns.pending_confirm do
      :empty ->
        {:ok, ids} = Instances.empty_trash()

        {:noreply,
         assign_list(socket)
         |> put_flash(:info, "Permanently deleted #{length(ids)} agent(s) from trash.")}

      _ ->
        {:noreply, assign(socket, pending_confirm: :empty)}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <p><.link navigate={~p"/studio"}>&larr; Studio</.link></p>
    <h1>Trash</h1>
    <p style="color:#9cb0d6;max-width:900px;">
      Trashed agents are soft-deleted -- their process is stopped and the row
      is hidden from the dashboard, but the metadata is retained until the trash
      is emptied.  Restore moves the agent back to <code class="inline">:stopped</code>,
      and permanent delete removes the row from Mnesia.
    </p>

    <%= if @flash_msg do %>
      <div class="card"><p><%= @flash_msg %></p></div>
    <% end %>

    <div class="card">
      <h2>Trashed agents (<%= length(@trashed) %>)</h2>
      <%= if @trashed == [] do %>
        <p style="color:#556478;">Trash is empty.</p>
      <% else %>
        <table>
          <thead>
            <tr>
              <th>Name</th>
              <th>Spec</th>
              <th>Source</th>
              <th style="min-width:360px;">Actions</th>
            </tr>
          </thead>
          <tbody>
            <%= for %Instance{} = i <- @trashed do %>
              <tr>
                <td><%= i.name || i.agent_id %></td>
                <td style="font-size:11px;"><%= i.spec_id %></td>
                <td style="font-size:11px;"><%= i.source %></td>
                <td>
                  <button phx-click="restore" phx-value-agent_id={i.agent_id} class="btn">Restore</button>
                  <%= if match?({:delete, id} when id == i.agent_id, @pending_confirm) do %>
                    <button phx-click="delete" phx-value-agent_id={i.agent_id} class="btn" style="background:#7f1d1d;border-color:#7f1d1d;">
                      Confirm delete
                    </button>
                    <button phx-click="cancel_confirm" class="btn">Cancel</button>
                  <% else %>
                    <button phx-click="confirm_delete" phx-value-agent_id={i.agent_id} class="btn">
                      Delete permanently
                    </button>
                  <% end %>
                </td>
              </tr>
            <% end %>
          </tbody>
        </table>
      <% end %>
    </div>

    <div class="card" style="border-color:#7f1d1d;">
      <h2 style="color:#fb7185;">Empty trash</h2>
      <p>Removes every trashed agent permanently from Mnesia.  Two-click confirm.</p>
      <%= case @pending_confirm do %>
        <% :empty -> %>
          <p>
            <button phx-click="empty_trash" class="btn" style="background:#7f1d1d;border-color:#7f1d1d;">
              Confirm empty trash (<%= length(@trashed) %>)
            </button>
            <button phx-click="cancel_confirm" class="btn">Cancel</button>
          </p>

        <% _ -> %>
          <p>
            <button phx-click="confirm_empty" class="btn" disabled={@trashed == []}>
              Empty trash
            </button>
          </p>
      <% end %>
    </div>
    """
  end
end
