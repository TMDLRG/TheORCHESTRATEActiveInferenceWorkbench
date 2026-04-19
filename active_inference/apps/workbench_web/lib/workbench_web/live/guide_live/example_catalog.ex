defmodule WorkbenchWeb.GuideLive.ExampleCatalog do
  @moduledoc """
  Static catalogue for the five prebuilt Active Inference examples.

  Each entry is rendered both in the listing (`/guide/examples`) and the
  detail page (`/guide/examples/:slug`). The `:spec_id` field, when set,
  links to a seeded `WorldModels.Spec` — the Builder opens it read-only
  or lets the user fork and tweak.
  """

  @examples [
    %{
      slug: "l1-hello-pomdp",
      level: "L1",
      name: "Hello POMDP",
      tagline: "The core Active Inference loop on a 1-step maze.",
      world: "tiny_open_goal",
      world_note:
        "3×3 single-corridor maze. One east step solves it — perfect to verify the A/B/C/D → Perceive → Plan → Act pipeline end-to-end.",
      blocks: [
        "likelihood_matrix (A)",
        "transition_matrix (B)",
        "preference_vector (C)",
        "prior_vector (D)",
        "bundle_assembler",
        "perceive",
        "plan",
        "act"
      ],
      teaches:
        "The core POMDP loop: beliefs are updated from observations (eq 4.13), the policy posterior selects π from G (eq 4.14), and the action is emitted to the world.",
      equations: [
        "eq_4_5_pomdp_likelihood",
        "eq_4_6_pomdp_prior_over_states",
        "eq_4_11_vfe_linear_algebra",
        "eq_4_13_state_belief_update",
        "eq_4_14_policy_posterior"
      ],
      spec_id: "example-l1-hello-pomdp"
    },
    %{
      slug: "l2-epistemic-explorer",
      level: "L2",
      name: "Epistemic explorer",
      tagline: "Zero pragmatic preference — the agent seeks information for its own sake.",
      world: "forked_paths",
      world_note:
        "7×5 maze with two routes. With C ≈ 0, only the epistemic term of G is non-zero; the agent prefers states that resolve uncertainty about the layout.",
      blocks: [
        "likelihood_matrix (A)",
        "transition_matrix (B)",
        "preference_vector (C = 0)",
        "prior_vector (D)",
        "bundle_assembler",
        "perceive",
        "epistemic_preference (Skill)",
        "plan",
        "act"
      ],
      teaches:
        "The EFE decomposition (eq 2.6 / 4.10). G has an epistemic term (information gain about states) and a pragmatic term (distance to C). Zero C isolates epistemic drive — a minimal demonstration that active inference is also a theory of curiosity.",
      equations: [
        "eq_2_6_expected_free_energy",
        "eq_4_10_efe_linear_algebra",
        "eq_4_14_policy_posterior"
      ],
      spec_id: "example-l2-epistemic-explorer"
    },
    %{
      slug: "l3-sophisticated-planner",
      level: "L3",
      name: "Sophisticated planner",
      tagline: "Deep-horizon iterative policy search that solves the deceptive dead-end.",
      world: "deceptive_dead_end",
      world_note:
        "7×6 maze engineered to trap a greedy one-step planner. UAT confirmed the naïve `plan` block wall-bumps here; the sophisticated planner solves it by propagating beliefs recursively under candidate policies.",
      blocks: [
        "likelihood_matrix (A)",
        "transition_matrix (B)",
        "preference_vector (C)",
        "prior_vector (D)",
        "bundle_assembler",
        "perceive",
        "sophisticated_planner",
        "act"
      ],
      teaches:
        "Sophisticated inference (Ch 7): at each step, propagate beliefs forward under every candidate policy, compute G recursively at each horizon, and re-normalise. The rollout tree is visible in Glass, not just a scalar G.",
      equations: [
        "eq_4_13_state_belief_update",
        "eq_4_14_policy_posterior",
        "eq_4_10_efe_linear_algebra"
      ],
      spec_id: "example-l3-sophisticated-planner"
    },
    %{
      slug: "l4-dirichlet-learner",
      level: "L4",
      name: "Online Dirichlet learner",
      tagline: "Agent starts with wrong A/B priors and learns its world model online.",
      world: "corridor_turns",
      world_note:
        "5×5 maze needing planning horizon > 1. Spec is seeded with deliberately miscalibrated A and B priors; the agent must learn structure while navigating.",
      blocks: [
        "likelihood_matrix (A, weak prior)",
        "transition_matrix (B, weak prior)",
        "preference_vector (C)",
        "prior_vector (D)",
        "bundle_assembler",
        "perceive",
        "dirichlet_a_learner",
        "dirichlet_b_learner",
        "plan",
        "act"
      ],
      teaches:
        "Structure / parameter learning via Dirichlet counts (eq 7.10). After each observation and action, the A and B pseudo-counts are updated. Glass shows the count tensors evolving until they stabilise.",
      equations: [
        "eq_7_10_dirichlet_update",
        "eq_4_13_state_belief_update",
        "eq_4_14_policy_posterior"
      ],
      spec_id: "example-l4-dirichlet-learner"
    },
    %{
      slug: "l5-hierarchical-composition",
      level: "L5",
      name: "Hierarchical composition",
      tagline: "A meta-agent sets the preferences of a sub-agent through the signal broker.",
      world: "hierarchical_maze",
      world_note:
        "11×11 maze logically partitioned into sectors. The meta-agent treats sectors as hidden states; the sub-agent treats tiles as hidden states. Each macro step, the meta's policy posterior writes the sub's preference vector C.",
      blocks: [
        "meta_agent (archetype)",
        "sub_agent (archetype)",
        "composition_wire (meta.π → sub.C)",
        "signal_broker (runtime)"
      ],
      teaches:
        "Hierarchical active inference. Two Jido agents coordinate with no raw `send/2` — only `Jido.Signal` routed by the composition broker. Glass shows signals flowing between agent_ids, not pids.",
      equations: [
        "eq_4_13_state_belief_update",
        "eq_4_14_policy_posterior"
      ],
      spec_id: "example-l5-hierarchical-composition"
    }
  ]

  @spec all() :: [map()]
  def all, do: @examples

  @spec fetch(String.t()) :: map() | nil
  def fetch(slug), do: Enum.find(@examples, &(&1.slug == slug))

  @spec slugs() :: [String.t()]
  def slugs, do: Enum.map(@examples, & &1.slug)
end
