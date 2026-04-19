# 20 — Testing

> Two layers: **pure agent tests** (no runtime) and **integration tests** with `JidoTest.Case`. Never use `Process.sleep`.

## Test Isolation: `JidoTest.Case`

Provides a per-test Jido instance with isolated Registry, TaskSupervisor, AgentSupervisor. Works with `async: true`.

```elixir
defmodule MyAgentTest do
  use JidoTest.Case, async: true

  test "starts agent under isolated instance", %{jido: jido} do
    {:ok, pid} = Jido.start_agent(jido, MyAgent)
    assert Process.alive?(pid)
  end
end
```

### Context keys

- `:jido` — atom name of the Jido instance
- `:jido_pid` — supervisor pid

### Helper functions

```elixir
{:ok, pid} = start_test_agent(context, MyAgent, id: "test-1")
registry = test_registry(context)
task_sup = test_task_supervisor(context)
agent_sup = test_agent_supervisor(context)
```

## Pure Agent Tests (preferred first layer)

Agents are immutable structs — test `cmd/2` directly without a runtime:

```elixir
defmodule CounterAgentTest do
  use ExUnit.Case, async: true

  alias MyApp.CounterAgent
  alias MyApp.Actions.{Increment, Decrement}

  test "increment updates counter" do
    agent = CounterAgent.new()
    assert agent.state.counter == 0

    {agent, directives} = CounterAgent.cmd(agent, {Increment, %{by: 5}})

    assert agent.state.counter == 5
    assert directives == []
  end

  test "decrement reduces counter" do
    agent = CounterAgent.new(state: %{counter: 10})
    {agent, _} = CounterAgent.cmd(agent, Decrement)
    assert agent.state.counter == 9
  end

  test "multiple actions in sequence" do
    agent = CounterAgent.new()
    {agent, _} = CounterAgent.cmd(agent, [
      {Increment, %{by: 10}},
      {Decrement, %{}},
      {Increment, %{by: 5}}
    ])
    assert agent.state.counter == 14
  end

  test "action can emit signal directive" do
    agent = CounterAgent.new()
    {_agent, directives} = CounterAgent.cmd(agent, NotifyAction)
    assert [%Jido.Agent.Directive.Emit{signal: signal}] = directives
    assert signal.type == "counter.updated"
  end
end
```

### Validation

```elixir
test "validate/2 enforces schema" do
  agent = MyAgent.new(state: %{status: :running, extra: "data"})

  {:ok, validated} = MyAgent.validate(agent)
  assert validated.state.extra == "data"

  {:ok, strict} = MyAgent.validate(agent, strict: true)
  refute Map.has_key?(strict.state, :extra)
end
```

### `set/2`

```elixir
test "set/2 deep merges state" do
  agent = MyAgent.new(state: %{config: %{a: 1, b: 2}})
  {:ok, updated} = MyAgent.set(agent, %{config: %{b: 3, c: 4}})
  assert updated.state.config == %{a: 1, b: 3, c: 4}
end
```

## Integration Tests (runtime involvement)

```elixir
defmodule AgentIntegrationTest do
  use JidoTest.Case, async: true
  alias Jido.{AgentServer, Signal}

  test "synchronous call returns updated agent", %{jido: jido} do
    {:ok, pid} = AgentServer.start_link(agent: CounterAgent, jido: jido)
    signal = Signal.new!("increment", %{by: 5}, source: "/test")
    {:ok, agent} = AgentServer.call(pid, signal)
    assert agent.state.counter == 5
  end

  test "multiple signals in sequence", %{jido: jido} do
    {:ok, pid} = AgentServer.start_link(agent: CounterAgent, jido: jido)

    for _ <- 1..5 do
      signal = Signal.new!("increment", %{}, source: "/test")
      {:ok, _} = AgentServer.call(pid, signal)
    end

    {:ok, state} = AgentServer.state(pid)
    assert state.agent.state.counter == 5
  end

  test "starts with pre-built agent", %{jido: jido} do
    agent = CounterAgent.new(id: "prebuilt-123")
    agent = %{agent | state: Map.put(agent.state, :counter, 50)}

    {:ok, pid} = AgentServer.start_link(
      agent: agent,
      agent_module: CounterAgent,
      jido: jido
    )

    {:ok, state} = AgentServer.state(pid)
    assert state.id == "prebuilt-123"
    assert state.agent.state.counter == 50
  end
end
```

