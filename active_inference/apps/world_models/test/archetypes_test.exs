defmodule WorldModels.ArchetypesTest do
  @moduledoc """
  Plan §12 Phase 7a — Archetypes + Spec.Topology.

  An archetype is a seed for the Builder canvas: it declares the node
  types, the default topology wiring them together, the equation IDs
  they're grounded in, and a Zoi-shaped param schema. Dragging an
  archetype card onto the empty canvas expands into the seeded topology.
  """

  use ExUnit.Case, async: true

  alias ActiveInferenceCore.Equations
  alias WorldModels.{Archetypes, Spec}

  describe "T1: Archetypes.all/0 returns MVP archetypes" do
    test "pomdp_maze is listed" do
      all = Archetypes.all()
      assert is_list(all)
      assert Enum.any?(all, &(&1.id == "pomdp_maze"))
    end

    test "each archetype has the required fields" do
      for a <- Archetypes.all() do
        assert is_binary(a.id)
        assert is_binary(a.name)
        assert is_binary(a.family_id)
        assert is_list(a.primary_equation_ids)

        assert a.mvp_suitability in [
                 :mvp_primary,
                 :mvp_secondary,
                 :mvp_registry_only,
                 :future_work
               ]
      end
    end

    test "disabled archetypes (registry-only) are flagged" do
      # Continuous is still registry-only; Dirichlet was flipped to
      # runnable in Lego-uplift Phase H when the learning actions shipped.
      ids = Archetypes.all() |> Enum.map(& &1.id)
      assert "continuous_generalized_filter" in ids
      assert "dirichlet_pomdp" in ids

      continuous = Archetypes.fetch("continuous_generalized_filter")
      assert continuous.disabled? == true

      dirichlet = Archetypes.fetch("dirichlet_pomdp")
      assert dirichlet.disabled? == false

      pomdp = Archetypes.fetch("pomdp_maze")
      assert pomdp.disabled? == false
    end
  end

  describe "T2: equation references resolve in the registry" do
    test "every archetype's primary_equation_ids land in Equations.fetch/1" do
      for a <- Archetypes.all(), eq_id <- a.primary_equation_ids do
        assert %ActiveInferenceCore.Equation{} = Equations.fetch(eq_id),
               "archetype #{a.id} references unknown equation #{eq_id}"
      end
    end
  end

  describe "T3: seed_topology produces a valid starting canvas" do
    test "pomdp_maze seeds nodes + wires that Spec.validate accepts" do
      a = Archetypes.fetch("pomdp_maze")
      topology = Archetypes.seed_topology(a)

      assert %{nodes: nodes, edges: edges} = topology
      assert is_list(nodes)
      assert length(nodes) >= 4
      assert is_list(edges)

      # Every node has id + type (Builder uses those for lookups/validation).
      for n <- nodes do
        assert is_binary(n.id)
        assert is_binary(n.type)
      end

      # Every edge references real node ids.
      node_ids = MapSet.new(nodes, & &1.id)

      for e <- edges do
        assert MapSet.member?(node_ids, e.from_node)
        assert MapSet.member?(node_ids, e.to_node)
      end

      assert :ok = Spec.Topology.validate(topology)
    end
  end

  describe "T4: validator rejects malformed topology" do
    test "dangling wires" do
      topology = %{
        nodes: [%{id: "n1", type: "bundle"}],
        edges: [%{from_node: "n1", from_port: "out", to_node: "ghost", to_port: "in"}]
      }

      assert {:error, errors} = Spec.Topology.validate(topology)
      assert Enum.any?(errors, &match?({:dangling_edge, _}, &1))
    end

    test "type-mismatched ports" do
      topology = %{
        nodes: [
          %{id: "n1", type: "plan"},
          %{id: "n2", type: "act"}
        ],
        edges: [
          # plan's `policy_posterior` out-port is type :policy_posterior;
          # act's `action` in-port is type :action — types don't match.
          %{
            from_node: "n1",
            from_port: "policy_posterior",
            to_node: "n2",
            to_port: "action"
          }
        ]
      }

      assert {:error, errors} = Spec.Topology.validate(topology)
      assert Enum.any?(errors, &match?({:port_type_mismatch, _}, &1))
    end

    test "missing required nodes" do
      # An empty topology can be 'valid' (nothing to validate); but a
      # topology claiming an archetype with required-node guarantees
      # should report the missing ones.
      topology = %{nodes: [], edges: [], required_types: ["bundle", "perceive", "plan", "act"]}

      assert {:error, errors} = Spec.Topology.validate(topology)
      assert Enum.any?(errors, &match?({:missing_required_type, _}, &1))
    end

    test "empty topology with no requirements is vacuously valid" do
      assert :ok = Spec.Topology.validate(%{nodes: [], edges: []})
    end
  end

  describe "T5: provenance hash is stable under topology reorder" do
    test "reordering nodes in the topology doesn't change spec.hash" do
      a = Archetypes.fetch("pomdp_maze")
      t1 = Archetypes.seed_topology(a)
      # Reverse node order — semantically identical topology.
      t2 = %{t1 | nodes: Enum.reverse(t1.nodes), edges: Enum.reverse(t1.edges)}

      s1 = Spec.new(spec_from_archetype(a, t1, "spec-t5-a"))
      s2 = Spec.new(spec_from_archetype(a, t2, "spec-t5-b"))

      assert s1.hash == s2.hash,
             "reordering topology nodes should not change the provenance hash"
    end

    test "changing a node's params DOES change the hash" do
      a = Archetypes.fetch("pomdp_maze")
      t1 = Archetypes.seed_topology(a)

      t2 =
        update_in(t1, [:nodes], fn nodes ->
          Enum.map(nodes, fn
            %{type: "bundle"} = n -> Map.put(n, :params, %{horizon: 99})
            n -> n
          end)
        end)

      s1 = Spec.new(spec_from_archetype(a, t1, "spec-t5-c"))
      s2 = Spec.new(spec_from_archetype(a, t2, "spec-t5-d"))

      assert s1.hash != s2.hash
    end
  end

  defp spec_from_archetype(a, topology, id) do
    %{
      id: id,
      archetype_id: a.id,
      family_id: a.family_id,
      primary_equation_ids: a.primary_equation_ids,
      bundle_params: %{},
      blanket: %{},
      topology: topology
    }
  end
end
