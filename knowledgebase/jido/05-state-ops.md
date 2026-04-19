# 05 — State Operations

> StateOps are **internal** state transitions applied by the strategy layer during `cmd/2`. Unlike directives, they never reach the runtime.

## The Table

| StateOp | Purpose | Use When |
|---|---|---|
| `SetState` | Deep merge attributes into state | Adding/updating fields while preserving others |
| `ReplaceState` | Replace state wholesale | Full reset, blob replacement |
| `DeleteKeys` | Remove top-level keys | Clearing ephemeral/temporary data |
| `SetPath` | Set value at nested path | Targeted nested updates; list append |
| `DeletePath` | Delete value at nested path | Removing specific nested keys |

## Usage

```elixir
alias Jido.Agent.StateOp

# Structs
{:ok, %{result: "done"}, [
  %StateOp.SetState{attrs: %{status: :completed}},
  %StateOp.SetPath{path: [:metrics, :count], value: 42}
]}

# Constructor helpers
{:ok, %{}, [
  StateOp.set_state(%{status: :running}),
  StateOp.set_path([:metrics, :requests, :total], 1000),
  StateOp.replace_state(%{fresh: true}),
  StateOp.delete_keys([:temp, :cache]),
  StateOp.delete_path([:temp, :cache, :stale_entry])
]}
```

## Semantics

- **Applied in order.** Later ops can overwrite earlier ones.
- **Before directives.** The strategy applies StateOps during `cmd/2`; directives pass through afterward.
- **Schema validation runs after StateOps.** An invalid SetState can fail validation downstream.

## SetState — Deep Merge

Uses `DeepMerge.deep_merge/2`. Nested maps merge recursively.

```elixir
# Before: %{counter: 10, metadata: %{author: "alice"}}
%StateOp.SetState{attrs: %{metadata: %{version: "2.0"}}}
# After:  %{counter: 10, metadata: %{author: "alice", version: "2.0"}}
```

**Lists are replaced, not concatenated:**

```elixir
# Before: %{items: [1, 2, 3]}
%StateOp.SetState{attrs: %{items: [4, 5]}}
# After:  %{items: [4, 5]}    # NOT [1, 2, 3, 4, 5]
```

Use `SetPath` with explicit list manipulation to append:

```elixir
current = context.state[:items] || []
%StateOp.SetPath{path: [:items], value: current ++ [4, 5]}
```

## ReplaceState — Full Replacement

```elixir
%StateOp.ReplaceState{state: %{status: :idle, counter: 0}}
```

Use for full reset, blob replacement, guaranteeing no stale keys remain.

## DeleteKeys — Top-Level Removal

```elixir
# Before: %{counter: 5, temp: "data", cache: %{items: []}}
%StateOp.DeleteKeys{keys: [:temp, :cache]}
# After:  %{counter: 5}
```

Safe with non-existent keys (no-op).

## SetPath / DeletePath — Nested Updates

### SetPath — creates intermediate maps

```elixir
# Before: %{config: %{}}
%StateOp.SetPath{path: [:config, :database, :timeout], value: 5000}
# After:  %{config: %{database: %{timeout: 5000}}}
```

**Overwrites non-map intermediates:**

```elixir
# Before: %{config: "not a map"}
%StateOp.SetPath{path: [:config, :timeout], value: 5000}
# After:  %{config: %{timeout: 5000}}   # string is gone
```

### DeletePath — uses `pop_in/2`

```elixir
%StateOp.DeletePath{path: [:config, :credentials, :api_key]}
```

Handles non-existent paths gracefully (no-op if intermediate keys missing).

## Cookbook

### Append to a list

```elixir
def run(%{message: msg}, context) do
  current = get_in(context.state, [:messages]) || []
  {:ok, %{}, %StateOp.SetPath{path: [:messages], value: current ++ [msg]}}
end
```

### Increment a deeply nested counter

```elixir
def run(%{amount: amount}, context) do
  current = get_in(context.state, [:metrics, :requests, :count]) || 0
  {:ok, %{}, %StateOp.SetPath{path: [:metrics, :requests, :count], value: current + amount}}
end
```

### Conditional updates

```elixir
def run(%{item: item}, context) do
  pending = Map.get(context.state, :pending_items, [])

  if item.priority == :high do
    {:ok, %{processed: item.id}, [
      %StateOp.SetState{attrs: %{last_high_priority: DateTime.utc_now()}},
      %StateOp.SetPath{path: [:pending_items], value: pending -- [item]}
    ]}
  else
    {:ok, %{queued: item.id},
     %StateOp.SetPath{path: [:pending_items], value: pending ++ [item]}}
  end
end
```

### Mix with directives in one return

```elixir
{:ok, %{completed_at: DateTime.utc_now()}, [
  %StateOp.SetState{attrs: %{status: :completed}},
  %StateOp.DeleteKeys{keys: [:temp, :in_progress_data]},
  %StateOp.SetPath{path: [:metrics, :completed_count], value: 1},
  Directive.emit(completion_signal)
]}
```

StateOps get applied before `cmd/2` returns; the `Emit` directive goes to the runtime after.

## Gotchas Summary

1. **Deep-merge replaces lists** → use `SetPath`.
2. **`SetPath` overwrites non-map intermediates** → no error, but data lost.
3. **Validation runs after StateOps** → bad types can fail downstream.
4. **`DeletePath` with missing intermediates is a no-op** → no error raised.
5. **Order matters** → later ops overwrite earlier ones in the same return.

## Source

- `jido/guides/state-ops.md`
- `jido/lib/jido/agent/state_op.ex`
- `Jido.Agent.StateOp` moduledoc for complete API
