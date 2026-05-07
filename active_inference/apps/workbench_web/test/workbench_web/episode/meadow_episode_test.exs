defmodule WorkbenchWeb.Episode.MeadowEpisodeTest do
  use ExUnit.Case, async: false

  alias AgentPlane.BundleBuilder.Meadow
  alias WorkbenchWeb.Episode.MeadowEpisode
  alias WorldPlane.Worlds.BirdMeadow

  setup do
    {:ok, meadow} = BirdMeadow.start_link(width: 4, height: 4)
    on_exit(fn -> if Process.alive?(meadow), do: GenServer.stop(meadow) end)
    %{meadow: meadow}
  end

  describe "two SimpleBird episode" do
    @tag timeout: 120_000
    test "advances time, emits actions, populates history", %{meadow: meadow} do
      birds = [
        %{
          agent_id: "alice",
          position: {0, 0},
          bundle: Meadow.simple(width: 4, height: 4, preferred_token: :t1)
        },
        %{
          agent_id: "bob",
          position: {3, 3},
          bundle: Meadow.simple(width: 4, height: 4, preferred_token: :t1)
        }
      ]

      {:ok, ep} =
        MeadowEpisode.start_link(meadow_pid: meadow, birds: birds, max_steps: 5)

      Enum.each(1..5, fn _ ->
        assert {:ok, entries} = MeadowEpisode.step(ep)
        assert length(entries) == 2

        Enum.each(entries, fn e ->
          assert e.action in ([:stay] ++
                                [:move_north, :move_south, :move_east, :move_west] ++
                                [:sing_t1, :sing_t2, :sing_t3, :sing_t4])

          assert is_list(e.policy_posterior)
          assert_in_delta Enum.sum(e.policy_posterior), 1.0, 1.0e-6
          assert is_tuple(e.position)
        end)
      end)

      snap = MeadowEpisode.snapshot(ep)
      assert snap.steps == 5
      assert length(snap.history) == 5 * 2
      assert Map.has_key?(snap.birds, "alice")
      assert Map.has_key?(snap.birds, "bob")

      GenServer.stop(ep)
    end
  end

  describe "ComplexBird episode" do
    @tag timeout: 180_000
    test "complex bundle drives one tick end-to-end (depth=1 for budget)", %{meadow: meadow} do
      birds = [
        %{
          agent_id: "ada",
          position: {0, 1},
          # policy_depth=1 keeps the test inside Jido's per-action 60s timeout.
          # Higher-depth verification is exercised by the bundle-builder smoke
          # tests, not the multi-agent integration test.
          bundle:
            Meadow.complex(
              width: 4,
              height: 4,
              preferred_token: :t2,
              policy_depth: 1
            )
        },
        %{
          agent_id: "ben",
          position: {3, 1},
          bundle:
            Meadow.complex(
              width: 4,
              height: 4,
              preferred_token: :t2,
              policy_depth: 1
            )
        }
      ]

      {:ok, ep} =
        MeadowEpisode.start_link(meadow_pid: meadow, birds: birds, max_steps: 2)

      assert {:ok, entries} = MeadowEpisode.step(ep)
      assert length(entries) == 2

      GenServer.stop(ep)
    end
  end

  describe "inspect_state contract (ActiveRuns chip)" do
    test "answers :inspect_state with the keys ActiveRuns reads", %{meadow: meadow} do
      birds = [
        %{
          agent_id: "alice",
          position: {0, 0},
          bundle: Meadow.simple(width: 4, height: 4, preferred_token: :t1)
        }
      ]

      {:ok, ep} =
        MeadowEpisode.start_link(meadow_pid: meadow, birds: birds, max_steps: 3)

      s = GenServer.call(ep, :inspect_state, 1_000)

      assert is_integer(s.steps)
      assert is_integer(s.max_steps)
      assert is_boolean(s.terminal?)
      assert get_in(s, [:agent, :agent_id]) == "alice"

      GenServer.stop(ep)
    end
  end

  describe "ResonantBird context swap" do
    @tag timeout: 180_000
    test "context flips when silence threshold accumulates", %{meadow: meadow} do
      bundle =
        Meadow.resonant(
          width: 4,
          height: 4,
          preferred_token: :t1,
          policy_depth: 1,
          duet_window: 4,
          silence_threshold: 2
        )

      birds = [
        %{agent_id: "rosa", position: {0, 0}, bundle: bundle}
      ]

      {:ok, ep} =
        MeadowEpisode.start_link(meadow_pid: meadow, birds: birds, max_steps: 6)

      # Single bird in an empty meadow → silence dominates → should swap to :duet
      # within a few ticks once the recent_obs buffer fills.
      Enum.each(1..6, fn _ -> MeadowEpisode.step(ep) end)
      snap = MeadowEpisode.snapshot(ep)

      contexts =
        snap.history
        |> Enum.filter(&(&1.agent_id == "rosa"))
        |> Enum.map(& &1.context)

      assert :explore in contexts or :duet in contexts
      # At least one swap must have occurred over the run.
      assert Enum.any?(snap.history, & &1.context_swapped?)

      GenServer.stop(ep)
    end
  end
end
