import Config

config :agent_plane, AgentPlane.JidoInstance, max_tasks: 1000

config :workbench_web, WorkbenchWeb.Endpoint,
  url: [host: "localhost"],
  adapter: Bandit.PhoenixAdapter,
  render_errors: [
    formats: [html: WorkbenchWeb.ErrorHTML],
    layout: false
  ],
  pubsub_server: WorkbenchWeb.PubSub,
  live_view: [signing_salt: "ai-workbench-salt-2026"],
  secret_key_base: "active-inference-workbench-dev-secret-key-base-please-rotate-in-prod-12345678"

# Optional override for absolute URLs (bookmarklet, emails). If unset, derived from each HTTP request.
config :workbench_web, :public_origin, nil

config :phoenix, :json_library, Jason

config :logger, :console,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

import_config "#{config_env()}.exs"
