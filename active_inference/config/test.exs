import Config

config :workbench_web, WorkbenchWeb.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: 4002],
  secret_key_base: "active-inference-workbench-test-secret-key-base-1234567890-1234567890-123456",
  server: false

# Plan §12 Phase 2 — tests own the Mnesia lifecycle via WorldModels.MnesiaCase;
# skip the auto-boot so existing tests (mvp_maze, smoke, golden) don't create
# a stray schema in the repo root.
config :world_models, :auto_start_event_log, false

config :logger, level: :warning
config :phoenix, :plug_init_mode, :runtime
