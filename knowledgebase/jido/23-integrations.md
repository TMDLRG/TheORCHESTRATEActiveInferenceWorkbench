# 23 — Integrations

> Phoenix/LiveView, Ash, PubSub.

## Phoenix Integration

### Setup

```elixir
defmodule MyApp.Jido do
  use Jido, otp_app: :my_app
end

# application.ex
children = [
  MyApp.Repo,
  MyApp.Jido,
  {Phoenix.PubSub, name: MyApp.PubSub},
  MyAppWeb.Endpoint
]

config :my_app, MyApp.Jido, max_tasks: 1000, agent_pools: []
```

### Controller pattern

```elixir
defmodule MyAppWeb.CounterController do
  use MyAppWeb, :controller
  alias Jido.Signal

  def show(conn, %{"id" => id}) do
    case MyApp.Jido.whereis(id) do
      nil -> conn |> put_status(:not_found) |> json(%{error: "not_found"})
      pid ->
        {:ok, state} = Jido.AgentServer.state(pid)
        json(conn, %{id: id, count: state.agent.state.count})
    end
  end

  def create(conn, %{"id" => id}) do
    case MyApp.Jido.start_agent(MyApp.CounterAgent, id: id) do
      {:ok, _pid} -> json(conn, %{id: id, count: 0})
      {:error, {:already_started, _}} ->
        conn |> put_status(:conflict) |> json(%{error: "exists"})
    end
  end

  def increment(conn, %{"id" => id, "amount" => amount}) do
    signal = Signal.new!("counter.increment", %{amount: amount}, source: "/api")

    with pid when is_pid(pid) <- MyApp.Jido.whereis(id),
         {:ok, agent} <- Jido.AgentServer.call(pid, signal) do
      json(conn, %{id: id, count: agent.state.count})
    else
      nil -> conn |> put_status(:not_found) |> json(%{error: "not_found"})
    end
  end
end
```

### PubSub broadcasting from actions

```elixir
defmodule MyApp.Actions.Increment do
  use Jido.Action, name: "increment", schema: [amount: [type: :integer, default: 1]]

  alias Jido.Agent.Directive

  def run(%{amount: amount}, context) do
    current = context.state[:count] || 0
    signal = Jido.Signal.new!("counter.updated", %{count: current + amount}, source: "/agent")

    {:ok, %{count: current + amount}, [
      Directive.emit(signal, {:pubsub, pubsub: MyApp.PubSub, topic: "counter:updates"})
    ]}
  end
end
```

Or from the controller directly:

```elixir
Phoenix.PubSub.broadcast(MyApp.PubSub, "counter:#{id}", {:counter_updated, agent.state})
```

### LiveView integration

```elixir
defmodule MyAppWeb.CounterLive do
  use MyAppWeb, :live_view
  alias Jido.Signal

  def mount(%{"id" => id}, _session, socket) do
    if connected?(socket) do
      Phoenix.PubSub.subscribe(MyApp.PubSub, "counter:#{id}")
    end

    {:ok, socket |> assign(:id, id) |> load_count(id)}
  end

  def handle_event("increment", %{"amount" => amount}, socket) do
    signal = Signal.new!("counter.increment",
      %{amount: String.to_integer(amount)},
      source: "/liveview")

    case MyApp.Jido.whereis(socket.assigns.id) do
      nil -> {:noreply, socket}
      pid ->
        {:ok, agent} = Jido.AgentServer.call(pid, signal)
        Phoenix.PubSub.broadcast(MyApp.PubSub,
          "counter:#{socket.assigns.id}",
          {:counter_updated, agent.state})
        {:noreply, assign(socket, count: agent.state.count)}
    end
  end

  def handle_info({:counter_updated, state}, socket) do
    {:noreply, assign(socket, count: state.count)}
  end

  defp load_count(socket, id) do
    case MyApp.Jido.whereis(id) do
      nil -> assign(socket, count: 0)
      pid ->
        {:ok, state} = Jido.AgentServer.state(pid)
        assign(socket, count: state.agent.state.count)
    end
  end
end
```

### JSON response sanitization

Drop internal framework keys before serializing agent state:

