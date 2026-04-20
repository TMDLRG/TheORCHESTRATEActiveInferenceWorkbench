defmodule WorkbenchWeb.GuideLive.JidoDocs do
  @moduledoc "C12 -- render any file under jido/guides/ (upstream)."
  use WorkbenchWeb, :live_view

  @impl true
  def mount(%{"file" => file}, _session, socket) do
    safe = Path.basename(file)
    path = Path.join(WorkbenchWeb.KbPaths.jido_guides_dir(), safe)

    case File.read(path) do
      {:ok, body} ->
        {:ok,
         assign(socket,
           page_title: safe,
           file: safe,
           body: body,
           files: list_guides(),
           error: nil,
           qwen_page_type: :guide,
           qwen_page_key: "jido-docs/" <> safe,
           qwen_page_title: "Jido doc · " <> safe
         )}

      _ ->
        {:ok,
         assign(socket,
           page_title: safe,
           file: safe,
           body: "",
           files: list_guides(),
           error: :not_found,
           qwen_page_type: :guide,
           qwen_page_key: "jido-docs/" <> safe,
           qwen_page_title: "Jido doc · " <> safe
         )}
    end
  end

  def mount(_params, _session, socket) do
    {:ok,
     assign(socket,
       page_title: "Jido upstream docs",
       file: nil,
       body: nil,
       files: list_guides(),
       error: nil
     )}
  end

  defp list_guides do
    case File.ls(WorkbenchWeb.KbPaths.jido_guides_dir()) do
      {:ok, files} -> files |> Enum.filter(&String.ends_with?(&1, ".md")) |> Enum.sort()
      _ -> []
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <%= cond do %>
      <% is_nil(@file) -> %>
        <p><.link navigate={~p"/guide/jido"}>&larr; Jido guide</.link></p>
        <h1>Jido upstream docs (v2.2.0)</h1>
        <p style="color:#9cb0d6;max-width:800px;">
          The upstream Jido repo lives as a git submodule at <code class="inline">jido/</code>.
          Its <code class="inline">guides/</code> directory mirrors
          <a href="https://hexdocs.pm/jido" target="_blank" rel="noopener noreferrer">hexdocs.pm/jido</a>
          1:1.  Below: every file in that directory, rendered in-place.
        </p>

        <%= if @files == [] do %>
          <div class="card">
            <p>No upstream guide files found at <code class="inline">jido/guides/</code>.
              Make sure the git submodule is checked out (<code class="inline">git submodule update --init</code>).</p>
          </div>
        <% else %>
          <div class="card">
            <ul>
              <%= for f <- @files do %>
                <li><.link navigate={~p"/guide/jido/docs/#{f}"}><%= f %></.link></li>
              <% end %>
            </ul>
          </div>
        <% end %>

        <p>
          <a href="https://github.com/agentjido/jido" target="_blank" rel="noopener noreferrer">
            agentjido/jido on GitHub &rarr;
          </a>
        </p>

      <% @error == :not_found -> %>
        <p><.link navigate={~p"/guide/jido/docs"}>&larr; Upstream docs index</.link></p>
        <h1>Not found: <%= @file %></h1>

      <% true -> %>
        <p>
          <.link navigate={~p"/guide/jido/docs"}>&larr; Upstream docs index</.link>
          &middot;
          <a href="https://github.com/agentjido/jido" target="_blank" rel="noopener noreferrer">agentjido/jido &rarr;</a>
        </p>
        <h1><%= @file %></h1>
        <div class="card">
          <%= WorkbenchWeb.MarkdownHelper.render(@body) %>
        </div>
    <% end %>
    """
  end
end
