defmodule WorkbenchWeb.GuideLive.JidoTopic do
  @moduledoc "C11 -- render any knowledgebase/jido/NN-*.md file as HTML."
  use WorkbenchWeb, :live_view

  @impl true
  def mount(%{"topic" => slug}, _session, socket) do
    path = Path.join(WorkbenchWeb.KbPaths.knowledgebase_dir(), slug <> ".md")

    case File.read(path) do
      {:ok, body} ->
        {:ok,
         assign(socket,
           page_title: slug,
           slug: slug,
           body: body,
           error: nil,
           qwen_page_type: :guide,
           qwen_page_key: "jido/" <> slug,
           qwen_page_title: "Jido · " <> slug
         )}

      {:error, reason} ->
        {:ok,
         assign(socket,
           page_title: slug,
           slug: slug,
           body: "",
           error: reason,
           qwen_page_type: :guide,
           qwen_page_key: "jido/" <> slug,
           qwen_page_title: "Jido · " <> slug
         )}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <%= if is_nil(@error) do %>
      <p>
        <.link navigate={~p"/guide/jido"}>&larr; Jido guide</.link>
        &middot;
        <a href="https://github.com/agentjido/jido" target="_blank" rel="noopener noreferrer">
          agentjido/jido &rarr;
        </a>
      </p>
      <h1><%= @slug %></h1>
      <div class="card">
        <%= WorkbenchWeb.MarkdownHelper.render(@body) %>
      </div>
    <% else %>
      <p><.link navigate={~p"/guide/jido"}>&larr; Jido guide</.link></p>
      <h1>Topic not found: <%= @slug %></h1>
      <p style="color:#fb7185;">File system error: <code class="inline"><%= inspect(@error) %></code></p>
    <% end %>
    """
  end
end
