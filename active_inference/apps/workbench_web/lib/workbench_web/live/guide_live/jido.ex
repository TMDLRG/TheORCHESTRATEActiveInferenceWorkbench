defmodule WorkbenchWeb.GuideLive.Jido do
  @moduledoc "C10 -- Jido primer + knowledgebase MASTER-INDEX."
  use WorkbenchWeb, :live_view

  @impl true
  def mount(_params, _session, socket) do
    dir = WorkbenchWeb.KbPaths.knowledgebase_dir()

    {:ok,
     socket
     |> assign(
       page_title: "Jido guide",
       index: safe_read(Path.join(dir, "MASTER-INDEX.md")),
       topics: list_topics(dir)
     )}
  end

  defp list_topics(dir) do
    case File.ls(dir) do
      {:ok, files} ->
        files
        |> Enum.filter(&String.ends_with?(&1, ".md"))
        |> Enum.reject(&(&1 == "MASTER-INDEX.md"))
        |> Enum.sort()
        |> Enum.map(fn f -> %{slug: Path.rootname(f), file: f} end)

      _ ->
        []
    end
  end

  defp safe_read(path) do
    case File.read(path) do
      {:ok, body} -> body
      _ -> "# Jido knowledgebase\n\nMASTER-INDEX.md not found at the expected path."
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <p><.link navigate={~p"/guide"}>&larr; Guide</.link></p>
    <h1>Jido -- the pure-Elixir agent framework</h1>

    <div class="card">
      <h2>Credit and provenance</h2>
      <p>
        This suite runs on <strong>Jido</strong>, the pure-Elixir agent framework created and
        maintained by the <strong>agentjido</strong> organization.
      </p>
      <ul>
        <li>Version in use: <strong>v2.2.0</strong></li>
        <li>GitHub: <a href="https://github.com/agentjido/jido" target="_blank" rel="noopener noreferrer">github.com/agentjido/jido</a></li>
        <li>Homepage: <a href="https://jido.run" target="_blank" rel="noopener noreferrer">jido.run</a></li>
        <li>Upstream guides: <.link navigate={~p"/guide/jido/docs"}>in-app rendering</.link></li>
      </ul>
    </div>

    <div class="card">
      <h2>Curated knowledgebase (27 topics, 5700+ lines)</h2>
      <p style="color:#9cb0d6;">
        Curated locally for this suite under <code class="inline">knowledgebase/jido/</code>.
        Read the MASTER-INDEX below, then drill into any topic.
      </p>
      <div style="margin-top:12px;">
        <%= WorkbenchWeb.MarkdownHelper.render(@index) %>
      </div>
    </div>

    <div class="card">
      <h2>All topic files</h2>
      <ul>
        <%= for t <- @topics do %>
          <li><.link navigate={~p"/guide/jido/#{t.slug}"}><%= t.file %></.link></li>
        <% end %>
      </ul>
    </div>
    """
  end
end
