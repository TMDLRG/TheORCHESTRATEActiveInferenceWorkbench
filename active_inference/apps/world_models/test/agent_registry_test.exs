defmodule WorldModels.AgentRegistryTest do
  @moduledoc """
  Plan §12 Phase 5 — Spec persistence + live-agent directory.

  The registry is the hinge between Builder (which creates Specs) and
  Runtime (which instantiates live agents from Specs). Glass Engine reads
  both: a signal's spec_id resolves to a Spec via `fetch_spec/1`, and a
  spec_id resolves to its live agent_ids via `live_for_spec/1`.
  """

  use WorldModels.MnesiaCase, async: false

  alias WorldModels.AgentRegistry
  alias WorldModels.EventLog.Setup
  alias WorldModels.Spec

  setup _ do
    :ok = Setup.ensure_schema!()
    :ok
  end

  describe "T1: register_spec + fetch_spec roundtrip" do
    test "a registered spec is retrievable by id" do
      spec = build_spec("spec-reg-1")

      {:ok, stored} = AgentRegistry.register_spec(spec)
      assert stored.id == "spec-reg-1"

      assert {:ok, retrieved} = AgentRegistry.fetch_spec("spec-reg-1")
      assert retrieved.id == "spec-reg-1"
      assert retrieved.archetype_id == spec.archetype_id
      assert retrieved.family_id == spec.family_id
      assert retrieved.primary_equation_ids == spec.primary_equation_ids
    end

    test "fetch_spec returns :error for unknown ids" do
      assert AgentRegistry.fetch_spec("never-registered") == :error
    end

    test "list_specs returns all registered specs" do
      _ = AgentRegistry.register_spec(build_spec("spec-list-a"))
      _ = AgentRegistry.register_spec(build_spec("spec-list-b"))

      ids = AgentRegistry.list_specs() |> Enum.map(& &1.id) |> MapSet.new()
      assert MapSet.subset?(MapSet.new(["spec-list-a", "spec-list-b"]), ids)
    end
  end

  describe "T2: provenance_hash is deterministic and content-addressing" do
    test "the same canonical form hashes identically" do
      a = build_spec("spec-hash-a")

      b = %{a | id: "spec-hash-b"}
      # Manually recompute b's hash so we compare canonical content, not id.
      b = %{b | hash: Spec.provenance_hash(b)}

      a_canonical = Spec.canonical_form(a)
      b_canonical = Spec.canonical_form(b)

      # The id is NOT part of canonical_form — two specs with identical
      # content and different ids should canonicalize the same.
      assert a_canonical == b_canonical
      assert Spec.provenance_hash(a) == Spec.provenance_hash(b)
    end

    test "any material change produces a different hash" do
      a = build_spec("spec-hash-c")
      b = %{a | primary_equation_ids: a.primary_equation_ids ++ ["eq_7_10_dirichlet_update"]}
      b = %{b | hash: Spec.provenance_hash(b)}

      assert Spec.provenance_hash(a) != Spec.provenance_hash(b)
    end

    test "new/1 auto-computes the hash if not provided" do
      spec =
        Spec.new(%{
          id: "spec-auto-hash",
          archetype_id: "pomdp_maze",
          family_id: "POMDP",
          primary_equation_ids: ["eq_4_14_policy_posterior"],
          bundle_params: %{horizon: 5},
          blanket: %{}
        })

      assert is_binary(spec.hash)
      assert byte_size(spec.hash) > 0
      assert spec.hash == Spec.provenance_hash(spec)
    end
  end

  describe "T3: live-agent directory" do
    test "attach_live + live_for_spec roundtrip" do
      {:ok, _} = AgentRegistry.register_spec(build_spec("spec-live-1"))

      :ok = AgentRegistry.attach_live("agent-A", "spec-live-1")
      :ok = AgentRegistry.attach_live("agent-B", "spec-live-1")

      live = AgentRegistry.live_for_spec("spec-live-1")
      assert MapSet.new(live) == MapSet.new(["agent-A", "agent-B"])
    end

    test "detach_live removes an agent from the directory" do
      {:ok, _} = AgentRegistry.register_spec(build_spec("spec-live-2"))
      :ok = AgentRegistry.attach_live("agent-X", "spec-live-2")
      :ok = AgentRegistry.detach_live("agent-X")

      assert AgentRegistry.live_for_spec("spec-live-2") == []
    end

    test "attach_live refuses unknown spec_id" do
      assert {:error, :unknown_spec} = AgentRegistry.attach_live("agent-Y", "spec-does-not-exist")
    end

    test "list_live_agents returns {agent_id, spec_id} pairs" do
      {:ok, _} = AgentRegistry.register_spec(build_spec("spec-live-3"))
      :ok = AgentRegistry.attach_live("agent-P", "spec-live-3")
      :ok = AgentRegistry.attach_live("agent-Q", "spec-live-3")

      pairs = AgentRegistry.list_live_agents() |> MapSet.new()

      assert MapSet.member?(pairs, {"agent-P", "spec-live-3"})
      assert MapSet.member?(pairs, {"agent-Q", "spec-live-3"})
    end
  end

  describe "T4: specs survive :mnesia restart" do
    test "registered specs re-load from disk after mnesia stop+start" do
      {:ok, _} = AgentRegistry.register_spec(build_spec("spec-durable-1"))

      :stopped = :mnesia.stop()
      :ok = :mnesia.start()
      :ok = :mnesia.wait_for_tables([:world_models_specs], 5_000)

      assert {:ok, spec} = AgentRegistry.fetch_spec("spec-durable-1")
      assert spec.id == "spec-durable-1"
      assert is_binary(spec.hash)
    end
  end

  describe "T5: delete_spec guard" do
    test "delete_spec refuses when live agents are attached" do
      {:ok, _} = AgentRegistry.register_spec(build_spec("spec-with-live"))
      :ok = AgentRegistry.attach_live("agent-still-alive", "spec-with-live")

      assert {:error, {:live_agents, ["agent-still-alive"]}} =
               AgentRegistry.delete_spec("spec-with-live")

      assert {:ok, _} = AgentRegistry.fetch_spec("spec-with-live")
    end

    test "delete_spec succeeds when no live agents remain" do
      {:ok, _} = AgentRegistry.register_spec(build_spec("spec-deletable"))
      :ok = AgentRegistry.delete_spec("spec-deletable")
      assert AgentRegistry.fetch_spec("spec-deletable") == :error
    end
  end

  # -- Helpers ---------------------------------------------------------------

  defp build_spec(id) do
    Spec.new(%{
      id: id,
      archetype_id: "pomdp_maze",
      family_id: "Partially Observable Markov Decision Process (POMDP)",
      primary_equation_ids: [
        "eq_4_13_state_belief_update",
        "eq_4_14_policy_posterior",
        "eq_4_10_efe_linear_algebra",
        "eq_4_11_vfe_linear_algebra"
      ],
      bundle_params: %{
        horizon: 3,
        policy_depth: 3,
        preference_strength: 4.0
      },
      blanket: %{observation_channels: [:goal_cue], action_vocabulary: [:move_east, :move_west]}
    })
  end
end
