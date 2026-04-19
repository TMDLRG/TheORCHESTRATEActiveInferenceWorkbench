import Config

# The workbench ships no compiled asset pipeline (UI is inline CSS,
# Bandit HTTP, no esbuild/tailwind). cache_static_manifest is therefore
# omitted — setting it would only produce a boot-time warning looking
# for a file that never gets generated.

# Plan §11.5 — disk location for the Mnesia event log in prod.
# Overridden at runtime by MNESIA_DIR env var (see config/runtime.exs).
config :mnesia, dir: ~c"priv/mnesia/prod"

config :logger, level: :info
