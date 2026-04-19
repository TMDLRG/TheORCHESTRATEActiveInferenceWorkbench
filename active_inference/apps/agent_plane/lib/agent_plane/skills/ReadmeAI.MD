# agent_plane/lib/agent_plane/skills/ — ReadmeAI

## Purpose

Reusable math "skills" — named primitives that the builder's canvas can reference as nodes. Each module wraps a well-known Active Inference primitive with a schema + short docstring citing the equation it implements.

## Contents

| File | Module | Implements | Equation |
|---|---|---|---|
| [`softmax.ex`](softmax.ex) | `AgentPlane.Skills.Softmax` | Categorical softmax | eq. B.4 |
| [`shannon_entropy.ex`](shannon_entropy.ex) | `AgentPlane.Skills.ShannonEntropy` | H[p] = −Σp log p | eq. 4.6 |
| [`kl_divergence.ex`](kl_divergence.ex) | `AgentPlane.Skills.KlDivergence` | KL[q \|\| p] | eq. 4.4 |
| [`variational_free_energy.ex`](variational_free_energy.ex) | `AgentPlane.Skills.VariationalFreeEnergy` | F | eq. 4.11 |
| [`expected_free_energy.ex`](expected_free_energy.ex) | `AgentPlane.Skills.ExpectedFreeEnergy` | G | eq. 4.10 |
| [`registry.ex`](registry.ex) | `AgentPlane.Skills.Registry` | Looks up skills by id for the canvas node palette |

## Public API

Each skill module exports at minimum `run/2` (for use as a `Jido.Action`) and `info/0` (metadata for the canvas block catalogue).

`Registry`:

| Function | Arity | Purpose |
|---|---|---|
| `all/0` | 0 | Every registered skill |
| `fetch/1` | 1 | Skill by id |

## Verification status

- `:verified` — primitives are backed by `ActiveInferenceCore.Math` / `DiscreteTime` which are tested.
- `:scaffolded` — skill-node usage from the canvas is wired but not end-to-end tested.

## Related

- Block catalogue: `/guide/blocks` (in-app)
- Parent README: [`../../../ReadmeAI.MD`](../../../ReadmeAI.MD)
