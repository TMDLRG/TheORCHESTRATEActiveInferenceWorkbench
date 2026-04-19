# composition_runtime/lib/ — ReadmeAI

## Purpose

Source tree for the multi-agent composition runtime.

## Contents

| File | Module | Purpose |
|---|---|---|
| [`composition_runtime.ex`](composition_runtime.ex) | `CompositionRuntime` | Root |
| [`composition_runtime/application.ex`](composition_runtime/application.ex) | `CompositionRuntime.Application` | OTP app; children = NameRegistry + RootSupervisor + Registry |
| [`composition_runtime/composition.ex`](composition_runtime/composition.ex) | `CompositionRuntime.Composition` | Supervisor (`:one_for_one`) |
| [`composition_runtime/signal_broker.ex`](composition_runtime/signal_broker.ex) | `CompositionRuntime.SignalBroker` | GenServer routing `Jido.Signal` |
| [`composition_runtime/registry.ex`](composition_runtime/registry.ex) | `CompositionRuntime.Registry` | Unique-name live composition tracker |

See [`../ReadmeAI.MD`](../ReadmeAI.MD) for public API + usage.
