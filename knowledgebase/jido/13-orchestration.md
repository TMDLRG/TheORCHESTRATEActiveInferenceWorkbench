# 13 — Multi-Agent Orchestration

> How Jido handles parallel, hierarchical, and fan-out work. **Ephemeral** via `SpawnAgent`; **durable** via Pods ([11](11-pods.md)) or `InstanceManager` ([10](10-persistence.md)).

## The Pattern (ephemeral `SpawnAgent`)

1. Parent spawns children via `SpawnAgent` directive
2. Parent receives `jido.agent.child.started` signal
3. Parent sends work via `emit_to_pid/2`
4. Children process, reply via `emit_to_parent/3`
5. Parent aggregates, continues

```
Parent (Coordinator)
  |
  |-- SpawnAgent(:worker_1) ------> Worker 1
  |                                    |
  |<-- jido.agent.child.started -------|
  |                                    |
  |-- work.request ------------------->|
  |                            [process]
  |<-- work.result --------------------|
  |
[aggregate]
```

`emit_to_parent/3` works only while attached. If the coordinator dies and the child is configured to survive, the child becomes orphaned and must be explicitly adopted before parent communication resumes ([14](14-orphans-adoption.md)).

## When to Use What

- **Ephemeral workers for a single turn** → `Directive.spawn_agent/3`
- **Durable collaborators that must survive idle hibernation** → `Jido.Agent.InstanceManager` ([10](10-persistence.md))
- **Named team with persisted topology** → `Jido.Pod` ([11](11-pods.md))

`SpawnAgent` is not durable. If you need survival across hibernation or named reacquisition, that's InstanceManager / Pod territory.

## When the Coordinator Dies

Three policies for child behavior on logical parent death:

| `on_parent_death` | Behavior |
|---|---|
| `:stop` (default) | Simple hierarchy |
| `:continue` | Child finishes work silently as orphan |
| `:emit_orphan` | Child reacts explicitly via `jido.agent.orphaned` signal |

Use orphan survival only when the child owns work that should outlive the coordinator. For replacement coordinators, use `Directive.adopt_child/3`. The adopted relationship is mirrored into `Jido.RuntimeStore`, so future child restarts continue using the replacement parent.

## Tutorial: Parallel URL Fetcher

### Worker

```elixir
defmodule FetchUrlAction do
  use Jido.Action,
    name: "fetch_url",
    schema: [
      url: [type: :string, required: true],
      request_id: [type: :string, required: true]
    ]

  alias Jido.Agent.Directive
  alias Jido.Signal

  def run(%{url: url, request_id: request_id}, context) do
    result = fetch(url)  # HTTP call

    result_signal = Signal.new!(
      "fetch.result",
      %{request_id: request_id, url: url, result: result},
      source: "/worker"
    )

    emit = Directive.emit_to_parent(%{state: context.state}, result_signal)
    {:ok, %{status: :completed, last_fetch: url}, List.wrap(emit)}
  end
end

defmodule FetcherAgent do
  use Jido.Agent,
    name: "fetcher",
    schema: [
      status: [type: :atom, default: :idle],
      last_fetch: [type: :string, default: nil]
    ],
    signal_routes: [{"fetch.request", FetchUrlAction}]
end
```

### Coordinator — spawn + send work

```elixir
defmodule SpawnFetchersAction do
  use Jido.Action,
    name: "spawn_fetchers",
    schema: [urls: [type: {:list, :string}, required: true]]

  alias Jido.Agent.Directive

  def run(%{urls: urls}, _context) do
    pending =
      urls
      |> Enum.with_index()
      |> Map.new(fn {url, i} -> {"req-#{i}", %{url: url, status: :pending}} end)

    spawns =
      urls
      |> Enum.with_index()
      |> Enum.map(fn {url, i} ->
        Directive.spawn_agent(FetcherAgent, :"worker_#{i}",
          meta: %{url: url, request_id: "req-#{i}"})
      end)

    {:ok, %{pending: pending, completed: []}, spawns}
  end
end

defmodule HandleChildStartedAction do
  use Jido.Action,
    name: "child_started",
    schema: [
      pid: [type: :any, required: true],
      tag: [type: :any, required: true],
      meta: [type: :map, default: %{}]
    ]

  alias Jido.Agent.Directive
  alias Jido.Signal

  def run(%{pid: pid, meta: meta}, _context) do
    work = Signal.new!(
      "fetch.request",
      %{url: meta.url, request_id: meta.request_id},
      source: "/coordinator"
    )
    {:ok, %{}, [Directive.emit_to_pid(work, pid)]}
  end
end

defmodule HandleFetchResultAction do
  use Jido.Action,
    name: "handle_result",
    schema: [
      request_id: [type: :string, required: true],
      url: [type: :string, required: true],
      result: [type: :any, required: true]
    ]

  alias Jido.Agent.StateOp

  def run(%{request_id: request_id, url: url, result: result}, context) do
    pending   = Map.get(context.state, :pending, %{})
    completed = Map.get(context.state, :completed, [])
    {_, remaining} = Map.pop(pending, request_id)

    entry = %{request_id: request_id, url: url, result: result, completed_at: DateTime.utc_now()}
    status = if map_size(remaining) == 0, do: :completed, else: :working

    set_pending = StateOp.set_path([:pending], remaining)

    {:ok, %{completed: [entry | completed], status: status}, [set_pending]}
  end
end

defmodule CoordinatorAgent do
  use Jido.Agent,
    name: "coordinator",
    schema: [
      pending: [type: :map, default: %{}],
      completed: [type: {:list, :map}, default: []],
      status: [type: :atom, default: :idle]
    ],
    signal_routes: [
      {"fetch_urls", SpawnFetchersAction},
      {"jido.agent.child.started", HandleChildStartedAction},
      {"fetch.result", HandleFetchResultAction}
    ]
end
```

