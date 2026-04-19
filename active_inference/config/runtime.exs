import Config

# ---------------------------------------------------------------------------
# runtime.exs
#
# Evaluated at release boot (and also at `mix phx.server` time in dev/test).
# Everything that must read environment variables at the moment the BEAM
# starts — secrets, hostnames, ports, persistence paths — belongs here.
#
# See:
#   * active_inference/Dockerfile        — container entrypoint is `bin/orcworkbench start`
#   * docker-compose.yml (repo root)     — sets the env vars below
#   * active_inference/config/prod.exs   — compile-time prod config (kept minimal)
# ---------------------------------------------------------------------------

if origin = System.get_env("PHX_PUBLIC_ORIGIN") do
  config :workbench_web, :public_origin, String.trim_trailing(origin, "/")
end

if config_env() == :prod do
  secret_key_base =
    System.get_env("SECRET_KEY_BASE") ||
      raise """
      environment variable SECRET_KEY_BASE is missing.
      Generate one with: mix phx.gen.secret
      """

  host = System.get_env("PHX_HOST") || "localhost"
  port = String.to_integer(System.get_env("PORT") || "4000")

  config :workbench_web, WorkbenchWeb.Endpoint,
    url: [host: host, port: 80, scheme: "http"],
    http: [
      # bind to all interfaces so the container exposes the port
      ip: {0, 0, 0, 0, 0, 0, 0, 0},
      port: port
    ],
    secret_key_base: secret_key_base,
    server: true

  # Mnesia on-disk event log. `:mnesia, :dir` must be a charlist, not a
  # binary — the Erlang mnesia app does not accept strings.
  mnesia_dir = System.get_env("MNESIA_DIR") || "/data/mnesia"
  File.mkdir_p!(mnesia_dir)
  config :mnesia, dir: String.to_charlist(mnesia_dir)
end
