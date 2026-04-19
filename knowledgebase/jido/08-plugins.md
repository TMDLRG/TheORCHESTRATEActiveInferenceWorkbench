# 08 — Plugins

> Plugins are composable capability modules. They bundle actions, state, schema, and signal routing into reusable units. Every agent gets default plugins (Identity / Thread / Memory) unless disabled.

## Definition

```elixir
defmodule MyApp.ChatPlugin do
  use Jido.Plugin,
    name: "chat",                               # required, letters/numbers/underscores
    state_key: :chat,                           # required, atom key in agent.state
    actions: [MyApp.Actions.SendMessage,        # required, list of Action modules
              MyApp.Actions.ListHistory],
    description: "Conversational messaging",    # optional
    category: :conversation,                    # optional metadata
    tags: [:messaging],                         # optional metadata
    vsn: "1.0.0",                               # optional
    schema: Zoi.object(%{                       # optional Zoi schema for plugin state
      messages: Zoi.list(Zoi.any()) |> Zoi.default([]),
      model: Zoi.string() |> Zoi.default("gpt-4")
    }),
    config_schema: Zoi.object(%{                # optional Zoi schema for per-agent config
      max_messages: Zoi.integer() |> Zoi.default(100)
    }),
    signal_patterns: ["chat.*"],                # optional glob patterns
    signal_routes: [                            # optional static routes
      {"chat.send", MyApp.Actions.SendMessage},
      {"chat.history", MyApp.Actions.ListHistory}
    ]
end
```

## Attaching Plugins to an Agent

```elixir
defmodule MyApp.MyAgent do
  use Jido.Agent,
    name: "my_agent",
    plugins: [
      MyApp.ChatPlugin,
      {MyApp.ConfigurablePlugin, %{max_value: 500}}    # with config
    ]
end
```

Plugins are mounted during `new/1`. Order matters: later plugins can depend on earlier ones.

## State Isolation

Plugin state is nested under `state_key`:

```elixir
agent.state = %{
  # Default plugins:
  __identity__: %{...},
  __thread__: %{...},
  __memory__: %{...},
  # User plugins:
  chat:     %{messages: [], model: "gpt-4"},
  database: %{pool_size: 5}
}

# Access plugin state
chat_state = MyAgent.plugin_state(agent, :chat)
```

Inside actions, target the plugin's key when updating:

```elixir
{:ok, %{chat: %{history: updated_history}}}
```

Or use `StateOp.SetPath` for surgical updates:

```elixir
%StateOp.SetPath{path: [:chat, :history], value: updated}
```

## Lifecycle Callbacks (all optional)

### `mount/2` — initialize plugin state

Called during `new/1`. Pure. No side effects.

```elixir
@impl Jido.Plugin
def mount(agent, config) do
  {:ok, %{initialized_at: DateTime.utc_now(), api_key: config[:api_key]}}
end
# Return: {:ok, state_map} | {:error, reason}
```

### `signal_routes/1` — dynamic routing (rare)

Use `signal_routes:` compile-time option first. Only use the callback when routes must be computed from runtime config:

```elixir
@impl Jido.Plugin
def signal_routes(_ctx), do: [{"runtime.resolved", MyAction}]
```

### `handle_signal/2` — pre-routing hook

Called before signal routing. Can override, abort, or continue.

```elixir
@impl Jido.Plugin
def handle_signal(signal, context) do
  cond do
    signal.type == "admin.override" -> {:ok, {:override, MyApp.AdminAction}}
    blocked?(signal)                -> {:error, :blocked}
    true                            -> {:ok, :continue}
  end
end
```

`context` includes: `:agent`, `:agent_module`, `:plugin`, `:plugin_spec`, `:config`.

### `transform_result/3` — post-call hook (sync only)

Transforms the agent returned from `AgentServer.call/3`.

```elixir
@impl Jido.Plugin
def transform_result(_action, agent, _context) do
  new_state = Map.put(agent.state, :last_call_at, DateTime.utc_now())
  %{agent | state: new_state}
end
```

### `child_spec/1` — supervised child processes

Return child specs started during `AgentServer.init/1`.

```elixir
@impl Jido.Plugin
def child_spec(config) do
  %{id: MyWorker, start: {MyWorker, :start_link, [config]}}
end
# Return: nil | single spec | list of specs
```

## Default Plugins (framework-provided singletons)

Every agent gets these unless overridden. They occupy **reserved state keys** and are mounted but **don't initialize state by default** — state is created on demand.

