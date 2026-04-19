# 14 — Orphans & Adoption

> An **advanced exception**, not the default lifecycle story. Use when a live child must outlast its logical parent coordinator. For durable lifecycle, use `InstanceManager` / `Pod` instead.

## Parent Death Policies

Set via `Directive.spawn_agent(Mod, tag, opts: %{on_parent_death: ...})`:

| Value | Behavior |
|---|---|
| `:stop` (default) | Child stops when parent dies |
| `:continue` | Child stays alive, orphaned silently |
| `:emit_orphan` | Child stays alive, orphaned, receives `jido.agent.orphaned` signal |

## Lifecycle States

| State | `state.parent` | `agent.state.__parent__` | `state.orphaned_from` | `agent.state.__orphaned_from__` |
|---|---|---|---|---|
| Attached | `%ParentRef{}` | `%ParentRef{}` | `nil` | `nil` |
| Orphaned | `nil` | `nil` | `%ParentRef{}` | `%ParentRef{}` |
| Standalone | `nil` | `nil` | `nil` | `nil` |

## On Orphan Transition

1. `state.parent` cleared
2. `agent.state.__parent__` cleared
3. `state.orphaned_from` populated with former `ParentRef`
4. `agent.state.__orphaned_from__` populated with former `ParentRef`
5. `Directive.emit_to_parent/3` starts returning `nil`
6. If `:emit_orphan`, agent receives a `jido.agent.orphaned` signal **after** detachment

### `jido.agent.orphaned` signal data

- `parent_id` — former parent's agent id
- `parent_pid` — former parent pid
- `tag` — this child's tag under the former parent
- `meta` — metadata from `spawn_agent/3`
- `reason` — exit reason

## Adoption (`Directive.adopt_child/3`)

```elixir
Directive.adopt_child("worker-123", :new_tag)
Directive.adopt_child(child_pid, :recovered_worker, meta: %{restored: true})
```

Rules:
- Resolves child by child_id (within the caller's partition) or pid
- Child **must be unattached** — adoption rejects if already attached
- Rejects tag collisions within the new parent
- Installs fresh `ParentRef` and monitor
- Clears orphan markers on the child
- Restores `emit_to_parent/3` semantics
- Mirrors new binding into `Jido.RuntimeStore` — future restarts of this child rebind to the adopted parent, not the startup parent

## `emit_to_parent/3` is Strict

- Works **only** while `agent.state.__parent__` is present
- Returns `nil` for standalone agents
- Returns `nil` for orphaned agents

This prevents stale routing to a dead coordinator. Do not re-read a saved parent pid and `send/2` it — use `emit_to_parent/3`, which returns `nil` when detached.

If a child needs to remember where it came from after orphaning:
- Read `agent.state.__orphaned_from__` to inspect the former parent
- Handle `jido.agent.orphaned` for an event-driven reaction

## When to Use Orphan Survival

Reach for it when:
- In-flight work must survive coordinator death
- Reattachment is explicit business logic
- A replacement coordinator should resume ownership

Do **not** use it as a substitute for:
- Durable keyed lifecycle → use `InstanceManager`
- Named team with topology → use `Pod`
- Hibernate/thaw → use `InstanceManager` or `Pod` (both are durable)

## Jido Does NOT Auto-Reconnect on Parent Restart

Adoption is manual. If you want "when a new parent starts, adopt orphans from the old parent", implement that in your orchestration layer using `Jido.get_children/1` / `Jido.list_agents/2` / `Jido.parent_binding/3`.

## Replacement Coordinator Pattern

```elixir
# Child spawned with orphan emit
Directive.spawn_agent(WorkerAgent, :tag, opts: %{
  id: "worker-1",
  on_parent_death: :emit_orphan
})

# Later: parent dies. Replacement parent comes up:
{:ok, new_parent_pid} = MyApp.Jido.start_agent(ParentAgent, id: "parent-2")

# Explicit adoption
{:ok, _} = Jido.AgentServer.call(
  new_parent_pid,
  Signal.new!("adopt_child", %{child: "worker-1", tag: :tag}, source: "/ops")
)
```

Where `adopt_child` is a signal route on your ParentAgent that returns `Directive.adopt_child("worker-1", :tag)`.

## Testing Orphan Lifecycle

Verify:
- `state.parent` and `agent.state.__parent__` cleared
- `state.orphaned_from` and `agent.state.__orphaned_from__` populated
- `Directive.emit_to_parent/3` returns `nil` while orphaned
- `jido.agent.orphaned` handlers see detached state
- `Directive.adopt_child/3` restores `Jido.get_children/1` and child→parent messaging
- Adopted-child restart binds to the adopted parent, not stale startup metadata

Full acceptance test: `jido/test/examples/runtime/orphan_lifecycle_test.exs`.

## `Jido.RuntimeStore` Notes

- Instance-local, ephemeral ETS table
- Persists through process restarts (via framework's restart hooks)
- Resets when the Jido instance supervisor stops
- Stores current logical parent binding for each child — used to rebind after child restart

Fetch runtime bindings:

```elixir
{:ok, binding} = Jido.parent_binding(MyApp.Jido, "child-123")
# binding.parent_id, .parent_partition, .tag, .meta
```

## Source

- `jido/guides/orphans.md`
- `jido/guides/runtime.md` (parent-child section)
- `jido/guides/orchestration.md`
- `jido/lib/jido/runtime_store.ex`
