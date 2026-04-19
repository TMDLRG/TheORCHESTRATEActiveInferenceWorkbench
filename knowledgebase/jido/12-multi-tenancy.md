# 12 — Multi-Tenancy

> Two distinct models: **separate Jido instances** for hard isolation, or **one shared instance with `partition:`** as the logical tenant boundary.

## Choosing an Isolation Level

**Separate Jido instances** — use when you need:
- Different supervision trees
- Different storage backends or runtime config
- Strong operational isolation between tenants

**One shared Jido instance with partitions** — use when you want:
- One runtime hosting many tenants/workspaces
- Shared supervision and managers
- Isolated registry identity, persistence, lineage, and telemetry per tenant

## Pod-First Model (recommended)

For shared-instance multi-tenancy, think in terms of **partitioned durable teams**, not partitioned standalone agents.

- A tenant owns one or more root pods
- Each pod owns a durable topology
- Pod-managed children inherit the pod's partition by default
- Same pod key can exist in multiple partitions without collisions

### Definition

```elixir
defmodule MyApp.WorkspacePod do
  use Jido.Pod,
    name: "workspace",
    topology: %{
      coordinator: %{agent: MyApp.WorkerAgent, manager: :workspace_workers, activation: :eager},
      reviewer: %{agent: MyApp.WorkerAgent, manager: :workspace_workers, activation: :lazy}
    }
end
```

### Acquisition per tenant

```elixir
{:ok, alpha_pod} = Jido.Pod.get(:workspace_pods, "workspace-123", partition: :tenant_alpha)
{:ok, beta_pod}  = Jido.Pod.get(:workspace_pods, "workspace-123", partition: :tenant_beta)
```

Two separate pod runtimes with two separate child trees.

## Setup

```elixir
children = [
  MyApp.Jido,
  Jido.Agent.InstanceManager.child_spec(
    name: :workspace_workers,
    agent: MyApp.WorkerAgent,
    jido: MyApp.Jido
  ),
  Jido.Agent.InstanceManager.child_spec(
    name: :workspace_pods,
    agent: MyApp.WorkspacePod,
    jido: MyApp.Jido
  )
]
```

Workers manager is shared, but runtime identity is not. `workspace-123` in `:tenant_alpha` is separate from `workspace-123` in `:tenant_beta`.

## Runtime Invariants

- A pod tree is **single-partition** by default
- Pod-managed children inherit the pod partition
- Nested pod nodes inherit that same partition
- Runtime parent bindings stored per partition
- Registry identity per partition
- Persistence identity per partition
- Telemetry includes `:jido_partition`

These operations stay partition-isolated automatically:

```elixir
Jido.whereis/3
Jido.Agent.InstanceManager.get/3
Jido.Agent.InstanceManager.lookup/3
Jido.Pod.get/3
Jido.Pod.reconcile/2
Jido.Pod.ensure_node/3
# hibernate/thaw for agents and pods
```

Pass `partition: atom` in opts to any of these.

## Hierarchies & Nested Pods

Partition inheritance is recursive through normal Pod runtime behavior.

If a root pod in `:tenant_alpha` starts:
- an eager worker
- a lazy worker
- a nested pod node

all runtimes stay in `:tenant_alpha` unless you explicitly do something unusual with raw pids.

Nested pods are a good fit for workspace/team decomposition:
- Root pod for the tenant workspace
- Nested pods for planning, editorial, review domains

## Persistence & Thaw

Partition is part of durable identity.

```elixir
:ok = Jido.Agent.InstanceManager.stop(:workspace_pods, "workspace-123", partition: :tenant_alpha)
```

Does NOT affect the same pod key in another partition.

On thaw:
- Only the requested partition is restored
- Surviving children reattach only inside that partition
- Sibling tenant runtimes remain untouched

Especially important for pods because durable topology snapshot and runtime ownership tree must stay aligned at the tenant boundary.

## Cross-Partition Behavior

Normal pod behavior is partition-local:
- Adoption by child id resolves within the caller's partition
- Child lookup by id resolves within the requested partition
- Pod trees should not span partitions as a normal design pattern

Escape hatch exists if you operate on raw pids directly, but that is an explicit exception. For strong guarantees, keep pod trees single-partition.

## Observability

`:jido_partition` appears in:
- Debug events
- Agent runtime telemetry
- Pod telemetry

Practical applications:
- Filter logs by tenant
- Segment traces/metrics by tenant
- Verify reconcile/thaw behavior stayed in the expected partition

## Partition Without Pods

You can use `partition:` with direct agent starts or bare `InstanceManager` too. In practice, Pod-first is the recommended shared-instance model because the durable runtime shape is explicit.

```elixir
# With InstanceManager alone
Jido.Agent.InstanceManager.get(:sessions, "user-123", partition: :tenant_alpha)

# With direct start
MyApp.Jido.start_agent(MyAgent, id: "a-1", partition: :tenant_alpha)
```

## Separate-Instance Model (hard isolation)

```elixir
defmodule MyApp.TenantA.Jido, do: use Jido, otp_app: :my_app
defmodule MyApp.TenantB.Jido, do: use Jido, otp_app: :my_app

config :my_app, MyApp.TenantA.Jido, max_tasks: 500
config :my_app, MyApp.TenantB.Jido, max_tasks: 1000
```

Separate registries, supervisors, storage. Use when different infrastructure or operational isolation is required.

## Out of Scope (v1)

- Distributed pod graphs across a cluster
- Cross-partition pod trees as a first-class design
- Tenant placement policies across multiple nodes

For hard operational isolation or different infrastructure per tenant → separate Jido instances.

## Example

End-to-end runtime example: `jido/test/examples/runtime/partitioned_pod_runtime_test.exs`. Demonstrates:
- Same pod key in multiple partitions
- Eager and lazy node isolation
- Partition-preserving runtime lineage

## Source

- `jido/guides/multi-tenancy.md`
- `jido/guides/runtime-patterns.md`
- `jido/guides/configuration.md`