### Kick off + await

```elixir
{:ok, coord} = MyApp.Jido.start_agent(CoordinatorAgent, id: "coord-1")
signal = Jido.Signal.new!("fetch_urls", %{urls: urls}, source: "/api")
{:ok, _} = Jido.AgentServer.call(coord, signal)

case Jido.await(coord, 30_000) do
  {:ok, %{status: :completed, completed: results}} -> results
  {:error, :timeout} -> {:error, :timeout}
end
```

## Error Handling

### Child crashes → `jido.agent.child.exit`

```elixir
defmodule HandleChildExitAction do
  use Jido.Action,
    name: "handle_child_exit",
    schema: [
      tag: [type: :atom, required: true],
      reason: [type: :any, required: true]
    ]

  def run(%{tag: tag, reason: reason}, context) do
    pending = Map.get(context.state, :pending, %{})
    failed = Enum.find(pending, fn {_id, info} -> info[:worker_tag] == tag end)

    case failed do
      {request_id, _} ->
        {_, remaining} = Map.pop(pending, request_id)
        failures = Map.get(context.state, :failures, [])
        {:ok, %{pending: remaining, failures: [{request_id, reason} | failures]}}
      nil -> {:ok, %{}}
    end
  end
end

# Route it
signal_routes: [
  # ...
  {"jido.agent.child.exit", HandleChildExitAction}
]
```

### Timeout on fan-out

```elixir
{:ok, children} = Jido.get_children(coord)
pids = Map.values(children) |> Enum.map(& &1.pid)

case Jido.await_all(pids, 60_000) do
  {:ok, results} ->
    successful = Enum.count(results, fn {_, %{status: s}} -> s == :completed end)
    successful

  {:error, :timeout} ->
    for pid <- pids, Jido.alive?(pid), do: Jido.cancel(pid, reason: :timeout)
end
```

### Graceful cleanup with StopChild

```elixir
defmodule CleanupWorkersAction do
  use Jido.Action, name: "cleanup",
    schema: [tags: [type: {:list, :atom}, required: true]]

  alias Jido.Agent.Directive

  def run(%{tags: tags}, _context) do
    stops = Enum.map(tags, &Directive.stop_child(&1, :cleanup))
    {:ok, %{status: :cleaned_up}, stops}
  end
end
```

## Await Helpers (Coordination)

```elixir
Jido.await(pid, 10_000)                       # single agent
Jido.await_child(parent, :worker_1, 30_000)   # specific child by tag
Jido.await_all([pid1, pid2], 30_000)          # all agents
Jido.await_any([pid1, pid2], 10_000)          # first to complete

Jido.alive?(pid)
{:ok, children} = Jido.get_children(parent)
{:ok, child_pid} = Jido.get_child(parent, :tag)
Jido.cancel(pid, reason: :timeout)
```

### Return shapes

- `{:ok, %{status: :completed, result: any}}` — success
- `{:ok, %{status: :failed, result: error}}` — agent-level failure (still `:ok` to await; not an infrastructure error)
- `{:error, :timeout}` — infrastructure timeout
- `{:error, :not_found}` — dead pid

### `await/2` customization

`Jido.await(pid, timeout, status_path: [:status], result_path: [:last_answer], error_path: [:error])`

Defaults: `status_path: [:status]`, `result_path: [:last_answer]`, `error_path: [:error]`.

Agent completion is **state-based** — set `agent.state.status = :completed | :failed` to signal terminal state.

### `await_any/2` semantics

Returns first winner; other agents keep running. Cancel explicitly if needed.

## Durable Variants (when `SpawnAgent` is wrong)

If collaborators must survive coordinator death or hibernation:

```elixir
# Durable named agent
{:ok, worker_pid} = Jido.Agent.InstanceManager.get(:workers, "worker-123")

# Durable named team
{:ok, pod_pid} = Jido.Pod.get(:review_pods, "review-123")
{:ok, reviewer} = Jido.Pod.ensure_node(pod_pid, :reviewer)
```

## Source

- `jido/guides/orchestration.md`
- `jido/guides/await.md`
- `jido/guides/runtime-patterns.md`
