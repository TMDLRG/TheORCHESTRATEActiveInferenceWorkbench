# 22 — Discovery

> Catalog of registered actions, sensors, agents, plugins, and demos for tooling and introspection. Backed by `:persistent_term` (read O(1), concurrent).

## Initialization

In your `Application.start/2`:

```elixir
def start(_type, _args) do
  Jido.Discovery.init_async()   # non-blocking catalog scan

  children = [MyApp.Jido, ...]
  Supervisor.start_link(children, strategy: :one_for_one)
end
```

Queries before the scan completes return `[]`.

## Listing

```elixir
Jido.Discovery.list_actions(name: "search", category: :utility, tag: :ai, limit: 10, offset: 0)
Jido.Discovery.list_sensors(tag: :monitoring, limit: 5)
Jido.Discovery.list_agents(name: "worker")
Jido.Discovery.list_plugins()
Jido.Discovery.list_demos()
```

### Filter options (AND logic)

| Option | Type | Description |
|---|---|---|
| `:name` | `String.t()` | Partial match |
| `:description` | `String.t()` | Partial match |
| `:category` | `atom()` | Exact match |
| `:tag` | `atom()` | Must contain this tag |
| `:limit` | `integer()` | |
| `:offset` | `integer()` | |

## Fetching by Slug

```elixir
Jido.Discovery.get_action_by_slug("abc123de")
Jido.Discovery.get_sensor_by_slug("x7y8z9ab")
Jido.Discovery.get_agent_by_slug("def456gh")
Jido.Discovery.get_plugin_by_slug("ijk789lm")
Jido.Discovery.get_demo_by_slug("nop012qr")
```

Slugs are 8-char, stable, derived from module hash.

## Top-Level Delegates on `Jido`

```elixir
Jido.list_actions(opts \\ [])
Jido.list_sensors(opts \\ [])
Jido.list_plugins(opts \\ [])
Jido.list_demos(opts \\ [])

Jido.get_action_by_slug(slug)
Jido.get_sensor_by_slug(slug)
Jido.get_plugin_by_slug(slug)

Jido.refresh_discovery()
```

## Metadata Fields

```elixir
%{
  module: MyApp.CoolAction,
  name: "cool_action",
  description: "Does cool stuff",
  slug: "abc123de",
  category: :utility,
  tags: [:cool, :stuff]
}
```

## Catalog Refresh

```elixir
Jido.Discovery.refresh()                      # rescan all apps
{:ok, %DateTime{}} = Jido.Discovery.last_updated()
{:ok, catalog}     = Jido.Discovery.catalog() # full map with all metadata
```

Writes are expensive (`:persistent_term` triggers full GC). Avoid calling `refresh/0` frequently — init once at startup.

## Building Tooling

### List all signal routes

```elixir
for agent <- Jido.Discovery.list_agents() do
  routes =
    if function_exported?(agent.module, :signal_routes, 1) do
      agent.module.signal_routes(%{agent_module: agent.module})
    else
      []
    end
  {agent.module, routes}
end
```

### Generate API docs

```elixir
Jido.Discovery.list_actions()
|> Enum.sort_by(& &1.name)
|> Enum.map(&format_action/1)
|> Enum.join("\n\n")
```

### Capability checks

```elixir
has_ai? = Jido.Discovery.list_actions(tag: :ai) |> Enum.any?()

categories =
  Jido.Discovery.list_actions()
  |> Enum.map(& &1.category)
  |> Enum.uniq()
```

## Performance

- Storage: `:persistent_term` → O(1) reads, no GenServer bottleneck
- Concurrent reads allowed
- Writes are expensive → initialize once at startup, avoid frequent `refresh/0`

## Source

- `jido/guides/discovery.md`
- `jido/lib/jido/discovery.ex`
