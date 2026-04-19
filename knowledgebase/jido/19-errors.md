# 19 — Errors & Error Policies

> Structured, Splode-based error types. Tagged tuples at boundaries. No raw strings/atoms in public APIs.

## Error Types (`Jido.Error.*`)

| Type | Fields |
|---|---|
| `ValidationError` | `message`, `kind: :input \| :action \| :sensor \| :config`, `subject`, `details` |
| `ExecutionError` | `message`, `phase: :execution \| :planning`, `details` |
| `RoutingError` | `message`, `target`, `details` |
| `TimeoutError` | `message`, `timeout_ms`, `details` |
| `CompensationError` | `message`, `original_error`, `compensated`, `details` |
| `InternalError` | `message`, `details` |

## Creating Errors

```elixir
Jido.Error.validation_error("Invalid email", field: :email)
Jido.Error.validation_error("Invalid config", kind: :config, subject: :timeout)
Jido.Error.execution_error("Action failed", phase: :execution)
Jido.Error.routing_error("No handler found", target: "user.created")
Jido.Error.timeout_error("Operation timed out", timeout: 5000)
Jido.Error.compensation_error("Rollback failed", original_error: err, compensated: false)
Jido.Error.internal_error("Unexpected failure", details: %{module: MyModule})
```

All functions accept `:details` keyword for free-form structured data.

## Returning Errors from Actions

```elixir
def run(params, _context) do
  case validate(params) do
    {:ok, data} -> {:ok, %{processed: data}}
    {:error, reason} ->
      {:error, Jido.Error.validation_error("Invalid", field: :param_name)}
  end
end
```

Schema validation errors are **auto-wrapped**:

```
{:error, %Jido.Error.ValidationError{message: "Invalid parameters...", kind: :input}}
```

## `Directive.Error` (wrapper for agent-level errors)

When `cmd/2` produces an error, the strategy wraps it in a `Directive.Error`:

```elixir
%Jido.Agent.Directive.Error{
  error: %Jido.Error.ExecutionError{...},
  context: :instruction  # or :normalize | :fsm_transition | :routing | :plugin_handle_signal
}
```

Helper constructor:

```elixir
Directive.error(Jido.Error.validation_error("Invalid input"))
```

The `AgentServer` receives these via the directive queue, then applies the error policy.

## Error Policies (`AgentServer` option)

Configured via `AgentServer.start_link(agent: MyAgent, error_policy: ...)` (and by extension `MyApp.Jido.start_agent(MyAgent, error_policy: ...)`):

| Policy | Behavior |
|---|---|
| `:log_only` (default) | Log error, continue processing |
| `:stop_on_error` | Log, stop agent |
| `{:max_errors, n}` | Stop after n errors |
| `{:emit_signal, dispatch_cfg}` | Emit error signal via dispatch |
| Custom function `fun/2` | `fn %Directive.Error{error: err, context: ctx}, state -> {:ok, state} \| {:stop, reason, state} end` |

```elixir
MyApp.Jido.start_agent(MyAgent,
  id: "a-1",
  error_policy: {:max_errors, 3}
)
```

## Error Flow

```
Action fails
  ↓
Strategy wraps in %Directive.Error{context: :instruction}
  ↓
Returned from cmd/2 in directives list
  ↓
AgentServer queues directives
  ↓
DirectiveExec dispatches error directive to error policy
  ↓
Policy decides: log / stop / emit / custom handler
```

## Utilities

```elixir
Jido.Error.to_map(error)
# => %{type: :validation_error, message: "...", details: %{}, stacktrace: [...]}

Jido.Error.extract_message(error)    # => string
```

## Testing Errors

### Pure action test

```elixir
result = Jido.Action.run(ProcessOrder, %{order_id: "invalid"}, %{})
assert {:error, %Jido.Error.ValidationError{}} = result
```

### cmd/2 error directive test

```elixir
{_agent, [error_directive]} = MyAgent.cmd(agent, {FailingAction, %{}})
assert %Jido.Agent.Directive.Error{error: %Jido.Error.ExecutionError{}} = error_directive
```

### Error policy test

Send signals that cause errors, assert agent stops at threshold or keeps counts.

```elixir
test "stops after 3 errors" do
  {:ok, pid} = MyApp.Jido.start_agent(MyAgent, error_policy: {:max_errors, 3})
  ref = Process.monitor(pid)

  for _ <- 1..3 do
    Jido.AgentServer.cast(pid, Jido.Signal.new!("cause_error", %{}, source: "/test"))
  end

  assert_receive {:DOWN, ^ref, :process, ^pid, _}, 1000
end
```

## Cross-Package Error Mapping

When errors originate in `jido_action` / `jido_signal`, they get normalized:

| Source | Normalized to |
|---|---|
| `Jido.Action.Error.InvalidInputError` | `:validation_error` |
| `Jido.Action.Error.ExecutionFailureError` | `:execution_error` |
| `Jido.Signal.Error.RoutingError` | `:routing_error` |

## Source

- `jido/guides/errors.md`
- `jido/lib/jido/error.ex`, `jido/lib/jido/error/**`
- `jido/lib/jido/agent/directive/error.ex`
- `jido/lib/jido/agent_server/error_policy.ex`
