# 02 — Actions

> Actions live in the `jido_action` package. They receive validated params + context, return state updates + optional directives. Actions may perform side effects (HTTP, DB, file I/O).

## Minimal Definition

```elixir
defmodule MyApp.Actions.Increment do
  use Jido.Action,
    name: "increment",
    description: "Increments the counter",
    schema: [amount: [type: :integer, default: 1]]

  def run(params, context) do
    current = Map.get(context.state, :counter, 0)
    {:ok, %{counter: current + params.amount}}
  end
end
```

## The `run/2` Contract

```elixir
def run(params, context) do
  # params: validated map matching your schema (defaults applied)
  # context: %{state: map(), agent: t() (when called via emit_to_parent)}
  # returns: one of the return shapes below
end
```

## Return Shapes

### 1. State updates only (deep-merged into `agent.state`)

```elixir
{:ok, %{counter: 10}}
```

### 2. State updates + directive(s)

```elixir
{:ok, %{status: :done}, %Directive.Emit{signal: signal}}
{:ok, %{triggered: true}, [
  Directive.emit(signal),
  Directive.schedule(1000, :check)
]}
```

### 3. State updates + StateOps + directives (mixed list)

```elixir
alias Jido.Agent.{Directive, StateOp}

{:ok, %{order_id: id}, [
  %StateOp.SetState{attrs: %{last_order: id}},
  Directive.emit(signal)
]}
```

The strategy applies StateOps during `cmd/2`; the runtime interprets directives afterward. See [05-state-ops.md](05-state-ops.md).

### 4. Errors

```elixir
{:error, "Failed to read file: #{inspect(reason)}"}
{:error, Jido.Error.validation_error("Invalid email", field: :email)}
```

Schema validation errors are auto-wrapped into `%Jido.Error.ValidationError{kind: :input}`.

## Reading State

```elixir
def run(%{amount: amount}, context) do
  current = Map.get(context.state, :counter, 0)
  {:ok, %{counter: current + amount}}
end

# Or pattern-match in the head:
def run(%{amount: amount}, %{state: %{counter: current}}) do
  {:ok, %{counter: current + amount}}
end
```

## Emitting Directives (helpers)

```elixir
alias Jido.Agent.Directive

Directive.emit(signal)                           # default dispatch
Directive.emit(signal, {:pubsub, topic: "events"})
Directive.emit_to_pid(signal, pid)
Directive.emit_to_parent(agent, signal)          # child → parent; returns nil if orphaned
Directive.spawn_agent(Module, :tag)
Directive.spawn_agent(Module, :tag, opts: %{initial_state: %{}}, meta: %{...})
Directive.spawn_agent(Module, :durable, restart: :permanent)
Directive.stop_child(:tag, :normal)
Directive.adopt_child("child-id", :tag, meta: %{...})
Directive.schedule(5_000, :timeout)
Directive.cron("*/5 * * * *", :tick, job_id: :heartbeat)
Directive.cron_cancel(:heartbeat)
Directive.run_instruction(instruction, result_action: :some_internal_action)
Directive.stop()
Directive.stop(:shutdown)
Directive.error(Jido.Error.validation_error("Invalid input"))
```

See [04-directives.md](04-directives.md) for full semantics.

## Plugin State Scope

When actions target plugin-owned state, nest under the plugin's `state_key`:

```elixir
# ChatPlugin has state_key: :chat
# agent.state = %{counter: 0, chat: %{history: []}}

def run(%{message: msg}, context) do
  history = get_in(context.state, [:chat, :history]) || []
  {:ok, %{chat: %{history: history ++ [msg]}}}
end
```

Lists are **replaced**, not concatenated, by deep-merge. Use `StateOp.SetPath` for list append:

```elixir
current = context.state[:items] || []
{:ok, %{}, %StateOp.SetPath{path: [:items], value: current ++ [new_item]}}
```

## Schema Options (NimbleOptions)

```elixir
schema: [
  order_id: [type: :string, required: true],
  amount: [type: :integer, default: 1],
  priority: [type: {:in, [:low, :medium, :high]}, default: :medium],
  metadata: [type: :map, default: %{}],
  tags: [type: {:list, :string}, default: []]
]
```

Common types: `:string`, `:integer`, `:atom`, `:map`, `{:list, :type}`, `{:in, values}`, `{:or, [:string, nil]}`.

For new code, prefer Zoi (same as agents/plugins).

## Testing Actions

```elixir
# Pure test — no runtime
result = MyApp.Actions.Increment.run(%{amount: 5}, %{state: %{counter: 0}})
assert {:ok, %{counter: 5}} = result

# Via an agent
agent = MyApp.CounterAgent.new()
{agent, directives} = MyApp.CounterAgent.cmd(agent, {MyApp.Actions.Increment, %{amount: 5}})
assert agent.state.counter == 5
```

See [20-testing.md](20-testing.md).

## Further Reading

- [jido_action HexDocs](https://hexdocs.pm/jido_action) — full schema options, validation, composition
- [04-directives.md](04-directives.md) — every directive
- [05-state-ops.md](05-state-ops.md) — StateOp details and cookbook
- `jido/guides/actions.md`
