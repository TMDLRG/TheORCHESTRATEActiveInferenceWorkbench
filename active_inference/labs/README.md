# The ORCHESTRATE Active Inference Learning Workbench — Labs (Weeks 8–12)

These are the **clone-and-follow** labs for the Build / Models / Capstone arc.
Each `week-NN.md` maps a deck lab segment to the exact commands that reproduce
the demonstrated result against the real Elixir/Jido engine — so a learner who
clones this umbrella sees the same numbers the instructor shows.

Every lab is governed by the **9-point build gate**
(`curriculum_app/content/lessons/weeks-08-12-build-gate.md`) and the per-week
math specs (`week-NN-math-spec.md`). The math here *applies* the framework; it
never reproduces book prose (see `BOOK_SOURCES.md`).

## Clone and set up

```bash
git clone <this-umbrella> active_inference
cd active_inference
mix deps.get
mix compile
```

Run any command below **from the umbrella root** (`active_inference/`). App-local
runs miss sibling apps.

## Three ways to run a lab

1. **Reproduce the gate (fastest).** Every lab result is pinned by a test:

   ```bash
   mix test apps/active_inference_core/test/trust_gate_test.exs   # numerical anchors
   mix test apps/agent_plane/test/build_gate_test.exs            # the 9 gates
   ```

2. **Explore in IEx.** Each week file gives a copy-paste `iex -S mix` snippet.

3. **Run in the app (`/labs`).** Boot the workbench and open the linked recipe:

   ```bash
   mix phx.server   # then visit the /labs?recipe=<slug> link in each week file
   ```

   The `/labs` page boots a supervised Jido agent in the chosen world and streams
   the equation traces to `/glass`. Recipes are validated by
   `mix cookbook.validate` (50 recipes, 0 errors).

## The arc

| Week | Lab | Core modules | In-app recipe |
|------|-----|--------------|---------------|
| 8  | [Perception as inference (VMP)](week-08.md) | `DiscreteTime.{update_state_beliefs,variational_free_energy}` | `bayes-one-step-coin` |
| 9  | [The generative model + learning A](week-09.md) | `BundleBuilder`, `Actions.DirichletUpdateA` | `dirichlet-learn-a-matrix` |
| 10 | [Choosing softly (γ, EFE)](week-10.md) | `DiscreteTime.{policy_posterior,expected_free_energy}` | `efe-decompose-epistemic-pragmatic` |
| 11 | [Markov blankets, carefully](week-11.md) | `MarkovBlanket`, `SharedContracts.*` | `perception-blanket-channel-choice` |
| 12 | [Capstone: cue task + ablations](week-12.md) | `BundleBuilder.CueTask` | `epistemic-disambiguate-before-exploit` |

## Two open items (instructor note)

- **Week 8 inference path** is taught as **mean-field VMP** (the implemented
  method); the `(lnB)s` vs `ln(Bs)` cross-term pairing is pending a UNI ruling.
- **Week 12 cue-*seeking*** emerges robustly only under sophisticated/counterfactual
  inference; the basic flat-policy EFE values the cue weakly. The labs assert the
  robust halves (informative cue + exploit) and the five ablations; the
  single-shot cue-preference is tracked as a UNI question.
