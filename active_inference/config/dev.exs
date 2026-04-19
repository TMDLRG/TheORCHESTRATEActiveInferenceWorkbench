import Config

config :workbench_web, WorkbenchWeb.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: 4000],
  check_origin: false,
  code_reloader: true,
  debug_errors: true,
  watchers: []

config :workbench_web, dev_routes: true

# Plan §11.5 — disk location for the Mnesia event log in dev.
# Path is relative to the dir `mix phx.server` runs from (active_inference/).
config :mnesia, dir: ~c"priv/mnesia/dev"

config :phoenix, :stacktrace_depth, 20
config :phoenix, :plug_init_mode, :runtime
config :phoenix_live_view, :debug_heex_annotations, true
