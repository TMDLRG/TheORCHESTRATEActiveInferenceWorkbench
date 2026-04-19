defmodule WorkbenchWeb.LearningCatalog do
  @moduledoc """
  Static catalogue of the seven standalone learning-lab HTML simulators and
  their relationships to Workbench surfaces (equations, examples, builder
  blocks, Glass signals).

  This is deliberately a plain-data module — no state, no process, no Ecto —
  so every LiveView and controller can read it with zero overhead.

  The catalogue is the single source of truth for:
    * hub rendering (`LearningLive.Hub`)
    * sidebars on `/guide`, `/guide/examples/:slug`, `/equations/:id`
    * persona-picker cross-links (`/learn/path`)
    * in-lab breadcrumbs (the Shell fetches titles from here at build time)
  """

  @doc """
  All seven labs, ordered by the difficulty arc (L1→L5) the book follows.
  """
  @spec labs() :: [map()]
  def labs do
    [
      %{
        slug: "bayes-chips",
        file: "BayesChips.html",
        title: "Bayes Machine",
        hero:
          "New evidence changes how likely an idea is, proportionally to how much that evidence is expected under it.",
        blurb: "Mechanical 100-chip simulator that makes Bayes' rule a counted fraction.",
        icon: "🎯",
        levels: [:P1, :P2, :P3, :P4, :P5],
        tier: :L1,
        time_min: 5,
        equations: ~w(bayes_rule posterior_odds),
        examples: ~w(l1_bayes_basic),
        follow_ups: ["pomdp-machine", "jumping-frog"]
      },
      %{
        slug: "pomdp-machine",
        file: "active_inference_pomdp_machine.html",
        title: "Clockwork POMDP Machine",
        hero:
          "You can't see inside — guess what's likely, imagine what would happen if you acted, then pick the action that best serves you.",
        blurb: "Discrete POMDP active inference with policies, F, G, and the softmax over −G−F.",
        icon: "⚙",
        levels: [:P2, :P3, :P4, :P5],
        tier: :L2,
        time_min: 10,
        equations: ~w(message_passing_4_13 variational_free_energy expected_free_energy),
        examples: ~w(l2_pomdp_basic l3_epistemic_explorer),
        follow_ups: ["jumping-frog", "anatomy-studio"]
      },
      %{
        slug: "free-energy-forge",
        file: "free_energy_forge_eq419.html",
        title: "Free Energy Forge",
        hero:
          "Three kinds of disagreement — with what you see, with how things flow, and with what you expected — each weighted by how strict we are about them.",
        blurb: "Equation 4.19 in a 3-dimensional linear world with generalized coordinates.",
        icon: "🔥",
        levels: [:P3, :P4, :P5],
        tier: :L3,
        time_min: 10,
        equations: ~w(free_energy_4_19),
        examples: ~w(l3_predictive_coding),
        follow_ups: ["laplace-tower", "atlas"]
      },
      %{
        slug: "laplace-tower",
        file: "laplace_tower_predictive_coding_builder.html",
        title: "Laplace Tower",
        hero:
          "Build a tower. Each floor tries to explain the floor below. When every floor agrees, the tower is stable.",
        blurb:
          "Multi-level predictive coding with Laplace-Gaussian beliefs and action that only changes sensory input.",
        icon: "🗼",
        levels: [:P3, :P4, :P5],
        tier: :L3,
        time_min: 12,
        equations: ~w(laplace_approx predictive_coding_hierarchy),
        examples: ~w(l4_dirichlet_learner),
        follow_ups: ["atlas", "anatomy-studio"]
      },
      %{
        slug: "anatomy-studio",
        file: "anatomy_of_inference_studio.html",
        title: "Anatomy of Inference Studio",
        hero: "Habits, plans, goals, predictions, and actions are one machine working together.",
        blurb: "Figure 5.5 — the scalar-EFE proxy plus continuous predictive coding bridged.",
        icon: "🧠",
        levels: [:P3, :P4, :P5],
        tier: :L4,
        time_min: 10,
        equations: ~w(scalar_efe_proxy anatomy_5_5),
        examples: ~w(l4_dirichlet_learner l5_hierarchical_composition),
        follow_ups: ["atlas"]
      },
      %{
        slug: "atlas",
        file: "active_inference_atlas_educational_sim.html",
        title: "Active Inference Atlas",
        hero:
          "The same F-minimizing machinery with different precision knobs plays different roles in a brain-like story.",
        blurb: "Cortical microcircuit + neuromodulator (ACh, NA, DA, 5-HT) precision atlas.",
        icon: "🗺",
        levels: [:P4, :P5],
        tier: :L5,
        time_min: 15,
        equations: ~w(free_energy_4_19 scalar_efe_proxy),
        examples: ~w(l5_hierarchical_composition),
        follow_ups: []
      },
      %{
        slug: "jumping-frog",
        file: "jumping_frog_generative_model_lab.html",
        title: "Jumping Frog Generative Model Lab",
        hero:
          "Many clues, one guess. Picking an action that gets you a useful clue beats guessing.",
        blurb:
          "Multi-modal concept inference with action-as-precision-gain and information-gain action selection.",
        icon: "🐸",
        levels: [:P2, :P3, :P4, :P5],
        tier: :L2,
        time_min: 8,
        equations: ~w(bayes_rule expected_bayesian_surprise),
        examples: ~w(l3_epistemic_explorer),
        follow_ups: ["anatomy-studio", "atlas"]
      }
    ]
  end

  @doc "Look up a lab by its slug."
  @spec find(binary()) :: map() | nil
  def find(slug), do: Enum.find(labs(), fn l -> l.slug == slug end)

  @doc "Labs filtered by learning path (kid|real|equation|derivation)."
  @spec for_path(atom() | binary()) :: [map()]
  def for_path(path) when is_binary(path), do: for_path(String.to_atom(path))
  def for_path(:kid), do: Enum.filter(labs(), fn l -> :P1 in l.levels or :P2 in l.levels end)
  def for_path(:real), do: Enum.filter(labs(), fn l -> :P3 in l.levels end)
  def for_path(:equation), do: Enum.filter(labs(), fn l -> :P4 in l.levels end)
  def for_path(:derivation), do: Enum.filter(labs(), fn l -> :P5 in l.levels end)
  def for_path(_), do: labs()

  @doc "Ordered list of four learning paths with their metadata for the picker."
  @spec paths() :: [map()]
  def paths do
    [
      %{
        id: :kid,
        icon: "🌱",
        title: "I want the story",
        desc: "Narrative, physical objects, one hero quantity at a time."
      },
      %{
        id: :real,
        icon: "🧭",
        title: "I want real-world examples",
        desc: "Everyday analogies, reason-through-it prose, a practical mission."
      },
      %{
        id: :equation,
        icon: "🛠️",
        title: "I want the equations",
        desc: "Math tied to code, short derivations, parameter sweeps."
      },
      %{
        id: :derivation,
        icon: "🎓",
        title: "I want the full derivation",
        desc: "Proof sketches + canonical references."
      }
    ]
  end

  @doc "Human-readable label for a path atom."
  def path_label(:kid), do: "🌱 Story"
  def path_label(:real), do: "🧭 Real-world"
  def path_label(:equation), do: "🛠️ Equation"
  def path_label(:derivation), do: "🎓 Derivation"
  def path_label(other) when is_binary(other), do: path_label(String.to_existing_atom(other))
  def path_label(_), do: "🧭 Real-world"
end
