# 07 — Strategies

> Strategies control **how** an agent executes actions inside `cmd/2`. Two ship: `Direct` and `FSM`. Custom strategies implement `Jido.Agent.Strategy`.

## Built-in Strategies

### Direct (default)

Executes actions immediately and sequentially.

```elixir
use Jido.Agent,
  name: "my_agent",
  strategy: Jido.Agent.Strategy.Direct
```

No state-machine overhead. Each `cmd/2` processes the given instructions, returns updated agent + directives.

### FSM (Finite State Machine)

Tracks **execution state** around `cmd/2` with explicit transitions.

```elixir
use Jido.Agent,
  name: "fsm_agent",
  strategy: {Jido.Agent.Strategy.FSM,
    initial_state: "ready",
    transitions: %{
      "ready" => ["processing"],
      "processing" => ["ready"]
    },
    auto_transition: true
  }
```

#### FSM options

- `:initial_state` (default `"idle"`) — starting execution state
- `:transitions` (optional) — `%{from => [to_states]}`. If omitted, uses the default workflow below.
- `:auto_transition` (default `true`) — auto-return to initial state after processing

#### Default transitions (when not supplied)

```elixir
%{
  "idle"       => ["processing"],
  "processing" => ["idle", "completed", "failed"],
  "completed"  => ["idle"],
  "failed"     => ["idle"]
}
```

#### FSM contracts

- Transitions **must** include `"processing"` as the runtime execution state.
- With `:auto_transition`, there **must** be a path from `"processing"` back to the initial state.
- Keep **domain state** in `agent.state` (e.g. `order_status: :confirmed`). Keep **execution state** in `__strategy__`. Don't conflate them — modeling domain workflow as FSM transitions is a common pitfall.

### FSM keeps `cmd/2` pure

Instead of running instructions inline, FSM emits `%Directive.RunInstruction{}` for the runtime to execute, then handles results through internal strategy actions (via `{:strategy_cmd, handler}` signal routes). This preserves the pure-function contract.

## Snapshot Interface (stable introspection)

```elixir
snap = MyAgent.strategy_snapshot(agent)

snap.status    # :idle | :running | :waiting | :success | :failure
snap.done?     # true when terminal
snap.result    # main output if any
snap.details   # additional metadata (e.g. fsm_state, processed_count)
```

Helpers on `Jido.Agent.Strategy.Snapshot`:

```elixir
Snapshot.terminal?(snap)   # status in [:success, :failure]
Snapshot.running?(snap)    # status in [:running, :waiting]
```

## Strategy State Helpers (`Jido.Agent.Strategy.State`)

Strategy state lives under `agent.state.__strategy__`.

```elixir
alias Jido.Agent.Strategy.State, as: StratState

state  = StratState.get(agent, %{})
agent  = StratState.put(agent, %{status: :running})
agent  = StratState.update(agent, fn s -> %{s | counter: s.counter + 1} end)
StratState.status(agent)          # :idle | :running | ...
StratState.terminal?(agent)
StratState.active?(agent)
agent  = StratState.set_status(agent, :running)
agent  = StratState.clear(agent)
```

## Implementing a Custom Strategy

```elixir
defmodule MyCustomStrategy do
  use Jido.Agent.Strategy

  alias Jido.Agent.{Directive, StateOps}
  alias Jido.Agent.Strategy.State, as: StratState

  @impl true
  def init(agent, _ctx) do
    agent = StratState.put(agent, %{module: __MODULE__, status: :idle})
    {agent, []}
  end

  @impl true
  def cmd(agent, instructions, _ctx) do
    Enum.reduce(instructions, {agent, []}, fn instruction, {acc, dirs} ->
      instruction = %{instruction | context: Map.put(instruction.context, :state, acc.state)}

      case Jido.Exec.run(instruction) do
        {:ok, result} ->
          {StateOps.apply_result(acc, result), dirs}

        {:ok, result, effects} ->
          {StateOps.apply_result(acc, result), dirs ++ List.wrap(effects)}

        {:error, reason} ->
          error = Jido.Error.execution_error("Failed", %{reason: reason})
          {acc, dirs ++ [%Directive.Error{error: error, context: :instruction}]}
      end
    end)
  end

  # Optional callbacks:
  @impl true
  def tick(agent, _ctx), do: {agent, []}

  @impl true
  def snapshot(agent, _ctx), do: Jido.Agent.Strategy.default_snapshot(agent)

  @impl true
  def action_spec(:my_internal_action) do
    %{schema: [param: [type: :string, required: true]], doc: "..."}
  end
  def action_spec(_), do: nil

  @impl true
  def signal_routes(_ctx) do
    [{"my_strategy.start", {:strategy_cmd, :start_action}}]
  end
end
```

### Strategy callback surface

| Callback | Required | Purpose |
|---|---|---|
| `cmd/3` | yes | Process instructions, return `{agent, directives}` |
| `init/2` | no | Initialize strategy state (during `new/1` or `AgentServer.init/1`) |
| `tick/2` | no | Multi-step continuation hook (for LLM chains, etc.) |
| `snapshot/2` | no | Return `%Strategy.Snapshot{}` |
| `action_spec/1` | no | Describe strategy-internal actions (for discovery/validation) |
| `signal_routes/1` | no | Strategy-owned routing (priority 50+) |

## `{:strategy_cmd, handler}` route targets

A strategy route can target an internal handler instead of an action module:

```elixir
def signal_routes(_ctx) do
  [
    {"react.user_query", {:strategy_cmd, :react_start}},
    {"ai.llm_result", {:strategy_cmd, :react_llm_result}}
  ]
end
```

The strategy receives these in its `cmd/3` callback as strategy-internal instructions.

## When Direct vs FSM

| Use case | Strategy | Why |
|---|---|---|
| Simple request/response | Direct | No machine overhead |
| Multi-step workflows with transitions | FSM | Explicit transitions prevent invalid states |
| Stateless actions | Direct | No state to track |
| Wizards, onboarding | FSM | Step-by-step fits naturally |
| Background jobs | Direct | Execute and complete |
| Long-running with pauses / resume | FSM | Can persist state |
| Mode switching agents | FSM | States represent modes |

**Rule of thumb:** If you ever need to ask "what step are we on?" or "can we do X right now?", use FSM. Otherwise Direct.

Most agents ship with Direct; FSM covers ~90% of the rest. Custom strategies are for behavior trees, planners, and bespoke patterns.

## When NOT to Build a Custom Strategy

- Sequential action execution → Direct
- State machine transitions → FSM
- Modifying action behavior → different Action
- Pre/post processing → agent `on_before_cmd`/`on_after_cmd` hooks
- Different routing → plugin `signal_routes`

## Source

- `jido/guides/strategies.md`
- `jido/guides/custom-strategies.md`
- `jido/guides/fsm-strategy.livemd`
- `Jido.Agent.Strategy` moduledoc
