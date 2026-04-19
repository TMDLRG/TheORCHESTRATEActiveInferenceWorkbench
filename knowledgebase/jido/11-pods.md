# 11 — Pods (Durable Named Teams)

> `Jido.Pod` is the durable topology layer. A pod is an ordinary `Jido.Agent` with a canonical topology snapshot and a reserved singleton plugin mounted under `:__pod__`. The pod module IS the durable manager.

## Mental Model

- A pod module → `use Jido.Pod` → wraps `use Jido.Agent`
- The pod module is the durable manager for its topology
- `topology` is pure data: `%Jido.Pod.Topology{}`
- Member nodes are durable collaborators acquired through ordinary `Jido.Agent.InstanceManager` registries
- **No separate runtime manager process.** Pods run through `InstanceManager`.

## Defining a Pod

```elixir
defmodule MyApp.OrderReviewPod do
  use Jido.Pod,
    name: "order_review",
    topology: %{
      planner: %{agent: MyApp.PlannerAgent, manager: :planner_members, activation: :eager},
      reviewer: %{agent: MyApp.ReviewerAgent, manager: :reviewer_members, activation: :lazy}
    },
    schema: [
      phase: [type: :atom, default: :planning]
    ]
end

# Or empty topology (built up via mutate/3)
defmodule MyApp.EmptyReviewPod do
  use Jido.Pod, name: "empty_review"
end
```

## The Happy Path (most users only need this)

1. Define a pod with `use Jido.Pod`
2. Run the pod manager through a normal `Jido.Agent.InstanceManager`
3. `Jido.Pod.get/3` to load + reconcile eager members
4. `Jido.Pod.ensure_node/3` for lazy members
5. `Jido.Pod.mutate/3` when the team needs to grow/shrink at runtime

## Canonical Example

```elixir
defmodule MyApp.ReviewWorkerAgent do
  use Jido.Agent, name: "review_worker",
    schema: [role: [type: :string, default: "worker"]]
end

defmodule MyApp.ReviewPod do
  use Jido.Pod, name: "review_pod"
end

# Supervision tree
children = [
  Jido.Agent.InstanceManager.child_spec(
    name: :review_workers,
    agent: MyApp.ReviewWorkerAgent,
    storage: {Jido.Storage.ETS, table: :review_runtime}
  ),
  Jido.Agent.InstanceManager.child_spec(
    name: :review_pods,
    agent: MyApp.ReviewPod,
    storage: {Jido.Storage.ETS, table: :review_runtime}
  )
]

# Runtime
{:ok, pod_pid} = Jido.Pod.get(:review_pods, "review-123")

{:ok, report} =
  Jido.Pod.mutate(pod_pid, [
    Jido.Pod.Mutation.add_node("planner", %{
      agent: MyApp.ReviewWorkerAgent,
      manager: :review_workers,
      activation: :eager,
      initial_state: %{role: "planner"}
    }),
    Jido.Pod.Mutation.add_node(
      "reviewer",
      %{agent: MyApp.ReviewWorkerAgent, manager: :review_workers, activation: :lazy, initial_state: %{role: "reviewer"}},
      owner: "planner",
      depends_on: ["planner"]
    )
  ])

{:ok, reviewer_pid} = Jido.Pod.ensure_node(pod_pid, "reviewer")
```

## Core API

```elixir
Jido.Pod.get(manager_name, pod_id, opts \\ [])       # load + reconcile eager (happy path)
Jido.Pod.ensure_node(pod_pid, node_name)              # start or re-adopt one named member
Jido.Pod.reconcile(pod_pid)                           # repair eager roots + ownership edges
Jido.Pod.fetch_topology(pod_pid)                      # => {:ok, %Topology{}}
Jido.Pod.nodes(pod_pid)                               # => {:ok, snapshots}
Jido.Pod.mutate(pod_pid, [mutations])                 # change topology at runtime
Jido.Pod.mutation_effects(pod_pid, [mutations])       # return state ops + directive (for in-turn pod code)
Jido.Pod.put_topology(agent, topology)                # pure; advances version if structural change
Jido.Pod.update_topology(agent, fun)
```

