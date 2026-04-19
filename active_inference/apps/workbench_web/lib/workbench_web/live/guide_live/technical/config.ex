defmodule WorkbenchWeb.GuideLive.Technical.Config do
  @moduledoc """
  `/guide/technical/config` — every Application env key and `config/*.exs`
  entry the workbench reads, with defaults and per-environment overrides.
  """
  use WorkbenchWeb, :live_view

  @entries [
    %{
      key: ":agent_plane, AgentPlane.JidoInstance, :max_tasks",
      default: "1000",
      env: "all",
      source: "config/config.exs:3",
      consumer: "apps/agent_plane/lib/agent_plane/jido_instance.ex"
    },
    %{
      key: ":workbench_web, WorkbenchWeb.Endpoint, :url",
      default: "host: \"localhost\"",
      env: "all",
      source: "config/config.exs:6",
      consumer: "apps/workbench_web/lib/workbench_web/endpoint.ex"
    },
    %{
      key: ":workbench_web, WorkbenchWeb.Endpoint, :adapter",
      default: "Bandit.PhoenixAdapter",
      env: "all",
      source: "config/config.exs:7",
      consumer: "Endpoint"
    },
    %{
      key: ":workbench_web, WorkbenchWeb.Endpoint, :render_errors",
      default: "formats: [html: ErrorHTML], layout: false",
      env: "all",
      source: "config/config.exs:8-11",
      consumer: "Endpoint"
    },
    %{
      key: ":workbench_web, WorkbenchWeb.Endpoint, :pubsub_server",
      default: "WorkbenchWeb.PubSub",
      env: "all",
      source: "config/config.exs:12",
      consumer: "Endpoint"
    },
    %{
      key: ":workbench_web, WorkbenchWeb.Endpoint, :live_view, :signing_salt",
      default: "\"ai-workbench-salt-2026\"",
      env: "all",
      source: "config/config.exs:13",
      consumer: "Endpoint"
    },
    %{
      key: ":workbench_web, WorkbenchWeb.Endpoint, :secret_key_base",
      default: "(dev value — rotate in prod)",
      env: "all",
      source: "config/config.exs:14",
      consumer: "Endpoint"
    },
    %{
      key: ":workbench_web, WorkbenchWeb.Endpoint, :http, :port",
      default: "4000 (dev), 4002 (test)",
      env: "dev/test",
      source: "config/dev.exs:4, config/test.exs:4",
      consumer: "Endpoint"
    },
    %{
      key: ":workbench_web, WorkbenchWeb.Endpoint, :server",
      default: "false in test",
      env: "test",
      source: "config/test.exs:6",
      consumer: "Endpoint"
    },
    %{
      key: ":workbench_web, WorkbenchWeb.Endpoint, :check_origin",
      default: "false",
      env: "dev",
      source: "config/dev.exs:5",
      consumer: "Endpoint"
    },
    %{
      key: ":workbench_web, WorkbenchWeb.Endpoint, :code_reloader",
      default: "true",
      env: "dev",
      source: "config/dev.exs:6",
      consumer: "Endpoint"
    },
    %{
      key: ":workbench_web, WorkbenchWeb.Endpoint, :debug_errors",
      default: "true",
      env: "dev",
      source: "config/dev.exs:7",
      consumer: "Endpoint"
    },
    %{
      key: ":workbench_web, WorkbenchWeb.Endpoint, :cache_static_manifest",
      default: "\"priv/static/cache_manifest.json\"",
      env: "prod",
      source: "config/prod.exs:4",
      consumer: "Endpoint"
    },
    %{
      key: ":workbench_web, :dev_routes",
      default: "true",
      env: "dev",
      source: "config/dev.exs:10",
      consumer: "Router"
    },
    %{
      key: ":phoenix, :json_library",
      default: "Jason",
      env: "all",
      source: "config/config.exs:16",
      consumer: "Phoenix"
    },
    %{
      key: ":phoenix, :stacktrace_depth",
      default: "20",
      env: "dev",
      source: "config/dev.exs:16",
      consumer: "Phoenix"
    },
    %{
      key: ":phoenix, :plug_init_mode",
      default: ":runtime",
      env: "dev/test",
      source: "config/dev.exs:17, config/test.exs:14",
      consumer: "Phoenix"
    },
    %{
      key: ":phoenix_live_view, :debug_heex_annotations",
      default: "true",
      env: "dev",
      source: "config/dev.exs:18",
      consumer: "LiveView"
    },
    %{
      key: ":logger, :console, :format",
      default: "\"$time $metadata[$level] $message\\n\"",
      env: "all",
      source: "config/config.exs:19",
      consumer: "Logger"
    },
    %{
      key: ":logger, :console, :metadata",
      default: "[:request_id]",
      env: "all",
      source: "config/config.exs:20",
      consumer: "Logger"
    },
    %{
      key: ":logger, :level",
      default: ":warning (test), :info (prod)",
      env: "test/prod",
      source: "config/test.exs:13, config/prod.exs:9",
      consumer: "Logger"
    },
    %{
      key: ":mnesia, :dir",
      default: "~c\"priv/mnesia/dev\" (dev), ~c\"priv/mnesia/prod\" (prod)",
      env: "dev/prod",
      source: "config/dev.exs:14, config/prod.exs:7",
      consumer: "apps/world_models/lib/world_models/event_log/setup.ex"
    },
    %{
      key: ":world_models, :auto_start_event_log",
      default: "true (dev/prod), false (test)",
      env: "test",
      source: "config/test.exs:11",
      consumer: "apps/world_models/lib/world_models/application.ex"
    }
  ]

  @impl true
  def mount(_params, _session, socket) do
    {:ok, assign(socket, page_title: "Configuration", entries: @entries)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <h1>Configuration</h1>
    <p style="color:#9cb0d6;max-width:780px;">
      Every <code class="inline">Application</code> env key and <code class="inline">config/*.exs</code> entry the
      workbench reads, with environment, default, source location, and consumer.
    </p>

    <div class="card">
      <table class="table">
        <thead><tr><th>Key</th><th>Default</th><th>Env</th><th>Source</th><th>Consumer</th></tr></thead>
        <tbody>
          <%= for e <- @entries do %>
            <tr>
              <td style="font-size:11px;"><code class="inline"><%= e.key %></code></td>
              <td style="font-size:11px;"><code class="inline"><%= e.default %></code></td>
              <td><%= e.env %></td>
              <td style="font-size:11px;"><code class="inline"><%= e.source %></code></td>
              <td style="font-size:11px;"><code class="inline"><%= e.consumer %></code></td>
            </tr>
          <% end %>
        </tbody>
      </table>
    </div>

    <p>
      <.link navigate={~p"/guide/technical"}>← Technical reference</.link>
    </p>
    """
  end
end
