# 01 — Agents

> Agents are immutable structs with a schema, a strategy, and a `cmd/2` function. Runtime concerns live in `AgentServer` ([06](06-runtime.md)), not here.

## Minimal Definition

```elixir
defmodule MyApp.CounterAgent do
  use Jido.Agent,
    name: "counter",                          # required, alphanumeric + underscores
    description: "A simple counter agent",    # optional
    category: "example",                      # optional
    tags: ["demo"],                           # default: []
    vsn: "1.0.0",                             # optional
    schema: [count: [type: :integer, default: 0]],
    strategy: Jido.Agent.Strategy.Direct,     # default
    plugins: [],                              # extra plugins (see [08])
    default_plugins: true,                    # Identity/Thread/Memory (see [08])
    schedules: [],                            # declarative cron (see [15])
    signal_routes: [                          # static {type, Action}
      {"increment", MyApp.Actions.Increment}
    ]
end
```

## The `cmd/2` / `cmd/3` Contract

```elixir
{agent, directives} = MyAgent.cmd(agent, action)
{agent, directives} = MyAgent.cmd(agent, action, opts)
```

Invariants: the returned `agent` is complete; `directives` describe external effects; pure function.

### Action formats accepted

```elixir
MyAgent.cmd(agent, MyAction)                                    # module only
MyAgent.cmd(agent, {MyAction, %{value: 42}})                    # module + params
MyAgent.cmd(agent, {MyAction, %{value: 42}, %{user_id: 123}})   # + context
MyAgent.cmd(agent, {MyAction, %{value: 42}, %{}, [timeout: 5000]}) # + per-instr opts
MyAgent.cmd(agent, %Instruction{action: MyAction, params: %{}}) # full struct
MyAgent.cmd(agent, [Action1, {Action2, %{x: 1}}])               # sequence
```

### `cmd/3` options

Apply to every action in the command:

- `:timeout` — ms per action
- `:max_retries` — max retry attempts on failure
- `:backoff` — initial backoff ms (doubles with each retry)

## Creating Agents

```elixir
agent = MyAgent.new()
agent = MyAgent.new(id: "custom-id")
agent = MyAgent.new(state: %{counter: 10})
```

`new/1` initializes strategy state via `strategy.init/2` (any directives returned by strategy init are dropped — they need a runtime; `AgentServer` handles them at startup).

## State Management

```elixir
{:ok, agent} = MyAgent.set(agent, %{status: :running})     # deep merge
{:ok, agent} = MyAgent.set(agent, counter: 5)              # keyword form
{:ok, agent} = MyAgent.validate(agent)                     # keeps extras
{:ok, agent} = MyAgent.validate(agent, strict: true)       # drop non-schema fields
```

## Lifecycle Hooks (optional, pure)

### `on_before_cmd/2`

Called **before** action processing. Transform agent or action.

```elixir
def on_before_cmd(agent, action) do
  {:ok, agent} = set(agent, %{last_action: inspect(action)})
  {:ok, agent, action}
end
```

Uses: mirror action params into state, set default params, enforce invariants.

### `on_after_cmd/3`

Called **after** action processing. Transform agent or directives.

```elixir
def on_after_cmd(agent, action, directives) do
  {:ok, agent} = validate(agent)
  {:ok, agent, directives}
end
```

Uses: auto-validate, derive computed fields, invariant checks.

Both hooks must remain pure. For side effects, return a directive.

## Schemas

Two equivalent formats are accepted on `use Jido.Agent`:

```elixir
# Zoi (preferred for new code)
schema: Zoi.object(%{
  status: Zoi.atom() |> Zoi.default(:idle),
  counter: Zoi.integer() |> Zoi.default(0),
  config: Zoi.map() |> Zoi.default(%{})
})

# NimbleOptions (legacy, still supported)
schema: [
  status: [type: :atom, default: :idle],
  counter: [type: :integer, default: 0],
  config: [type: {:map, :atom, :string}, default: %{}]
]
```

## Persistence Callbacks (optional)

If persistence is configured ([10-persistence.md](10-persistence.md)), agents can customise serialization:

```elixir
@impl true
def checkpoint(agent, _ctx) do
  thread = agent.state[:__thread__]
  {:ok, %{
    version: 1,
    agent_module: __MODULE__,
    id: agent.id,
    state: Map.drop(agent.state, [:__thread__, :temp_cache]),
    thread: thread && %{id: thread.id, rev: thread.rev}
  }}
end

@impl true
def restore(data, _ctx) do
  case new(id: data[:id] || data["id"]) do
    {:ok, agent} ->
      state = data[:state] || data["state"] || %{}
      {:ok, %{agent | state: Map.merge(agent.state, state)}}
    error -> error
  end
end
```

Default implementations exist — only override when you need to skip fields or migrate schemas.

## Internal State Keys (reserved)

| Key | Purpose | Guide |
|---|---|---|
| `:__thread__` | Thread journal (stripped from checkpoint state) | [10](10-persistence.md) |
| `:__identity__` | Identity plugin profile | [08](08-plugins.md) |
| `:__memory__` | Memory plugin spaces | [08](08-plugins.md) |
| `:__pod__` | Pod topology snapshot (pod-wrapped agents) | [11](11-pods.md) |
| `:__parent__` | `%ParentRef{}` for attached child agents | [14](14-orphans-adoption.md) |
| `:__orphaned_from__` | Former parent ref after orphaning | [14](14-orphans-adoption.md) |
| `:__strategy__` | Strategy-specific state | [07](07-strategies.md) |
| `:__cron_specs__` | Persisted dynamic cron manifest | [15](15-scheduling.md) |
| `:__partition__` | Partition binding for multi-tenancy | [12](12-multi-tenancy.md) |

Don't write to these directly — they're managed by framework machinery.

## When to Use `Jido.Agent` vs `Jido.Pod`

If the module is primarily a durable coordinator for named collaborators with a topology, use `Jido.Pod` ([11](11-pods.md)). It wraps the Agent model and injects the `:__pod__` singleton plugin.

## Source

- `jido/lib/jido/agent.ex`
- `jido/guides/agents.md`
- `jido/guides/core-loop.md`
