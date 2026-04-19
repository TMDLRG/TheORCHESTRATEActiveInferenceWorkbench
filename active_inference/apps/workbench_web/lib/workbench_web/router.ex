defmodule WorkbenchWeb.Router do
  use WorkbenchWeb, :router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {WorkbenchWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
    plug WorkbenchWeb.Plugs.LearningPath
  end

  pipeline :api do
    plug :accepts, ["json"]
    plug :fetch_session
    plug WorkbenchWeb.Plugs.LearningPath
  end

  pipeline :media do
    plug :accepts, ["json", "wav", "mp3", "html"]
    plug :fetch_session
  end

  pipeline :proxy do
    plug :fetch_session
  end

  scope "/", WorkbenchWeb do
    pipe_through :browser

    # Unified learning-suite landing — bridges the Workbench surfaces and the
    # standalone /learninglabs/*.html simulators.
    live "/learn", LearningLive.Hub, :index
    live "/learn/chapter/:num", LearningLive.Chapter, :show
    live "/learn/session/:num/:slug", LearningLive.Session, :show
    live "/learn/progress", LearningLive.Progress, :show

    # Chat-bridge — opens a page that prepares on-page context + pops LibreChat.
    get "/learn/chat-bridge/chapter/:num", ChatBridgeController, :chapter
    get "/learn/chat-bridge/session/:num/:slug", ChatBridgeController, :session

    # Voice-autoplay shim install page (bookmarklet + userscript).
    get "/learn/voice-autoplay", VoiceAutoplayController, :index

    live "/", WorkbenchLive.Index, :index
    live "/equations", EquationsLive.Index, :index
    live "/equations/:id", EquationsLive.Show, :show
    live "/models", ModelsLive.Index, :index
    # `/run` is the original MVP maze route — aliased to the same
    # LiveView as `/world` so both URLs present the full-featured page
    # (all registered mazes, dynamic blanket, autorun, multi-episode
    # Run again, wall-hit UI). `RunLive.Index` is retained for legacy
    # tests and references but no longer routed to.
    live "/run", WorldLive.Index, :index

    # Plan §12 Phase 6 — new World UI.
    live "/world", WorldLive.Index, :index

    # Plan §12 Phase 8 — Glass Engine.
    live "/glass", GlassLive.Index, :index
    live "/glass/agent/:agent_id", GlassLive.Agent, :show
    live "/glass/signal/:signal_id", GlassLive.Signal, :show

    # Plan §12 Phase 7 — Agent Builder composition canvas.
    live "/builder/new", BuilderLive.Compose, :new
    live "/builder/:spec_id", BuilderLive.Compose, :edit

    # Lego-uplift Phase A — user-facing guide.
    live "/guide", GuideLive.Index, :index
    live "/guide/blocks", GuideLive.Blocks, :index
    live "/guide/examples", GuideLive.Examples, :index
    live "/guide/examples/:slug", GuideLive.Examples, :show
    live "/guide/build-your-first", GuideLive.Tutorial, :index

    # Documentation pass — in-app technical reference.
    live "/guide/technical", GuideLive.Technical.Index, :index
    live "/guide/technical/architecture", GuideLive.Technical.Architecture, :index
    live "/guide/technical/apps", GuideLive.Technical.Apps, :index
    live "/guide/technical/signals", GuideLive.Technical.Signals, :index
    live "/guide/technical/data", GuideLive.Technical.Data, :index
    live "/guide/technical/config", GuideLive.Technical.Config, :index
    live "/guide/technical/verification", GuideLive.Technical.Verification, :index
    live "/guide/technical/api/:module", GuideLive.Technical.Module, :show

    # Expansion Phase K — run any saved spec against any registered maze.
    live "/labs", LabsLive.Run, :index
    live "/labs/run", LabsLive.Run, :index

    # ORCHESTRATE Workbench uplift -- cookbook (50 runnable recipes).
    live "/cookbook", CookbookLive.Index, :index
    live "/cookbook/:slug", CookbookLive.Show, :show
    live "/guide/cookbook", GuideLive.Cookbook, :index

    # ORCHESTRATE Workbench uplift -- honest user-guide surfaces.
    live "/guide/creator", GuideLive.Creator, :index
    live "/guide/orchestrate", GuideLive.Orchestrate, :index
    live "/guide/level-up", GuideLive.LevelUp, :index
    live "/guide/credits", GuideLive.Credits, :index
    live "/guide/features", GuideLive.Features, :index
    live "/guide/learning", GuideLive.Learning, :index
    live "/guide/workbench", GuideLive.Workbench, :index
    live "/guide/labs", GuideLive.Labs, :index
    live "/guide/voice", GuideLive.Voice, :index
    live "/guide/chat", GuideLive.Chat, :index
    live "/guide/jido", GuideLive.Jido, :index
    live "/guide/jido/docs", GuideLive.JidoDocs, :index
    live "/guide/jido/docs/:file", GuideLive.JidoDocs, :show
    live "/guide/jido/:topic", GuideLive.JidoTopic, :show

    # Studio subsystem (S5) -- flexible agent runner + lifecycle dashboard.
    live "/studio",                  StudioLive.Index, :index
    live "/studio/new",              StudioLive.New,   :new
    live "/studio/run/:session_id",  StudioLive.Run,   :show
    live "/studio/agents/:agent_id", StudioLive.Agent, :show
    live "/studio/trash",            StudioLive.Trash, :index
    live "/guide/studio",            GuideLive.Studio, :index

    # Direct one-shot run endpoint used by the cookbook "Run in Studio"
    # button (bypasses the LV picker so the cookbook gives a true
    # single-click "run this recipe against this world" experience).
    get "/studio/run_recipe", StudioController, :run_recipe
  end

  # API pipeline (no CSRF; POST w/ JSON from fetch()).
  scope "/", WorkbenchWeb do
    pipe_through :api

    post "/api/uber-help", UberHelpController, :ask
  end

  # Speech (ClaudeSpeak HTTP wrapper proxy at 127.0.0.1:7712).
  scope "/speech", WorkbenchWeb do
    pipe_through :media

    get "/healthz", SpeechController, :healthz
    get "/voices", SpeechController, :voices
    post "/speak", SpeechController, :speak
    get "/narrate/chapter/:num", SpeechController, :narrate_chapter
  end

  # LibreChat reverse-proxy (all subpaths, any method).
  scope "/chat", WorkbenchWeb do
    pipe_through :proxy
    match :*, "/*path", ChatProxy, []
  end
end