| Plugin | State key | Purpose |
|---|---|---|
| `Jido.Identity.Plugin` | `:__identity__` | Agent self-model (profile, lifecycle facts) |
| `Jido.Thread.Plugin` | `:__thread__` | Append-only conversation/event journal |
| `Jido.Memory.Plugin` | `:__memory__` | On-demand cognitive memory container |

Pod-wrapped agents also get `Jido.Pod.Plugin` at the reserved `:__pod__` key ([11](11-pods.md)).

### Identity Plugin

Gives every agent a first-class identity primitive: profile facts (age, origin, generation) and a monotonic revision counter.

```elixir
alias Jido.Identity.Agent, as: IdentityAgent
alias Jido.Identity.Profile

agent = MyAgent.new()
refute IdentityAgent.has_identity?(agent)           # not initialized yet

# Initialize on demand
agent = IdentityAgent.ensure(agent, profile: %{age: 0, origin: :spawned})

Profile.age(agent)                                  # => 0
Profile.get(agent, :origin)                         # => :spawned

# Evolve identity
{agent, []} = MyAgent.cmd(agent, {Jido.Identity.Actions.Evolve, %{years: 3}})
Profile.age(agent)                                  # => 3
```

### Thread Plugin

Append-only journal of what happened. Treat entries as **immutable facts**.

**Pattern for late metadata:** supply a stable `entry_id` up front, then append a follow-up entry pointing back via `refs`.

```elixir
alias Jido.Thread.Agent, as: ThreadAgent

entry_id = "entry_" <> Jido.Util.generate_id()

agent = ThreadAgent.append(agent, %{
  id: entry_id,
  kind: :message,
  payload: %{role: "assistant", content: "hello"}
})

# Later, when provider returns its remote_id:
agent = ThreadAgent.append(agent, %{
  kind: :message_committed,
  payload: %{provider: :slack, remote_id: slack_ts},
  refs: %{entry_id: entry_id}
})
```

This is the preferred way to model late acknowledgements, delivery receipts, retries, edits, deletes. Journal stays canonical and append-only.

### Memory Plugin

On-demand cognitive memory container. Organized into **spaces** — named containers holding map or list data. Reserved spaces: `:world`, `:tasks`.

```elixir
alias Jido.Memory.Agent, as: MemoryAgent

agent = MyAgent.new()
refute MemoryAgent.has_memory?(agent)

agent = MemoryAgent.ensure(agent)

# Map space
agent = MemoryAgent.put_in_space(agent, :world, :temperature, 22)
MemoryAgent.get_in_space(agent, :world, :temperature)   # => 22

# List space
agent = MemoryAgent.append_to_space(agent, :tasks, %{id: "t1", text: "Check sensor"})
```

Build domain wrappers on top of space primitives; don't invent new reserved keys.

### Overriding / Disabling Defaults

```elixir
# Disable one default
use Jido.Agent,
  name: "minimal",
  default_plugins: %{__identity__: false}

# Replace with custom module
use Jido.Agent,
  name: "custom",
  default_plugins: %{__identity__: MyApp.CustomIdentityPlugin}

# Replace with module + config
use Jido.Agent,
  name: "configured",
  default_plugins: %{__identity__: {MyApp.CustomIdentityPlugin, %{profile: %{age: 10}}}}

# Disable all defaults
use Jido.Agent,
  name: "bare",
  default_plugins: false
```

`default_plugins:` only controls **built-in** defaults. Use `plugins:` to add new plugins. A replacement Identity/Thread/Memory plugin must keep the same reserved state key, be singleton, and advertise the matching capability.

Pod-wrapped agents can replace the `:__pod__` plugin the same way, but must not disable it.

## Instance-level Default Plugins

`use Jido, default_plugins: ...` configures defaults for all agents bound to that instance. Agent-level `default_plugins:` overrides still apply.

## Composing Multiple Plugins

```elixir
defmodule MyAssistant do
  use Jido.Agent,
    name: "assistant",
    plugins: [
      MyApp.ChatPlugin,
      MyApp.MemoryPlugin,
      {MyApp.ToolsPlugin, %{enabled_tools: [:search, :calculator]}}
    ]
end
```

Each plugin keeps its own state slice and routing. Later plugins see earlier plugin state during `mount/2`.

## Source

- `jido/guides/plugins.md`
- `jido/guides/your-first-plugin.md`
- `jido/lib/jido/plugin.ex`, `jido/lib/jido/identity.ex`, `jido/lib/jido/thread.ex`, `jido/lib/jido/memory.ex`