```elixir
defmodule MyAppWeb.AgentJSON do
  def show(%{agent: agent}) do
    %{
      id: agent.id,
      state: sanitize_state(agent.state),
      dirty_state: agent.dirty_state
    }
  end

  defp sanitize_state(state) when is_map(state) do
    state
    |> Map.drop([
      :__thread__, :__identity__, :__memory__, :__pod__,
      :__parent__, :__orphaned_from__, :__strategy__,
      :__cron_specs__, :__partition__,
      :children
    ])
    |> Map.new(fn {k, v} -> {k, serialize_value(v)} end)
  end

  defp serialize_value(%DateTime{} = dt), do: DateTime.to_iso8601(dt)
  defp serialize_value(v), do: v
end
```

## Ash Integration (`ash_jido`)

### Installation

```elixir
def deps do
  [
    {:ash, "~> 3.12"},
    {:jido, "~> 2.0"},
    {:ash_jido, "~> 0.1"}
  ]
end
```

### Resource with Jido extension

```elixir
defmodule MyApp.Order do
  use Ash.Resource, domain: MyApp.Shop, extensions: [AshJido]

  attributes do
    uuid_primary_key :id
    attribute :status, :atom, default: :pending
    attribute :total, :decimal
    timestamps()
  end

  actions do
    create :place
    read :by_id, get_by: [:id]
    update :confirm
    update :ship
  end

  jido do
    action :place, name: "create_order"
    action :by_id, name: "get_order"
    action :confirm
    action :ship
  end
end
```

### Using generated actions

```elixir
{:ok, order} = MyApp.Order.Jido.Place.run(%{total: Decimal.new("99.99")},
  %{domain: MyApp.Shop})

{:ok, updated} = MyApp.Order.Jido.Confirm.run(%{id: order.id},
  %{domain: MyApp.Shop, actor: user})
```

### Wiring into an agent

```elixir
defmodule MyApp.OrderAgent do
  use Jido.Agent,
    name: "order_processor",
    schema: [current_order_id: [type: {:or, [:string, nil]}, default: nil]],
    signal_routes: [
      {"order.place",   MyApp.Order.Jido.Place},
      {"order.confirm", MyApp.Order.Jido.Confirm},
      {"order.ship",    MyApp.Order.Jido.Ship}
    ]
end
```

### Triggering from Ash changes

```elixir
defmodule MyApp.Changes.NotifyAgent do
  use Ash.Resource.Change

  def change(changeset, _opts, _context) do
    Ash.Changeset.after_action(changeset, fn _cs, record ->
      signal = Jido.Signal.new!(
        "order.created",
        %{order_id: record.id, total: record.total},
        source: "/ash"
      )

      case MyApp.Jido.whereis("fulfillment-agent") do
        nil -> :ok
        pid -> Jido.AgentServer.cast(pid, signal)
      end

      {:ok, record}
    end)
  end
end
```

### Context requirements

- `:domain` (required)
- `:actor` (optional, for authorization)
- `:tenant` (optional, for multi-tenancy)

### DSL reference (`jido do ... end`)

```elixir
jido do
  action :create
  action :read, name: "list_users", description: "...", tags: ["user-management"]
  action :special, output_map?: false       # preserve Ash structs

  all_actions                               # expose all
  all_actions except: [:destroy]            # exclude some
  all_actions only: [:create, :read]        # include only
end
```

### Default naming

| Action | Generated name |
|---|---|
| `:create` | `create_<resource>` |
| `:read` (`:read`) | `list_<resources>` |
| `:read` (`:by_id`) | `get_<resource>_by_id` |
| `:update` | `update_<resource>` |
| `:destroy` | `delete_<resource>` |

## Signal Sources (convention)

Use path-like sources that describe the origin, not the consumer:

- `"/api"` — HTTP controllers
- `"/liveview"` — LiveView events
- `"/worker"` — background workers
- `"/sensor/metric"` — sensors
- `"/ash"` — Ash change hooks
- `"/agent"` — another agent (internal)

## Source

- `jido/guides/phoenix-integration.md`
- `jido/guides/ash-integration.md`
- `ash_jido` package
