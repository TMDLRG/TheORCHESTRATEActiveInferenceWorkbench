defmodule WorkbenchWeb.GuideLive.Technical.Verification do
  @moduledoc """
  `/guide/technical/verification` — the "real honesty" page. What is
  verified by tests end-to-end vs what is scaffolded vs uncertain.
  """
  use WorkbenchWeb, :live_view

  alias ActiveInferenceCore.Equations
  alias WorkbenchWeb.Docs.VerificationManifest

  @impl true
  def mount(_params, _session, socket) do
    manifest = VerificationManifest.all()
    manifest_counts = VerificationManifest.counts()

    equation_counts =
      Equations.all()
      |> Enum.group_by(& &1.verification_status)
      |> Enum.map(fn {k, list} -> {k, length(list)} end)
      |> Map.new()

    {:ok,
     assign(socket,
       page_title: "Verification",
       manifest: manifest,
       manifest_counts: manifest_counts,
       equation_counts: equation_counts
     )}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <h1>Verification</h1>
    <p style="color:#9cb0d6;max-width:780px;">
      Honesty manifest. Vocabulary borrowed from the equation registry so the whole
      system reads consistently: <strong>verified</strong> (tested end-to-end),
      <strong>scaffolded</strong> (compiles and is wired), <strong>uncertain</strong>
      (known gap).
    </p>

    <div class="card">
      <h2>Rollup</h2>
      <table class="table">
        <thead><tr><th>Source</th><th>Verified</th><th>Scaffolded</th><th>Uncertain</th></tr></thead>
        <tbody>
          <tr>
            <td>Code manifest</td>
            <td><%= @manifest_counts.verified %></td>
            <td><%= @manifest_counts.scaffolded %></td>
            <td><%= @manifest_counts.uncertain %></td>
          </tr>
          <tr>
            <td>Equation registry</td>
            <td><%= Map.get(@equation_counts, :verified, 0) %></td>
            <td><%= Map.get(@equation_counts, :scaffolded, 0) %></td>
            <td><%= Map.get(@equation_counts, :uncertain, 0) %></td>
          </tr>
        </tbody>
      </table>
    </div>

    <div class="card">
      <h2>Code manifest</h2>
      <table class="table">
        <thead><tr><th>Area</th><th>Status</th><th>Evidence</th><th>Notes</th></tr></thead>
        <tbody>
          <%= for e <- @manifest do %>
            <tr>
              <td><%= e.area %></td>
              <td><%= e.status %></td>
              <td style="font-size:11px;"><code class="inline"><%= e.evidence %></code></td>
              <td><%= e.notes %></td>
            </tr>
          <% end %>
        </tbody>
      </table>
    </div>

    <p>
      For equation-level verification, see
      <.link navigate={~p"/equations"}>/equations</.link> — each equation page
      shows its <code class="inline">:verification_status</code> and notes.
    </p>

    <p>
      <.link navigate={~p"/guide/technical"}>← Technical reference</.link>
    </p>
    """
  end
end