`Jido.Pod.get/3` is the default happy path: calls `InstanceManager.get/3` then reconciles eager nodes.

## Pod Plugin (`Jido.Pod.Plugin`)

Framework-provided:

- Always singleton
- Reserved state key `:__pod__`
- Persists resolved topology snapshot as ordinary agent state
- Advertises `:pod` capability

Replace via normal `default_plugins: %{__pod__: ...}` override. Replacement must keep `:__pod__` key, be singleton, and advertise `:pod` capability. Do not **disable** it.

## Topology (`%Jido.Pod.Topology{}`)

- `name` — stable topology name
- `nodes` — map of logical node name → `%Topology.Node{}`
- `links` — list of `%Topology.Link{}`
- `version` — integer version; advances on structural changes (preserved for no-op rewrites)

Node names may be **atoms or strings** (mixed in the same topology). Static predefined pods can keep atom names; runtime-defined or persisted dynamic nodes can use strings.

### Link vocabulary (v1)

- `:depends_on` — runtime prerequisites + eager reconciliation order
- `:owns` — logical runtime owner

### Pure topology API

```elixir
{:ok, topology} = Jido.Pod.Topology.from_nodes("review", %{
  planner: %{agent: MyApp.PlannerAgent, manager: :planner_members}
})

{:ok, topology} = Jido.Pod.Topology.put_node(topology, :reviewer,
  %{agent: MyApp.ReviewerAgent, manager: :reviewer_members})

{:ok, topology} = Jido.Pod.Topology.put_link(topology,
  {:depends_on, :reviewer, :planner})

# Via struct constructor
Jido.Pod.Topology.new!(
  name: "editorial_pipeline",
  nodes: %{
    lead: %{agent: MyApp.LeadAgent, manager: :editorial_leads, activation: :eager},
    review: %{agent: MyApp.ReviewAgent, manager: :editorial_reviews},
    publish: %{agent: MyApp.PublishAgent, manager: :editorial_publish}
  },
  links: [
    {:owns, :lead, :review},
    {:owns, :lead, :publish},
    {:depends_on, :publish, :review}
  ]
)
```

Tuple shorthand links are normalized into `%Topology.Link{}` structs.

## Runtime Ownership Rules

- Root nodes (no `:owns` parent) → adopted directly into the pod manager
- Owned nodes → adopted under their logical owner
- `:depends_on` + `:owns` combine into reconcile waves so prerequisites run first
- `kind: :pod` nodes → acquired through their own `InstanceManager`, adopted into the ownership tree, then reconciled recursively
- **Recursive pod ancestry is rejected** (a pod cannot expand into itself)

### Nested pods

```elixir
Jido.Pod.Topology.new!(
  name: "program",
  nodes: %{
    coordinator: %{agent: MyApp.CoordinatorAgent, manager: :coordinators, activation: :eager},
    editorial: %{module: MyApp.EditorialPod, manager: :editorial_pods, kind: :pod, activation: :eager}
  },
  links: [{:owns, :coordinator, :editorial}]
)
```

The nested pod reconciles its own eager topology once reattached. Thaw repairs the broken ownership edge at the outer pod boundary, then the nested pod repairs its own edges.

## Live Mutation (`Jido.Pod.mutate/3`)

```elixir
{:ok, report} = Jido.Pod.mutate(pod_pid, [
  Jido.Pod.Mutation.add_node(
    "reviewer",
    %{agent: MyApp.ReviewerAgent, manager: :reviewer_members, activation: :eager},
    owner: "planner",
    depends_on: ["planner"]
  ),
  Jido.Pod.Mutation.remove_node("old_planner")
])
```

Pass a running pod pid or another `Jido.AgentServer` server reference. Raw string ids need registry lookup first.

### Semantics (persistence-first)

