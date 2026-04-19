defmodule WorkbenchWeb.GuideLive.Labs do
  @moduledoc "C7 -- labs guide (index + 7 subpages share this LiveView)."
  use WorkbenchWeb, :live_view

  @labs [
    %{
      slug: "bayes",
      name: "BayesChips",
      route: "/learn/lab/bayes",
      tier: 1,
      blurb: "Single-step Bayes on a chip world.  Prior * likelihood -> posterior, visualised.",
      book: "Ch 2",
      coach: "aif-lab-bayes"
    },
    %{
      slug: "pomdp",
      name: "POMDP Machine",
      route: "/learn/lab/pomdp",
      tier: 3,
      blurb: "Belief updating under partial observability; A and B matrices on sliders.",
      book: "Ch 4 / Ch 7",
      coach: "aif-lab-pomdp"
    },
    %{
      slug: "forge",
      name: "Free Energy Forge",
      route: "/learn/lab/forge",
      tier: 3,
      blurb: "Eq 4.19 live: set prior, likelihood, q(s) and watch each term of F move.",
      book: "Ch 4 / Ch 8",
      coach: "aif-lab-forge"
    },
    %{
      slug: "tower",
      name: "Laplace Tower",
      route: "/learn/lab/tower",
      tier: 4,
      blurb: "Multi-level predictive coding.  Top-down predictions meet bottom-up errors.",
      book: "Ch 5 / Ch 8",
      coach: "aif-lab-tower"
    },
    %{
      slug: "anatomy",
      name: "Anatomy Studio",
      route: "/learn/lab/anatomy",
      tier: 3,
      blurb: "Figure 5.5 live: state, prediction, error, precision -- labelled microcircuit.",
      book: "Ch 5 / Ch 9",
      coach: "aif-lab-anatomy"
    },
    %{
      slug: "atlas",
      name: "Cortical Atlas",
      route: "/learn/lab/atlas",
      tier: 4,
      blurb: "Neuromodulator sliders -> precision -> behavioural consequence.",
      book: "Ch 5 / Ch 10",
      coach: "aif-lab-atlas"
    },
    %{
      slug: "frog",
      name: "Jumping Frog",
      route: "/learn/lab/frog",
      tier: 3,
      blurb: "Multi-modal inference: two observation channels, one posterior.",
      book: "Ch 2 / Ch 3",
      coach: "aif-lab-frog"
    }
  ]

  @impl true
  def mount(_params, _session, socket),
    do: {:ok, assign(socket, page_title: "Labs guide", labs: @labs)}

  @impl true
  def render(assigns) do
    ~H"""
    <p><.link navigate={~p"/guide"}>&larr; Guide</.link></p>
    <h1>Learning Labs -- seven hands-on simulators</h1>
    <p style="color:#9cb0d6;max-width:900px;">
      Each lab is a single HTML simulator under <code class="inline">priv/static/learninglabs/</code>.
      Each supports <code class="inline">?path=kid|real|equation|derivation</code> and
      <code class="inline">?beat=N</code> for deep-link storytelling.  Every lab has a dedicated
      coach agent (<code class="inline">aif-lab-<em>slug</em></code>) reachable via LibreChat.
    </p>

    <div class="grid-2">
      <%= for lab <- @labs do %>
        <div class="card">
          <h2><%= lab.name %>
            <span class="tag general" style="font-size:11px;">Level <%= lab.tier %></span>
          </h2>
          <p><%= lab.blurb %></p>
          <ul style="font-size:13px;">
            <li><strong>Launch:</strong> <a href={lab.route}><%= lab.route %></a></li>
            <li><strong>Book anchor:</strong> <%= lab.book %></li>
            <li><strong>Coach agent:</strong> <code class="inline"><%= lab.coach %></code></li>
          </ul>
          <p style="font-size:12px;color:#9cb0d6;">
            Try <code class="inline"><%= lab.route %>?path=real</code> or any other path to reshape the explanation.
          </p>
        </div>
      <% end %>
    </div>

    <p>
      <.link navigate={~p"/learn"} class="btn primary">Open Learn hub &rarr;</.link>
      <.link navigate={~p"/guide/chat"} class="btn">Chat with a lab coach &rarr;</.link>
    </p>
    """
  end
end