## Await Patterns (never `Process.sleep`)

```elixir
test "await waits for agent completion", %{jido: jido} do
  {:ok, pid} = Jido.start_agent(jido, WorkerAgent)
  AgentServer.cast(pid, Signal.new!("start_work", %{}, source: "/test"))

  {:ok, result} = Jido.await(pid, 10_000)
  assert result.status == :completed
  assert result.result == "done"
end

test "await_child waits for spawned child", %{jido: jido} do
  {:ok, parent} = Jido.start_agent(jido, CoordinatorAgent)
  {:ok, _} = AgentServer.call(parent,
    Signal.new!("spawn_worker", %{tag: :worker_1}, source: "/test"))

  {:ok, result} = Jido.await_child(parent, :worker_1, 30_000)
  assert result.status == :completed
end

test "await_all", %{jido: jido} do
  pids = for i <- 1..3 do
    {:ok, pid} = Jido.start_agent(jido, WorkerAgent, id: "worker-#{i}")
    AgentServer.cast(pid, Signal.new!("start", %{}, source: "/test"))
    pid
  end

  {:ok, results} = Jido.await_all(pids, 30_000)
  assert map_size(results) == 3
end

test "await_any — first to complete", %{jido: jido} do
  pids = for i <- 1..3 do
    {:ok, pid} = Jido.start_agent(jido, WorkerAgent, id: "racer-#{i}")
    AgentServer.cast(pid, Signal.new!("start", %{delay: i * 100}, source: "/test"))
    pid
  end

  {:ok, {winner, result}} = Jido.await_any(pids, 10_000)
  assert winner in pids
  assert result.status == :completed
end

test "await returns timeout error", %{jido: jido} do
  {:ok, pid} = Jido.start_agent(jido, SlowAgent)
  AgentServer.cast(pid, Signal.new!("slow_work", %{}, source: "/test"))
  assert {:error, :timeout} = Jido.await(pid, 100)
end
```

## Mocking External Dependencies (Mimic)

### Setup

```elixir
# test/test_helper.exs
Mimic.copy(MyApp.ExternalService)
Mimic.copy(MyApp.HttpClient)
ExUnit.start()
```

### Expect / Stub / Reject

```elixir
use Mimic

test "expect a single call", %{jido: jido} do
  expect(MyApp.ExternalService, :call, fn args ->
    assert args == %{query: "test"}
    {:ok, "mocked response"}
  end)

  {:ok, pid} = Jido.start_agent(jido, MyAgent)
  signal = Signal.new!("fetch_data", %{query: "test"}, source: "/test")
  {:ok, agent} = AgentServer.call(pid, signal)

  assert agent.state.result == "mocked response"
end

test "stub returns consistent value", %{jido: jido} do
  stub(MyApp.HttpClient, :get, fn _url ->
    {:ok, %{status: 200, body: "stubbed"}}
  end)
  # multiple calls, all return stubbed value
end

test "verifies service was called N times", %{jido: jido} do
  expect(MyApp.ExternalService, :call, 2, fn _args -> {:ok, "result"} end)
  # Mimic auto-verifies expect count at test end
end

test "service should NOT be called", %{jido: jido} do
  reject(&MyApp.ExternalService.call/1)
  # Test asserts agent uses cache/other path
end
```

## Testing Parent-Child Hierarchies

```elixir
test "child receives parent reference", %{jido: jido} do
  {:ok, parent_pid} = AgentServer.start_link(
    agent: ParentAgent, id: "parent-1", jido: jido
  )

  parent_ref = Jido.AgentServer.ParentRef.new!(%{
    pid: parent_pid, id: "parent-1", tag: :worker
  })

  {:ok, child_pid} = AgentServer.start_link(
    agent: ChildAgent, id: "child-1", parent: parent_ref, jido: jido
  )

  {:ok, child_state} = AgentServer.state(child_pid)
  assert child_state.parent.pid == parent_pid
  assert child_state.parent.id == "parent-1"
end
```

### Orphan lifecycle (full acceptance test pattern)