1. New topology snapshot written into `agent.state[:__pod__]`
2. Runtime stop/start work runs against the new topology
3. Returns `%Jido.Pod.Mutation.Report{}` with `added`, `removed`, `started`, `stopped`, `failures`
4. **Partial failure** → topology stays updated, returns `{:error, report}`. Recovery via later `reconcile/2`, `ensure_node/3`, or another mutation.

### Removals are subtree-aware

Removing a node removes its owned descendants, deletes links touching removed nodes, tears down live runtime state in reverse ownership/dependency order.

### Supported

- Batched `add_node` and `remove_node`
- `kind: :agent` and `kind: :pod`
- Ownership and dependency links embedded on add ops
- Mixed atom/string node names

### NOT supported (yet)

- Standalone link mutation
- Reparenting a surviving node
- Multi-node pod runtime semantics

### In-turn pod code

`Jido.Pod.mutation_effects/3` returns state ops + runtime directive for the same mutation path instead of executing immediately. Use when mutating from within an agent's `cmd/2` path.

## Persistence, Storage, Thaw

Pods don't need a separate storage contract. The durable topology snapshot lives in ordinary agent state.

Persisted:
- `agent.state[:__pod__].topology`
- `agent.state[:__pod__].topology_version`
- Any pod-plugin metadata under `:__pod__`

NOT persisted as durable truth:
- Live child PIDs, monitors
- `AgentServer` `state.children`
- Process tree

### Thaw is two-step

1. Pod agent thaws with topology already restored
2. Root relationships re-established explicitly with `reconcile/2` and `ensure_node/3`

```elixir
{:ok, pod_pid} = Jido.Pod.get(:order_review_pods, "order-123")

# Later: hibernates, then restores
{:ok, restored_pid} = Jido.Agent.InstanceManager.get(:order_review_pods, "order-123")
{:ok, topology}     = Jido.Pod.fetch_topology(restored_pid)
{:ok, snapshots}    = Jido.Pod.nodes(restored_pid)

# Low-level: reconcile eager roots
{:ok, report} = Jido.Pod.reconcile(restored_pid)
```

After thaw:
- Surviving root nodes show as `:running` until re-adopted
- Surviving owned descendants remain `:adopted` if logical owner survived
- Nested pod managers can be `:running` or `:adopted` depending on owner
- `reconcile/2` repairs root boundary + missing ownership edges for eager nodes
- `ensure_node/3` handles start-fresh, re-adopt root, or reattach descendant

## Partitioned Pods (Multi-Tenancy)

```elixir
{:ok, alpha} = Jido.Pod.get(:order_review_pods, "order-123", partition: :alpha)
{:ok, beta}  = Jido.Pod.get(:order_review_pods, "order-123", partition: :beta)
```

Two different pod runtimes, same pod key. Pod-managed children and nested pod nodes inherit the pod's partition. Persistence, registry lookup, parent bindings, pod telemetry stay partition-scoped.

Cross-partition interaction is an explicit exception. Pod trees are single-partition by default.

See [12-multi-tenancy.md](12-multi-tenancy.md).

## Current Scope (v1)

Supported:
- Predefined topology
- Live add/remove mutation
- Hierarchical ownership for `kind: :agent` and `kind: :pod`
- Pod manager as durable root
- Single-node runtime
- Partition-safe pods, children, nested pods, persistence, telemetry

Not supported:
- Distributed pod graphs across a cluster
- Cross-partition pod trees as a first-class design
- Pod-local signal bus
- Separate pod instance manager
- Recursive pod ancestry
- Standalone link mutation
- Reparenting surviving nodes
- No pod-local tenant placement policies across nodes

Extension seam: `:__pod__` plugin state and `%Jido.Pod.Topology{}` shape.

## Source

- `jido/guides/pods.md`
- `jido/lib/jido/pod.ex`, `jido/lib/jido/pod/**`
- Full runnable example: `jido/test/examples/runtime/mutable_pod_runtime_test.exs`
