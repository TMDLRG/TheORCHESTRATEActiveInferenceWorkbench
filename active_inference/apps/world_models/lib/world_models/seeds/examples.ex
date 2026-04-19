defmodule WorldModels.Seeds.Examples do
  @moduledoc """
  Lego-uplift Phase C — seed the five prebuilt example specs into Mnesia at
  boot so that `/guide/examples/:slug → /builder/:spec_id` opens a populated
  canvas.

  Idempotent: `AgentRegistry.register_spec/1` overwrites on same `:id`.
  """

  alias WorldModels.{AgentRegistry, Spec}

  @seed_ids [
    "example-l1-hello-pomdp",
    "example-l2-epistemic-explorer",
    "example-l3-sophisticated-planner",
    "example-l4-dirichlet-learner",
    "example-l5-hierarchical-composition"
  ]

  @spec seed_all!() :: :ok
  def seed_all! do
    Enum.each(specs(), fn spec ->
      case AgentRegistry.register_spec(spec) do
        {:ok, _} -> :ok
        {:error, reason} -> raise "Seed #{spec.id} failed: #{inspect(reason)}"
      end
    end)

    :ok
  end

  @spec ids() :: [String.t()]
  def ids, do: @seed_ids

  # -- Specs ----------------------------------------------------------------

  defp specs do
    [
      l1_hello_pomdp(),
      l2_epistemic_explorer(),
      l3_sophisticated_planner(),
      l4_dirichlet_learner(),
      l5_hierarchical_composition()
    ]
  end

  defp l1_hello_pomdp do
    Spec.new(%{
      id: "example-l1-hello-pomdp",
      archetype_id: "pomdp_maze",
      family_id: "Partially Observable Markov Decision Process (POMDP)",
      primary_equation_ids: [
        "eq_4_5_pomdp_likelihood",
        "eq_4_6_pomdp_prior_over_states",
        "eq_4_11_vfe_linear_algebra",
        "eq_4_13_state_belief_update",
        "eq_4_14_policy_posterior"
      ],
      bundle_params: %{horizon: 3, policy_depth: 3, preference_strength: 4.0},
      blanket: blanket_defaults(),
      topology: l1_topology(),
      created_by: "seed/examples"
    })
  end

  defp l2_epistemic_explorer do
    Spec.new(%{
      id: "example-l2-epistemic-explorer",
      archetype_id: "pomdp_maze",
      family_id: "Partially Observable Markov Decision Process (POMDP)",
      primary_equation_ids: [
        "eq_2_6_expected_free_energy",
        "eq_4_10_efe_linear_algebra",
        "eq_4_14_policy_posterior"
      ],
      bundle_params: %{horizon: 5, policy_depth: 5, preference_strength: 0.0},
      blanket: blanket_defaults(),
      topology: l2_topology(),
      created_by: "seed/examples"
    })
  end

  defp l3_sophisticated_planner do
    Spec.new(%{
      id: "example-l3-sophisticated-planner",
      archetype_id: "pomdp_maze",
      family_id: "Partially Observable Markov Decision Process (POMDP)",
      primary_equation_ids: [
        "eq_4_13_state_belief_update",
        "eq_4_14_policy_posterior",
        "eq_4_10_efe_linear_algebra"
      ],
      # horizon=4 (4⁴=256 policies) keeps per-step compute under a
      # few seconds without sacrificing the "deeper than L1" story.
      # When the sophisticated-plan dispatch lands (separate phase)
      # we can raise this again because beam pruning will cap the
      # per-step cost independent of horizon.
      bundle_params: %{horizon: 4, policy_depth: 4, preference_strength: 4.0},
      blanket: blanket_defaults(),
      topology: l3_topology(),
      created_by: "seed/examples"
    })
  end

  defp l4_dirichlet_learner do
    Spec.new(%{
      id: "example-l4-dirichlet-learner",
      archetype_id: "dirichlet_pomdp",
      family_id: "Dirichlet-Parameterised POMDP (learning)",
      primary_equation_ids: [
        "eq_7_10_dirichlet_update",
        "eq_4_13_state_belief_update",
        "eq_4_14_policy_posterior"
      ],
      bundle_params: %{horizon: 5, policy_depth: 5, preference_strength: 4.0, weak_priors?: true},
      blanket: blanket_defaults(),
      topology: l4_topology(),
      created_by: "seed/examples"
    })
  end

  defp l5_hierarchical_composition do
    Spec.new(%{
      id: "example-l5-hierarchical-composition",
      archetype_id: "pomdp_maze",
      family_id: "Partially Observable Markov Decision Process (POMDP)",
      primary_equation_ids: [
        "eq_4_13_state_belief_update",
        "eq_4_14_policy_posterior"
      ],
      bundle_params: %{horizon: 3, policy_depth: 3, preference_strength: 4.0},
      blanket: blanket_defaults(),
      topology: l5_topology(),
      created_by: "seed/examples"
    })
  end

  # Inlined to avoid a cross-app dep on :shared_contracts. Kept in sync
  # with `SharedContracts.Blanket.maze_default/0`; if that surface changes,
  # this value needs to change too.
  defp blanket_defaults do
    %{
      observation_channels: [:wall_north, :wall_south, :wall_east, :wall_west, :goal_cue, :tile],
      action_vocabulary: [:move_north, :move_south, :move_east, :move_west]
    }
  end

  # -- Topologies — authored as matrix-level block graphs -------------------

  defp l1_topology do
    %{
      nodes: [
        %{
          id: "n_a",
          type: "likelihood_matrix",
          params: %{"n_obs" => 2, "n_states" => 9, "init" => "uniform"},
          position: %{x: 40, y: 60}
        },
        %{
          id: "n_b",
          type: "transition_matrix",
          params: %{"n_states" => 9, "n_actions" => 4, "init" => "deterministic_maze"},
          position: %{x: 40, y: 180}
        },
        %{
          id: "n_c",
          type: "preference_vector",
          params: %{"n_obs" => 2, "goal_weight" => 4.0, "epistemic_only?" => false},
          position: %{x: 40, y: 300}
        },
        %{
          id: "n_d",
          type: "prior_vector",
          params: %{"n_states" => 9, "init" => "point_mass", "point_mass_idx" => 3},
          position: %{x: 40, y: 420}
        },
        %{id: "n_asm", type: "bundle_assembler", params: %{}, position: %{x: 260, y: 200}},
        %{
          id: "n_perceive",
          type: "perceive",
          params: %{"n_iters" => 8},
          position: %{x: 480, y: 120}
        },
        %{
          id: "n_plan",
          type: "plan",
          params: %{"temperature" => 1.0},
          position: %{x: 700, y: 120}
        },
        %{id: "n_act", type: "act", params: %{}, position: %{x: 920, y: 120}}
      ],
      edges: [
        %{from_node: "n_a", from_port: "A", to_node: "n_asm", to_port: "A"},
        %{from_node: "n_b", from_port: "B", to_node: "n_asm", to_port: "B"},
        %{from_node: "n_c", from_port: "C", to_node: "n_asm", to_port: "C"},
        %{from_node: "n_d", from_port: "D", to_node: "n_asm", to_port: "D"},
        %{from_node: "n_asm", from_port: "bundle", to_node: "n_perceive", to_port: "bundle"},
        %{from_node: "n_asm", from_port: "bundle", to_node: "n_plan", to_port: "bundle"},
        %{from_node: "n_perceive", from_port: "beliefs", to_node: "n_plan", to_port: "beliefs"},
        %{from_node: "n_plan", from_port: "action", to_node: "n_act", to_port: "action"}
      ],
      required_types: ["bundle_assembler", "perceive", "plan", "act"]
    }
  end

  defp l2_topology do
    base = l1_topology()

    epistemic = %{
      id: "n_epistemic",
      type: "epistemic_preference",
      params: %{"epistemic_weight" => 1.0, "pragmatic_weight" => 0.0},
      position: %{x: 260, y: 320}
    }

    # Insert epistemic_preference between the assembler and the plan node.
    nodes = base.nodes ++ [epistemic]

    # Rewire: asm.bundle → epistemic; epistemic.bundle → plan
    edges =
      base.edges
      |> Enum.reject(fn e -> e.from_node == "n_asm" and e.to_node == "n_plan" end)
      |> Kernel.++([
        %{from_node: "n_asm", from_port: "bundle", to_node: "n_epistemic", to_port: "bundle"},
        %{from_node: "n_epistemic", from_port: "bundle", to_node: "n_plan", to_port: "bundle"}
      ])

    %{base | nodes: nodes, edges: edges}
  end

  defp l3_topology do
    base = l1_topology()

    # Replace plan with sophisticated_planner, keeping the same wiring.
    # Beam-width pruning is essential — exhaustive horizon-8 enumeration
    # is 65k policies and swamps the initial belief sweep.
    nodes =
      Enum.map(base.nodes, fn
        %{id: "n_plan"} = n ->
          %{
            n
            | type: "sophisticated_planner",
              params: %{
                "horizon" => 5,
                "tree_policy" => "beam",
                "beam_width" => 8,
                "discount" => 0.95
              }
          }

        other ->
          other
      end)

    %{
      base
      | nodes: nodes,
        required_types: ["bundle_assembler", "perceive", "sophisticated_planner", "act"]
    }
  end

  defp l4_topology do
    base = l1_topology()

    learners = [
      %{
        id: "n_dir_a",
        type: "dirichlet_a_learner",
        params: %{"prior_concentration" => 0.5, "learning_rate" => 1.0},
        position: %{x: 480, y: 320}
      },
      %{
        id: "n_dir_b",
        type: "dirichlet_b_learner",
        params: %{"prior_concentration" => 0.5, "learning_rate" => 1.0},
        position: %{x: 700, y: 320}
      }
    ]

    # A/B start deliberately weak — override the L1 defaults in-place.
    nodes =
      base.nodes
      |> Enum.map(fn
        %{id: "n_a"} = n -> %{n | params: Map.put(n.params, "init", "uniform")}
        %{id: "n_b"} = n -> %{n | params: Map.put(n.params, "init", "uniform")}
        other -> other
      end)
      |> Kernel.++(learners)

    edges =
      base.edges ++
        [
          %{from_node: "n_asm", from_port: "bundle", to_node: "n_dir_a", to_port: "bundle"},
          %{
            from_node: "n_perceive",
            from_port: "beliefs",
            to_node: "n_dir_a",
            to_port: "beliefs"
          },
          %{from_node: "n_asm", from_port: "bundle", to_node: "n_dir_b", to_port: "bundle"},
          %{
            from_node: "n_perceive",
            from_port: "beliefs",
            to_node: "n_dir_b",
            to_port: "beliefs"
          },
          %{from_node: "n_plan", from_port: "action", to_node: "n_dir_b", to_port: "action"}
        ]

    %{base | nodes: nodes, edges: edges}
  end

  defp l5_topology do
    %{
      nodes: [
        %{
          id: "n_meta",
          type: "meta_agent",
          params: %{"sector_count" => 4, "macro_horizon" => 3},
          position: %{x: 60, y: 80}
        },
        %{
          id: "n_sub",
          type: "sub_agent",
          params: %{"micro_horizon" => 2},
          position: %{x: 420, y: 80}
        },
        %{id: "n_sub_asm", type: "bundle_assembler", params: %{}, position: %{x: 260, y: 260}},
        %{
          id: "n_sub_a",
          type: "likelihood_matrix",
          params: %{"n_obs" => 2, "n_states" => 121, "init" => "uniform"},
          position: %{x: 40, y: 260}
        },
        %{
          id: "n_sub_b",
          type: "transition_matrix",
          params: %{"n_states" => 121, "n_actions" => 4, "init" => "deterministic_maze"},
          position: %{x: 40, y: 360}
        },
        %{
          id: "n_sub_d",
          type: "prior_vector",
          params: %{"n_states" => 121, "init" => "uniform"},
          position: %{x: 40, y: 460}
        }
      ],
      edges: [
        %{from_node: "n_sub_a", from_port: "A", to_node: "n_sub_asm", to_port: "A"},
        %{from_node: "n_sub_b", from_port: "B", to_node: "n_sub_asm", to_port: "B"},
        %{from_node: "n_sub_d", from_port: "D", to_node: "n_sub_asm", to_port: "D"},
        %{from_node: "n_sub_asm", from_port: "bundle", to_node: "n_sub", to_port: "bundle"},
        %{from_node: "n_meta", from_port: "preference", to_node: "n_sub", to_port: "preference"}
      ],
      required_types: ["meta_agent", "sub_agent"]
    }
  end
end