```elixir
test "child becomes orphaned and can be adopted", %{jido: jido} do
  {:ok, parent_pid} = Jido.start_agent(jido, ParentAgent, id: "parent-1")

  {:ok, _} = AgentServer.call(parent_pid,
    Signal.new!("spawn_agent", %{
      module: ChildAgent, tag: :worker,
      opts: %{id: "worker-1", on_parent_death: :emit_orphan}
    }, source: "/test"))

  eventually(fn ->
    {:ok, children} = Jido.get_children(parent_pid)
    Map.has_key?(children, :worker)
  end)

  {:ok, children} = Jido.get_children(parent_pid)
  child_pid = children.worker

  DynamicSupervisor.terminate_child(Jido.agent_supervisor_name(jido), parent_pid)

  eventually_state(child_pid, fn state ->
    state.parent == nil and
      Map.get(state.agent.state, :__parent__) == nil and
      state.orphaned_from.id == "parent-1"
  end)

  {:ok, replacement_pid} = Jido.start_agent(jido, ParentAgent, id: "parent-2")

  {:ok, _} = AgentServer.call(replacement_pid,
    Signal.new!("adopt_child", %{child: "worker-1", tag: :worker}, source: "/test"))

  eventually(fn ->
    {:ok, children} = Jido.get_children(replacement_pid)
    Map.get(children, :worker) == child_pid
  end)
end
```

Orphan lifecycle tests should verify:
- `state.parent` + `agent.state.__parent__` cleared
- `state.orphaned_from` + `agent.state.__orphaned_from__` populated
- `Directive.emit_to_parent/3` returns `nil` while orphaned
- `jido.agent.orphaned` handlers see detached state
- `Directive.adopt_child/3` restores `Jido.get_children/1`
- Adopted-child restart binds to adopted parent, not stale startup metadata

Full reference: `jido/test/examples/runtime/orphan_lifecycle_test.exs`.

## `JidoTest.Eventually` Helpers

Use instead of `Process.sleep` for async assertions:

```elixir
eventually(fn -> some_condition?() end, timeout: 5_000, interval: 50)

eventually_state(agent_pid, fn state ->
  state.agent.state.counter == 10
end)
```

## Testing Directives

```elixir
test "Schedule directive fires after delay", %{jido: jido} do
  {:ok, pid} = AgentServer.start_link(agent: SchedulerAgent, jido: jido)
  {:ok, _} = AgentServer.call(pid, Signal.new!("schedule_ping", %{}, source: "/test"))

  eventually_state(pid, fn s -> s.agent.state.received_ping == true end)
end

test "Stop directive terminates agent", %{jido: jido} do
  {:ok, pid} = AgentServer.start_link(agent: MyAgent, jido: jido)
  ref = Process.monitor(pid)
  {:ok, _} = AgentServer.call(pid, Signal.new!("shutdown", %{}, source: "/test"))
  assert_receive {:DOWN, ^ref, :process, ^pid, :normal}, 1000
end
```

## Debug-Based Diagnosis in Tests

```elixir
test "diagnose agent behavior", %{jido: jido} do
  Jido.Debug.enable(jido, :on)

  {:ok, pid} = Jido.start_agent(jido, MyAgent)
  AgentServer.cast(pid, Signal.new!("process", %{}, source: "/test"))

  eventually_state(pid, fn s -> s.agent.state.status == :completed end)

  {:ok, events} = Jido.AgentServer.recent_events(pid)
  IO.inspect(events, label: "debug events")
end
```

**Important:** reset debug in `on_exit` — `:persistent_term` leaks:

```elixir
setup %{jido: jido} = context do
  Jido.Debug.reset(jido)
  on_exit(fn -> Jido.Debug.reset(jido) end)
  context
end
```

## Summary

| Scenario | Approach |
|---|---|
| State transformations | Pure `cmd/2` tests, no runtime |
| Signal processing | `JidoTest.Case` + `AgentServer.call/cast` |
| Async coordination | `Jido.await/2`, `Jido.await_child/4`, `eventually/1` |
| External dependencies | Mimic `expect`/`stub`/`reject` |
| Test isolation | `JidoTest.Case` per-test instances |

## Source

- `jido/guides/testing.md`
- `jido/test/AGENTS.md`
- `jido/test/support/**` (JidoTest.Case, JidoTest.Eventually)
