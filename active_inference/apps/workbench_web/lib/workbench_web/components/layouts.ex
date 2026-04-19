defmodule WorkbenchWeb.Layouts do
  use WorkbenchWeb, :html

  embed_templates "layouts/*"

  def root(assigns) do
    ~H"""
    <!DOCTYPE html>
    <html lang="en" style="height:100%">
      <head>
        <meta charset="utf-8" />
        <meta name="viewport" content="width=device-width, initial-scale=1.0" />
        <meta name="csrf-token" content={get_csrf_token()} />
        <.live_title suffix=" · The ORCHESTRATE Active Inference Learning Workbench"><%= assigns[:page_title] || "Workbench" %></.live_title>
        <link rel="stylesheet" href={~p"/assets/suite-tokens.css"} />
        <style><%= raw(inline_css()) %></style>
      </head>
      <body style="margin:0;min-height:100%;background:#0b1020;color:#e8ecf1;font-family:ui-monospace,Menlo,Consolas,monospace">
        <header class="top-bar">
          <div class="brand">
            <span class="brand-name">The ORCHESTRATE Active Inference Learning Workbench</span>
            <span class="brand-tagline">ORCHESTRATE × Active Inference — runs on pure Jido</span>
          </div>
          <nav>
            <.link navigate={~p"/"}>Overview</.link>
            <.link navigate={~p"/learn"} style="color:#d8b56c;">Learn ▸</.link>
            <.link navigate={~p"/guide"}>Guide</.link>
            <.link navigate={~p"/equations"}>Equations</.link>
            <.link navigate={~p"/models"}>Models</.link>
            <.link navigate={~p"/world"}>World</.link>
            <.link navigate={~p"/builder/new"}>Builder</.link>
            <.link navigate={~p"/labs"}>Labs</.link>
            <.link navigate={~p"/studio"}>Studio</.link>
            <.link navigate={~p"/glass"}>Glass</.link>
            <.running_chip />
            <span class="persona-chip-nav" id="persona-chip-nav" title="Current learning path">
              <%= WorkbenchWeb.LearningCatalog.path_label(assigns[:learning_path] || "real") %>
            </span>
          </nav>
        </header>
        <main class="main"><%= @inner_content %></main>
        <.citation_footer />

        <!-- Uber-help drawer (Qwen). Floating button bottom-right; click to open. -->
        <button id="uber-help-fab" aria-label="Ask Qwen">✨ Ask Qwen</button>
        <aside id="uber-help-drawer" role="dialog" aria-modal="false" aria-hidden="true">
          <header>
            <strong style="color:#d8b56c;">✨ Qwen · uber help</strong>
            <button id="uber-help-close" aria-label="Close">✕</button>
          </header>
          <div id="uber-help-log" aria-live="polite"></div>
          <form id="uber-help-form">
            <input id="uber-help-input" type="text" autocomplete="off"
                   placeholder="Ask about the current page, or paste a concept…" />
            <button type="submit" class="primary">Send</button>
          </form>
          <div class="chips">
            <button data-chip="Explain the hero concept of this session in 3 sentences.">Explain this</button>
            <button data-chip="Give me a concrete analogy I could try with household objects.">Analogy</button>
            <button data-chip="What should I do next to cement this?">What's next?</button>
            <button data-chip="Narrate your answer.">🔊 Narrate</button>
          </div>
          <a id="uber-full-chat-link" href="http://localhost:3080/" target="_blank" rel="noopener noreferrer" class="full-chat-link">Open full chat ▸ (new tab)</a>
        </aside>

        <!-- Phase 7 JS pipeline: Phoenix LiveView + litegraph.js from CDN,
             plus our authored composition-canvas hook. The CDN dependency
             keeps the MVP single-file-deployable; a bundler (Phase 10) can
             replace these with local vendored files. -->
        <script src="https://cdn.jsdelivr.net/npm/phoenix@1.7.14/priv/static/phoenix.min.js"></script>
        <script src="https://cdn.jsdelivr.net/npm/phoenix_live_view@0.20.17/priv/static/phoenix_live_view.min.js"></script>
        <script src="https://cdn.jsdelivr.net/npm/litegraph.js@0.7.18/build/litegraph.min.js"></script>
        <link rel="stylesheet"
              href="https://cdn.jsdelivr.net/npm/litegraph.js@0.7.18/css/litegraph.css" />
        <script src={~p"/assets/composition_canvas.js"}></script>
        <script src={~p"/assets/app.js"}></script>
        <!-- Suite-wide cookie bridge: learners switch path on the hub; the
             cookie propagates to /learninglabs/*.html so the Shell respects
             the choice without a second picker. -->
        <script>
          window.addEventListener('phx:suite_set_cookie', function(e) {
            if (!e || !e.detail || !e.detail.name) return;
            var v = String(e.detail.value || '');
            document.cookie = e.detail.name + '=' + v + '; path=/; max-age=' + (60*60*24*365) + '; samesite=lax';
          });
        </script>
      </body>
    </html>
    """
  end

  def app(assigns) do
    ~H"""
    <%= @inner_content %>
    """
  end

  @doc """
  "Running sessions" chip for the global nav.

  Lists every live `WorkbenchWeb.Episode` (Labs or Studio origin) so the
  user can click any nav link without losing their in-progress run.
  Queries `WorkbenchWeb.ActiveRuns` on every render -- cheap enough to
  run per-request since episodes are few and the registry scan is ETS.

  Renders as a native `<details>` element so no JS is required for the
  dropdown; the browser handles open/close.
  """
  def running_chip(assigns) do
    runs = WorkbenchWeb.ActiveRuns.list()
    assigns = assign(assigns, runs: runs, count: length(runs))

    ~H"""
    <%= if @count > 0 do %>
      <details class="running-chip" title="Active episodes -- click to return">
        <summary>● Running (<%= @count %>)</summary>
        <div class="running-chip-dropdown">
          <%= for r <- @runs do %>
            <.link navigate={~p"/studio/run/#{r.session_id}"} class="running-chip-item">
              <strong><%= r.session_id %></strong>
              <span>
                <%= r.steps %> / <%= r.max_steps %> steps
                <%= if r.terminal?, do: " · done" %>
              </span>
              <%= if r.agent_id do %>
                <span class="running-chip-agent"><%= r.agent_id %></span>
              <% end %>
            </.link>
          <% end %>
        </div>
      </details>
    <% end %>
    """
  end

  @doc """
  Global citation + credit footer. Renders on every page via `root/1`.
  Source of truth for the copy: `BRANDING.md` at the repo root.
  """
  def citation_footer(assigns) do
    ~H"""
    <footer class="citation-footer">
      <div class="citation-footer-inner">
        <p class="tagline">
          Built with wisdom from
          <a href="https://www.amazon.com/ORCHESTRATE-Prompting-Professional-AI-Outputs-ebook/dp/B0G2B9LG6V"
             target="_blank" rel="noopener noreferrer">THE ORCHESTRATE METHOD™</a>
          and
          <a href="https://www.amazon.com/Level-Usage-Maturity-Model-Excellence-ebook/dp/B0GS4WDVFZ"
             target="_blank" rel="noopener noreferrer">LEVEL UP</a>
          by <a href="https://www.linkedin.com/in/mpolzin/" target="_blank" rel="noopener noreferrer">Michael Polzin</a>
          — running on pure <a href="https://github.com/agentjido/jido" target="_blank" rel="noopener noreferrer">Jido</a> v2.2.0 on the BEAM,
          teaching Active Inference from
          <a href="https://mitpress.mit.edu/9780262045353/active-inference/" target="_blank" rel="noopener noreferrer">
            Parr, Pezzulo &amp; Friston (2022, MIT Press, CC BY-NC-ND)</a>.
        </p>
        <p class="links">
          <%!-- TODO(workstream-C): swap to verified `~p` routes once
               /guide/credits, /guide/creator, /guide/jido, /guide/orchestrate,
               /guide/level-up LiveViews ship. For now plain anchors so the
               footer compiles ahead of the LiveViews. --%>
          <a href="/guide/credits">Credits &amp; Attributions</a>
          <span>·</span>
          <a href="/guide/creator">About the Creator</a>
          <span>·</span>
          <a href="/guide/jido">Jido Guide</a>
          <span>·</span>
          <a href="/guide/orchestrate">ORCHESTRATE</a>
          <span>·</span>
          <a href="/guide/level-up">Level Up</a>
        </p>
      </div>
    </footer>
    """
  end

  defp inline_css do
    """
    :root { color-scheme: dark; }
    * { box-sizing: border-box; }
    a { color: #7dd3fc; text-decoration: none; }
    a:hover { text-decoration: underline; }
    .top-bar {
      display: flex; align-items: center; justify-content: space-between;
      padding: 10px 20px; background: #111832; border-bottom: 1px solid #24314f;
      position: sticky; top: 0; z-index: 10;
    }
    .top-bar .brand { display: flex; flex-direction: column; line-height: 1.15; }
    .top-bar .brand .brand-name { font-weight: 700; color: #e3f2ff; font-size: 14px; letter-spacing: 0.2px; }
    .top-bar .brand .brand-tagline { font-size: 10px; color: #9cb0d6; letter-spacing: 0.3px; }
    .top-bar nav a { margin-left: 16px; font-size: 14px; }

    /* ----- Global citation footer (BRANDING.md) ----- */
    .citation-footer {
      border-top: 1px solid #1e2a48; background: #0a1226; color: #9cb0d6;
      padding: 18px 20px 28px; margin-top: 32px; font-size: 12px; line-height: 1.55;
    }
    .citation-footer-inner { max-width: 1280px; margin: 0 auto; }
    .citation-footer .tagline { margin: 0 0 8px; }
    .citation-footer .tagline a { color: #7dd3fc; }
    .citation-footer .links { margin: 0; color: #556478; }
    .citation-footer .links a { color: #9cb0d6; margin-right: 4px; }
    .citation-footer .links span { margin: 0 6px 0 2px; color: #3d4c77; }
    .citation-footer .links a:hover { color: #e8ecf1; }
    .persona-chip-nav { margin-left: 18px; padding: 3px 8px; border-radius: 999px;
      font-size: 11px; color: #fff8e6; background: rgba(216,181,108,0.18);
      border: 1px solid rgba(216,181,108,0.4); }

    /* Running-sessions chip in the nav. */
    .running-chip { display: inline-block; position: relative; margin-left: 16px; }
    .running-chip > summary {
      list-style: none; cursor: pointer;
      padding: 3px 10px; border-radius: 999px; font-size: 11px;
      color: #1b1410; background: #5eead4; border: 1px solid #5eead4;
      font-weight: 700;
    }
    .running-chip > summary::-webkit-details-marker { display: none; }
    .running-chip[open] > summary { background: #34d399; border-color: #34d399; }
    .running-chip-dropdown {
      position: absolute; right: 0; top: 100%; margin-top: 6px;
      background: #121a33; border: 1px solid #263257; border-radius: 6px;
      min-width: 320px; max-width: 480px; z-index: 50;
      box-shadow: 0 10px 30px rgba(0,0,0,0.5);
      padding: 6px;
    }
    .running-chip-item {
      display: block; padding: 8px 10px; border-radius: 4px;
      color: #e8ecf1; text-decoration: none; font-size: 12px; line-height: 1.4;
    }
    .running-chip-item:hover { background: rgba(94,234,212,0.08); text-decoration: none; }
    .running-chip-item strong { color: #5eead4; font-family: ui-monospace, Menlo, Consolas, monospace; }
    .running-chip-item span { display: block; color: #9cb0d6; font-size: 11px; }
    .running-chip-agent { color: #7dd3fc !important; font-family: ui-monospace, Menlo, Consolas, monospace; }

    /* ----- Uber-help drawer (Qwen) ----- */
    #uber-help-fab { position: fixed; bottom: 22px; right: 22px; z-index: 500;
      background: linear-gradient(180deg, #b3863a, #6e5325); color: #fff8e6;
      border: 1px solid #d8b56c; border-radius: 999px; padding: 10px 16px;
      font: 600 13px ui-monospace, Menlo, Consolas, monospace;
      cursor: pointer; box-shadow: 0 6px 18px rgba(0,0,0,0.4); }
    #uber-help-fab:hover { filter: brightness(1.1); }
    #uber-help-drawer { position: fixed; right: 0; top: 0; bottom: 0;
      width: min(420px, 96vw); background: #0b1020; border-left: 1px solid #263257;
      z-index: 501; display: none; flex-direction: column;
      box-shadow: -10px 0 30px rgba(0,0,0,0.5); color: #e8ecf1; }
    #uber-help-drawer.on { display: flex; }
    #uber-help-drawer header { padding: 14px 16px; border-bottom: 1px solid #263257;
      display: flex; justify-content: space-between; align-items: center; }
    #uber-help-close { background: transparent; color: #9cb0d6; border: 1px solid #263257;
      border-radius: 999px; padding: 3px 8px; font-size: 11px; cursor: pointer; }
    #uber-help-log { flex: 1 1 auto; padding: 12px 16px; overflow: auto; font-size: 13px; line-height: 1.5; }
    #uber-help-log .msg { margin-bottom: 12px; padding: 8px 10px; border-radius: 6px; }
    #uber-help-log .msg.user { background: rgba(125,211,252,0.08); border: 1px solid rgba(125,211,252,0.3); }
    #uber-help-log .msg.assistant { background: rgba(216,181,108,0.08); border: 1px solid rgba(216,181,108,0.3); }
    #uber-help-log .msg.error { background: rgba(251,113,133,0.08); border: 1px solid rgba(251,113,133,0.3); color:#fb7185; }
    #uber-help-form { display: flex; gap: 6px; padding: 10px 12px; border-top: 1px solid #263257; }
    #uber-help-input { flex: 1 1 auto; background: #0a1226; color: #e8ecf1;
      border: 1px solid #263257; padding: 8px 10px; border-radius: 6px;
      font: 13px ui-monospace, monospace; }
    #uber-help-form .primary { background: #1d4ed8; border: 1px solid #1d4ed8; color: white;
      padding: 8px 14px; border-radius: 6px; cursor: pointer; font: 600 12px ui-monospace, monospace; }
    #uber-help-drawer .chips { display: flex; flex-wrap: wrap; gap: 6px; padding: 4px 12px 10px; }
    #uber-help-drawer .chips button { background: rgba(255,255,255,0.04); color: #9cb0d6;
      border: 1px solid #263257; border-radius: 999px; padding: 4px 8px;
      font-size: 11px; cursor: pointer; }
    #uber-help-drawer .chips button:hover { color: #e8ecf1; background: rgba(125,211,252,0.1); }
    #uber-help-drawer .full-chat-link { display: block; padding: 8px 16px; text-align: right;
      border-top: 1px solid #263257; color: #7dd3fc; font-size: 12px; text-decoration: none; }
    #uber-help-drawer .full-chat-link:hover { text-decoration: underline; }
    .main { padding: 20px; max-width: 1280px; margin: 0 auto; }
    h1 { margin: 0 0 8px; font-size: 22px; }
    h2 { margin: 20px 0 8px; font-size: 18px; color: #ffd59e; }
    h3 { margin: 14px 0 6px; font-size: 15px; color: #b1e4ff; }
    .card {
      background: #121a33; border: 1px solid #263257; border-radius: 8px;
      padding: 16px; margin-bottom: 16px;
    }
    .grid-2 { display: grid; grid-template-columns: 1fr 1fr; gap: 16px; }
    .grid-3 { display: grid; grid-template-columns: 1fr 1fr 1fr; gap: 16px; }
    .mono { font-family: ui-monospace, Menlo, Consolas, monospace; }
    pre {
      background: #0a1226; border: 1px solid #1e2a48; border-radius: 6px;
      padding: 10px; overflow-x: auto; font-size: 12px;
      white-space: pre; color: #cbd5e1;
    }
    code.inline { background: #0a1226; padding: 2px 5px; border-radius: 3px; color: #c4b5fd; }
    table { width: 100%; border-collapse: collapse; font-size: 13px; }
    th, td { border-bottom: 1px solid #24314f; padding: 6px 8px; text-align: left; vertical-align: top; }
    th { color: #ffd59e; font-weight: 600; }
    .tag { display: inline-block; padding: 2px 6px; margin-right: 4px; border-radius: 3px; font-size: 11px; }
    .tag.discrete { background: #193e2c; color: #86efac; }
    .tag.continuous { background: #3a1b45; color: #f0abfc; }
    .tag.hybrid { background: #3a2e1b; color: #fde68a; }
    .tag.general { background: #1b263a; color: #93c5fd; }
    .tag.verified { background: #13352a; color: #5eead4; }
    .tag.uncertain { background: #3a2e1b; color: #fde68a; }
    .btn {
      display: inline-block; padding: 6px 12px; border-radius: 5px; border: 1px solid #3d4c77;
      background: #1a2342; color: #cbd5e1; cursor: pointer; font-family: inherit;
    }
    .btn.primary { background: #1d4ed8; border-color: #1d4ed8; color: white; }
    .btn:disabled { opacity: 0.5; cursor: not-allowed; }
    .btn:hover:not(:disabled) { filter: brightness(1.2); }
    label { font-size: 12px; color: #9cb0d6; display: block; margin-bottom: 4px; }
    select, input[type=text], input[type=number] {
      background: #0a1226; color: #e8ecf1; border: 1px solid #263257; padding: 6px 8px;
      border-radius: 4px; font-family: inherit; font-size: 13px;
    }
    .checkbox-row { display: inline-flex; align-items: center; gap: 4px; margin-right: 10px; font-size: 13px; }

    /* Maze grid */
    .maze-grid { display: grid; gap: 0; border: 1px solid #1e2a48; background: #000; width: max-content; }
    .maze-cell {
      width: 24px; height: 24px;
      display: flex; align-items: center; justify-content: center;
      font-size: 12px; font-weight: 600;
    }
    .maze-cell.empty { background: #0f1a34; }
    .maze-cell.wall  { background: #000; }
    .maze-cell.start { background: #0f1a34; color: #60a5fa; }
    .maze-cell.goal  { background: #0f1a34; color: #34d399; }
    .maze-cell.agent { background: #f59e0b !important; color: #111 !important; }
    .bar {
      display: inline-block; height: 10px; background: #60a5fa; vertical-align: middle;
      border-radius: 2px;
    }
    .bar.green { background: #34d399; }
    .bar.orange { background: #fb923c; }
    """
  end
end
