defmodule WorldModels.Spec.Topology do
  @moduledoc """
  Plan §5 + §12 Phase 7 — the canvas topology a Builder canvas edits.

  A topology is a small map of `%{nodes: [...], edges: [...]}` where:

  - a node is `%{id, type, params \\ %{}, position \\ %{x, y}}`
  - an edge is `%{from_node, from_port, to_node, to_port}`

  Every node type declares its input/output ports with typed sockets so
  the validator can reject nonsense edges client-side (via litegraph's
  built-in slot-type system) and server-side (this module).

  `validate/1` runs the authoritative server-side check. It returns
  `:ok` or `{:error, [reason, ...]}` where reason is a tagged tuple the
  LiveView can render inline on the offending node.
  """

  @type node_spec :: %{
          required(:id) => String.t(),
          required(:type) => String.t(),
          optional(:params) => map(),
          optional(:position) => %{x: number(), y: number()},
          optional(:equation_ids) => [String.t()]
        }

  @type edge_spec :: %{
          required(:from_node) => String.t(),
          required(:from_port) => String.t(),
          required(:to_node) => String.t(),
          required(:to_port) => String.t()
        }

  @type t :: %{
          required(:nodes) => [node_spec()],
          required(:edges) => [edge_spec()],
          optional(:required_types) => [String.t()]
        }

  @type error ::
          {:dangling_edge, edge_spec()}
          | {:unknown_node_type, String.t()}
          | {:unknown_port, {String.t(), String.t(), :in | :out}}
          | {:port_type_mismatch, %{edge: edge_spec(), from: atom(), to: atom()}}
          | {:missing_required_type, String.t()}

  # Port schema per node type. `:ports` is `%{in: %{name => type}, out: %{name => type}}`.
  @node_types %{
    "bundle" => %{
      description: "Generative-model bundle (A/B/C/D/E priors)",
      ports: %{
        in: %{},
        out: %{"bundle" => :bundle}
      }
    },
    "archetype" => %{
      description: "Archetype seed — expands into the full topology",
      ports: %{
        in: %{},
        out: %{"topology" => :topology}
      }
    },
    "equation" => %{
      description: "Reference to a registry equation",
      ports: %{
        in: %{},
        out: %{"equation_id" => :equation_id}
      }
    },
    "perceive" => %{
      description: "eq_4_13_state_belief_update — update beliefs from obs",
      ports: %{
        in: %{"bundle" => :bundle, "obs" => :obs},
        out: %{"beliefs" => :belief}
      }
    },
    "plan" => %{
      description: "eq_4_14_policy_posterior — compute π",
      ports: %{
        in: %{"bundle" => :bundle, "beliefs" => :belief},
        out: %{"policy_posterior" => :policy_posterior, "action" => :action}
      }
    },
    "act" => %{
      description: "Emit action packet to the world plane",
      ports: %{
        in: %{"action" => :action},
        out: %{"signal" => :signal}
      }
    },

    # -- Phase C — matrix-level generative-model blocks ---------------------

    "likelihood_matrix" => %{
      description: "A ∈ ℝ^(|obs| × |states|) — maps hidden states to observations",
      ports: %{in: %{}, out: %{"A" => :matrix_a}}
    },
    "transition_matrix" => %{
      description: "B ∈ ℝ^(|actions| × |states| × |states|) — per-action state dynamics",
      ports: %{in: %{}, out: %{"B" => :matrix_b}}
    },
    "preference_vector" => %{
      description: "C ∈ ℝ^|obs| — log-odds preferences over observations",
      ports: %{in: %{}, out: %{"C" => :vector_c}}
    },
    "prior_vector" => %{
      description: "D ∈ ℝ^|states| — prior over hidden states at t=0",
      ports: %{in: %{}, out: %{"D" => :vector_d}}
    },
    "bundle_assembler" => %{
      description: "Combines A, B, C, D into a unified bundle",
      ports: %{
        in: %{"A" => :matrix_a, "B" => :matrix_b, "C" => :vector_c, "D" => :vector_d},
        out: %{"bundle" => :bundle}
      }
    },

    # -- Phase G — sophisticated planner ------------------------------------

    "sophisticated_planner" => %{
      description: "Deep-horizon belief-propagated policy search (Ch 7)",
      ports: %{
        in: %{"bundle" => :bundle, "beliefs" => :belief},
        out: %{"policy_posterior" => :policy_posterior, "action" => :action}
      }
    },

    # -- Phase H — Dirichlet learners ---------------------------------------

    "dirichlet_a_learner" => %{
      description: "Online Dirichlet update to the A matrix (eq 7.10)",
      ports: %{
        in: %{"bundle" => :bundle, "obs" => :obs, "beliefs" => :belief},
        out: %{"bundle" => :bundle}
      }
    },
    "dirichlet_b_learner" => %{
      description: "Online Dirichlet update to the B tensor per action (eq 7.10)",
      ports: %{
        in: %{"bundle" => :bundle, "beliefs" => :belief, "action" => :action},
        out: %{"bundle" => :bundle}
      }
    },

    # -- Phase F — Skills & Workflows ---------------------------------------

    "skill" => %{
      description: "Drop-in Jido.Skill (entropy, KL, softmax, …)",
      ports: %{in: %{"in" => :any}, out: %{"out" => :any}}
    },
    "workflow" => %{
      description: "Ordered chain of skills — compiled to a Jido.Workflow at deploy",
      ports: %{in: %{"in" => :any}, out: %{"out" => :any}}
    },
    "epistemic_preference" => %{
      description: "Planner configurator — zeroes pragmatic term in G",
      ports: %{in: %{"bundle" => :bundle}, out: %{"bundle" => :bundle}}
    },

    # -- Phase E — composition / hierarchical agents ------------------------

    "meta_agent" => %{
      description: "Hierarchical meta-agent whose policy becomes the sub-agent's preference",
      ports: %{in: %{"obs" => :obs}, out: %{"preference" => :vector_c}}
    },
    "sub_agent" => %{
      description: "Hierarchical sub-agent receiving preferences from a meta",
      ports: %{
        in: %{"bundle" => :bundle, "preference" => :vector_c, "obs" => :obs},
        out: %{"action" => :action}
      }
    }
  }

  @spec node_types() :: %{String.t() => map()}
  def node_types, do: @node_types

  @spec validate(t()) :: :ok | {:error, [error()]}
  def validate(topology) when is_map(topology) do
    nodes = Map.get(topology, :nodes, [])
    edges = Map.get(topology, :edges, [])
    required = Map.get(topology, :required_types, [])

    errors =
      []
      |> check_node_types(nodes)
      |> check_required_types(nodes, required)
      |> check_edges(nodes, edges)

    case errors do
      [] -> :ok
      errs -> {:error, Enum.reverse(errs)}
    end
  end

  # -- Individual checks ----------------------------------------------------

  defp check_node_types(errs, nodes) do
    Enum.reduce(nodes, errs, fn n, acc ->
      if Map.has_key?(@node_types, n.type),
        do: acc,
        else: [{:unknown_node_type, n.type} | acc]
    end)
  end

  # `bundle` and `bundle_assembler` are interchangeable generative-model
  # sources — a topology that satisfies one satisfies the other. Similarly
  # `sub_agent` is a composite that encapsulates perceive/plan/act, so a
  # hierarchical composition whose sub_agent is wired satisfies the
  # action-loop requirements.
  @equivalences %{
    "bundle" => ["bundle_assembler"],
    "bundle_assembler" => ["bundle"],
    "sophisticated_planner" => ["plan"],
    "perceive" => ["sub_agent"],
    "plan" => ["sophisticated_planner", "sub_agent"],
    "act" => ["sub_agent"]
  }

  defp check_required_types(errs, nodes, required) do
    present = MapSet.new(nodes, & &1.type)

    Enum.reduce(required, errs, fn t, acc ->
      if satisfied?(t, present),
        do: acc,
        else: [{:missing_required_type, t} | acc]
    end)
  end

  defp satisfied?(type, present) do
    MapSet.member?(present, type) or
      Enum.any?(Map.get(@equivalences, type, []), &MapSet.member?(present, &1))
  end

  defp check_edges(errs, nodes, edges) do
    by_id = Map.new(nodes, &{&1.id, &1})

    Enum.reduce(edges, errs, fn e, acc ->
      from = Map.get(by_id, e.from_node)
      to = Map.get(by_id, e.to_node)

      cond do
        is_nil(from) or is_nil(to) ->
          [{:dangling_edge, e} | acc]

        true ->
          check_port_types(acc, e, from, to)
      end
    end)
  end

  defp check_port_types(errs, edge, from, to) do
    from_spec = @node_types[from.type]
    to_spec = @node_types[to.type]

    from_type = from_spec && get_in(from_spec, [:ports, :out, edge.from_port])
    to_type = to_spec && get_in(to_spec, [:ports, :in, edge.to_port])

    cond do
      is_nil(from_spec) or is_nil(to_spec) ->
        errs

      is_nil(from_type) ->
        [{:unknown_port, {from.type, edge.from_port, :out}} | errs]

      is_nil(to_type) ->
        [{:unknown_port, {to.type, edge.to_port, :in}} | errs]

      from_type != to_type ->
        [{:port_type_mismatch, %{edge: edge, from: from_type, to: to_type}} | errs]

      true ->
        errs
    end
  end
end
