# active_inference/config/ — ReadmeAI

## Purpose

Runtime configuration for the umbrella. Follows the standard Elixir pattern: `config.exs` is loaded first in every environment, then the environment-specific file (`dev.exs`, `test.exs`, `prod.exs`) via `import_config "#{config_env()}.exs"` ([`config.exs:22`](config.exs)).

## Contents

| File | Environments | Role |
|---|---|---|
| [`config.exs`](config.exs) | all | Umbrella-wide defaults; `agent_plane` Jido instance, `workbench_web` endpoint, JSON library, logger format |
| [`dev.exs`](dev.exs) | `:dev` | HTTP port 4000, code reloader, debug errors, Mnesia at `priv/mnesia/dev`, LiveView debug annotations |
| [`test.exs`](test.exs) | `:test` | HTTP port 4002 (server off), auto-start Mnesia disabled (tests own lifecycle via `WorldModels.MnesiaCase`), warning log level |
| [`prod.exs`](prod.exs) | `:prod` | Static cache manifest, Mnesia at `priv/mnesia/prod`, info log level |

Secret files matching `config/*.secret.exs` are gitignored (see [`active_inference/.gitignore:12`](../.gitignore)).

## Public API surface

None — this folder is configuration.

## Data types & schemas

None.

## Constants & config keys

| Key | Default | Set in | Consumers |
|---|---|---|---|
| `:agent_plane, AgentPlane.JidoInstance` | `max_tasks: 1000` | [`config.exs:3`](config.exs) | [`apps/agent_plane/lib/agent_plane/jido_instance.ex`](../apps/agent_plane/lib/agent_plane/jido_instance.ex) |
| `:workbench_web, WorkbenchWeb.Endpoint, :url` | `host: "localhost"` | [`config.exs:6`](config.exs) | [`apps/workbench_web/lib/workbench_web/endpoint.ex`](../apps/workbench_web/lib/workbench_web/endpoint.ex) |
| `:workbench_web, WorkbenchWeb.Endpoint, :adapter` | `Bandit.PhoenixAdapter` | [`config.exs:7`](config.exs) | ibid |
| `:workbench_web, WorkbenchWeb.Endpoint, :render_errors` | `[formats: [html: WorkbenchWeb.ErrorHTML], layout: false]` | [`config.exs:8-11`](config.exs) | ibid |
| `:workbench_web, WorkbenchWeb.Endpoint, :pubsub_server` | `WorkbenchWeb.PubSub` | [`config.exs:12`](config.exs) | ibid |
| `:workbench_web, WorkbenchWeb.Endpoint, :live_view, :signing_salt` | `"ai-workbench-salt-2026"` | [`config.exs:13`](config.exs) | ibid |
| `:workbench_web, WorkbenchWeb.Endpoint, :secret_key_base` | (dev value — rotate in prod) | [`config.exs:14`](config.exs) | ibid |
| `:workbench_web, WorkbenchWeb.Endpoint, :http` | dev `port: 4000`; test `port: 4002, server: false` | [`dev.exs:4`](dev.exs), [`test.exs:4-6`](test.exs) | ibid |
| `:workbench_web, WorkbenchWeb.Endpoint, :check_origin` | `false` (dev) | [`dev.exs:5`](dev.exs) | ibid |
| `:workbench_web, WorkbenchWeb.Endpoint, :code_reloader` | `true` (dev) | [`dev.exs:6`](dev.exs) | ibid |
| `:workbench_web, WorkbenchWeb.Endpoint, :debug_errors` | `true` (dev) | [`dev.exs:7`](dev.exs) | ibid |
| `:workbench_web, WorkbenchWeb.Endpoint, :cache_static_manifest` | `"priv/static/cache_manifest.json"` (prod) | [`prod.exs:4`](prod.exs) | ibid |
| `:workbench_web, :dev_routes` | `true` (dev) | [`dev.exs:10`](dev.exs) | router |
| `:phoenix, :json_library` | `Jason` | [`config.exs:16`](config.exs) | Phoenix |
| `:phoenix, :stacktrace_depth` | `20` (dev) | [`dev.exs:16`](dev.exs) | Phoenix |
| `:phoenix, :plug_init_mode` | `:runtime` | [`dev.exs:17`](dev.exs), [`test.exs:14`](test.exs) | Phoenix |
| `:phoenix_live_view, :debug_heex_annotations` | `true` (dev) | [`dev.exs:18`](dev.exs) | LiveView |
| `:logger, :console, :format` | `"$time $metadata[$level] $message\n"` | [`config.exs:19`](config.exs) | Logger |
| `:logger, :console, :metadata` | `[:request_id]` | [`config.exs:20`](config.exs) | Logger |
| `:logger, :level` | test `:warning`; prod `:info` | [`test.exs:13`](test.exs), [`prod.exs:9`](prod.exs) | Logger |
| `:mnesia, :dir` | dev `~c"priv/mnesia/dev"`; prod `~c"priv/mnesia/prod"` | [`dev.exs:14`](dev.exs), [`prod.exs:7`](prod.exs) | [`apps/world_models/lib/world_models/event_log/setup.ex`](../apps/world_models/lib/world_models/event_log/setup.ex) |
| `:world_models, :auto_start_event_log` | test `false` (tests only) | [`test.exs:11`](test.exs) | [`apps/world_models/lib/world_models/application.ex`](../apps/world_models/lib/world_models/application.ex) |

## Telemetry / signals / events emitted here

None.

## Dependencies

- **Inbound**: every umbrella app reads `Application.get_env/2` at boot.
- **Outbound**: none (config is data).

## Verification status

- `:verified` — all keys referenced here are actively read by the apps listed in the "Consumers" column. Umbrella boots cleanly in dev / test / prod.

## Related

- Umbrella root: [`../README.md`](../README.md)
- Endpoint consumer: [`../apps/workbench_web/lib/workbench_web/endpoint.ex`](../apps/workbench_web/lib/workbench_web/endpoint.ex)
- Mnesia setup: [`../apps/world_models/lib/world_models/event_log/setup.ex`](../apps/world_models/lib/world_models/event_log/setup.ex)
