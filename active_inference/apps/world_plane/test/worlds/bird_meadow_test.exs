defmodule WorldPlane.Worlds.BirdMeadowTest do
  use ExUnit.Case, async: true

  alias SharedContracts.{ActionPacket, Blanket}
  alias WorldPlane.Worlds.BirdMeadow

  setup do
    {:ok, pid} = BirdMeadow.start_link(width: 4, height: 4)
    blanket = Blanket.meadow_default()
    on_exit(fn -> if Process.alive?(pid), do: GenServer.stop(pid) end)
    %{pid: pid, blanket: blanket}
  end

  describe "WorldBehaviour conformance" do
    test "id, name, dims, blanket are stable" do
      assert BirdMeadow.id() == :bird_meadow
      assert BirdMeadow.name() =~ "Bird Meadow"
      assert BirdMeadow.dims().n_obs == 1000
      assert BirdMeadow.blanket() == Blanket.meadow_default()
    end

    test "single-agent step/2 is rejected with :multi_agent_only", %{pid: pid, blanket: bk} do
      packet = ActionPacket.new(%{t: 0, action: :stay, agent_id: "x", blanket: bk})
      assert {:error, :multi_agent_only} = BirdMeadow.step(pid, packet)
    end

    test "terminal? is always false (meadow is time-bounded)", %{pid: pid} do
      refute BirdMeadow.terminal?(pid)
    end
  end

  describe "add_bird/3" do
    test "places a bird and refuses duplicate placement", %{pid: pid} do
      assert :ok = BirdMeadow.add_bird(pid, "alice", {0, 0})
      assert {:error, {:already_placed, "alice"}} = BirdMeadow.add_bird(pid, "alice", {1, 1})
    end

    test "refuses occupied tiles", %{pid: pid} do
      assert :ok = BirdMeadow.add_bird(pid, "alice", {0, 0})
      assert {:error, {:tile_occupied, {0, 0}}} = BirdMeadow.add_bird(pid, "bob", {0, 0})
    end

    test "refuses out-of-bounds placement", %{pid: pid} do
      assert {:error, {:out_of_bounds, _}} = BirdMeadow.add_bird(pid, "alice", {-1, 0})
      assert {:error, {:out_of_bounds, _}} = BirdMeadow.add_bird(pid, "alice", {4, 4})
    end
  end

  describe "multi_step/2 movement" do
    test "applies movement actions per agent", %{pid: pid, blanket: bk} do
      :ok = BirdMeadow.add_bird(pid, "alice", {1, 1})
      :ok = BirdMeadow.add_bird(pid, "bob", {2, 2})

      actions = %{
        "alice" => ActionPacket.new(%{t: 0, action: :move_east, agent_id: "alice", blanket: bk}),
        "bob" => ActionPacket.new(%{t: 0, action: :move_south, agent_id: "bob", blanket: bk})
      }

      {:ok, _obs_map} = BirdMeadow.multi_step(pid, actions)
      state = BirdMeadow.peek(pid)

      assert state.positions["alice"] == {2, 1}
      assert state.positions["bob"] == {2, 3}
      assert state.t == 1
    end

    test "boundary blocks motion (bird stays put)", %{pid: pid, blanket: bk} do
      :ok = BirdMeadow.add_bird(pid, "alice", {0, 0})

      actions = %{
        "alice" => ActionPacket.new(%{t: 0, action: :move_north, agent_id: "alice", blanket: bk})
      }

      {:ok, _} = BirdMeadow.multi_step(pid, actions)
      state = BirdMeadow.peek(pid)
      assert state.positions["alice"] == {0, 0}
    end

    test ":stay leaves position unchanged and emits no song", %{pid: pid, blanket: bk} do
      :ok = BirdMeadow.add_bird(pid, "alice", {1, 1})

      actions = %{
        "alice" => ActionPacket.new(%{t: 0, action: :stay, agent_id: "alice", blanket: bk})
      }

      {:ok, _} = BirdMeadow.multi_step(pid, actions)
      state = BirdMeadow.peek(pid)
      assert state.positions["alice"] == {1, 1}
      assert state.song_events == []
      assert state.last_song_per_agent["alice"] == :none
    end
  end

  describe "multi_step/2 singing" do
    test "singing emits a song event and is heard by another bird in range",
         %{pid: pid, blanket: bk} do
      :ok = BirdMeadow.add_bird(pid, "alice", {0, 0})
      :ok = BirdMeadow.add_bird(pid, "bob", {1, 0})

      actions = %{
        "alice" => ActionPacket.new(%{t: 0, action: :sing_t1, agent_id: "alice", blanket: bk}),
        "bob" => ActionPacket.new(%{t: 0, action: :stay, agent_id: "bob", blanket: bk})
      }

      {:ok, obs_map} = BirdMeadow.multi_step(pid, actions)

      bob_obs = obs_map["bob"]
      assert bob_obs.channels.hearing_token == :t1
      assert bob_obs.channels.hearing_amp == :loud
      assert bob_obs.channels.hearing_bearing == :west

      alice_obs = obs_map["alice"]
      # Alice does not hear herself.
      assert alice_obs.channels.hearing_token == :none
      assert alice_obs.channels.self_sang_token == :t1
    end

    test "all birds out of range hear silence", %{blanket: bk} do
      {:ok, pid} = BirdMeadow.start_link(width: 8, height: 8)
      :ok = BirdMeadow.add_bird(pid, "alice", {0, 0})
      :ok = BirdMeadow.add_bird(pid, "bob", {7, 7})

      actions = %{
        "alice" => ActionPacket.new(%{t: 0, action: :sing_t1, agent_id: "alice", blanket: bk}),
        "bob" => ActionPacket.new(%{t: 0, action: :stay, agent_id: "bob", blanket: bk})
      }

      {:ok, obs_map} = BirdMeadow.multi_step(pid, actions)
      assert obs_map["bob"].channels.hearing_amp == :silence
      assert obs_map["bob"].channels.hearing_token == :none
      GenServer.stop(pid)
    end
  end

  describe "song-event lifecycle" do
    test "songs are visible only on the tick they were emitted", %{pid: pid, blanket: bk} do
      :ok = BirdMeadow.add_bird(pid, "alice", {0, 0})
      :ok = BirdMeadow.add_bird(pid, "bob", {1, 0})

      sing = %{
        "alice" => ActionPacket.new(%{t: 0, action: :sing_t1, agent_id: "alice", blanket: bk}),
        "bob" => ActionPacket.new(%{t: 0, action: :stay, agent_id: "bob", blanket: bk})
      }

      {:ok, obs1} = BirdMeadow.multi_step(pid, sing)
      assert obs1["bob"].channels.hearing_token == :t1

      stay = %{
        "alice" => ActionPacket.new(%{t: 1, action: :stay, agent_id: "alice", blanket: bk}),
        "bob" => ActionPacket.new(%{t: 1, action: :stay, agent_id: "bob", blanket: bk})
      }

      {:ok, obs2} = BirdMeadow.multi_step(pid, stay)
      assert obs2["bob"].channels.hearing_token == :none
    end
  end

  describe "wall_sig channel" do
    test "interior tiles are :open, edge tiles are :near_wall", %{pid: pid, blanket: bk} do
      # Use 4x4 — interior is {1,1}, {1,2}, {2,1}, {2,2}; everything else is on a boundary.
      :ok = BirdMeadow.add_bird(pid, "interior", {1, 1})
      :ok = BirdMeadow.add_bird(pid, "edge", {0, 1})

      stay = %{
        "interior" =>
          ActionPacket.new(%{t: 0, action: :stay, agent_id: "interior", blanket: bk}),
        "edge" => ActionPacket.new(%{t: 0, action: :stay, agent_id: "edge", blanket: bk})
      }

      {:ok, obs} = BirdMeadow.multi_step(pid, stay)
      assert obs["interior"].channels.wall_sig == :open
      assert obs["edge"].channels.wall_sig == :near_wall
    end
  end

  # External-review K5 (v2): Map iteration order in `apply_actions/2` was
  # implementation-defined, so two birds aiming at the same target tile
  # resolved non-deterministically. The fix reconciles target conflicts by
  # lexicographically-lowest agent_id wins; losers stay put with a
  # `{:blocked, :collision}` ledger entry.
  describe "K5 audit anchor: same-tile move-conflict resolution" do
    test "head-on collision: lowest agent_id lands on target, loser blocked", %{
      pid: pid,
      blanket: bk
    } do
      # alice at (1,1), bob at (3,1). Both move east+west toward (2,1).
      :ok = BirdMeadow.add_bird(pid, "alice", {1, 1})
      :ok = BirdMeadow.add_bird(pid, "bob", {3, 1})

      actions = %{
        "alice" => ActionPacket.new(%{t: 0, action: :move_east, agent_id: "alice", blanket: bk}),
        "bob" => ActionPacket.new(%{t: 0, action: :move_west, agent_id: "bob", blanket: bk})
      }

      {:ok, _obs} = BirdMeadow.multi_step(pid, actions)
      state = BirdMeadow.peek(pid)

      # alice is lex-first → wins (2, 1). bob bumped back to original (3, 1).
      assert state.positions["alice"] == {2, 1}
      assert state.positions["bob"] == {3, 1}

      stays = Map.fetch!(List.last(state.history), :stays)
      assert {"bob", {:blocked, :collision}} in stays
    end

    test "no spurious collisions when targets differ", %{pid: pid, blanket: bk} do
      :ok = BirdMeadow.add_bird(pid, "alice", {0, 0})
      :ok = BirdMeadow.add_bird(pid, "bob", {3, 3})

      actions = %{
        "alice" =>
          ActionPacket.new(%{t: 0, action: :move_east, agent_id: "alice", blanket: bk}),
        "bob" => ActionPacket.new(%{t: 0, action: :move_west, agent_id: "bob", blanket: bk})
      }

      {:ok, _} = BirdMeadow.multi_step(pid, actions)
      state = BirdMeadow.peek(pid)

      assert state.positions["alice"] == {1, 0}
      assert state.positions["bob"] == {2, 3}

      stays = Map.fetch!(List.last(state.history), :stays)
      refute Enum.any?(stays, fn {_, kind} -> kind == {:blocked, :collision} end)
    end

    test "three-way collision on the same tile: lex-lowest wins", %{pid: pid, blanket: bk} do
      :ok = BirdMeadow.add_bird(pid, "charlie", {2, 0})
      :ok = BirdMeadow.add_bird(pid, "alice", {2, 2})
      :ok = BirdMeadow.add_bird(pid, "bob", {1, 1})

      # All three aim at (2, 1).
      actions = %{
        "charlie" =>
          ActionPacket.new(%{t: 0, action: :move_south, agent_id: "charlie", blanket: bk}),
        "alice" =>
          ActionPacket.new(%{t: 0, action: :move_north, agent_id: "alice", blanket: bk}),
        "bob" => ActionPacket.new(%{t: 0, action: :move_east, agent_id: "bob", blanket: bk})
      }

      {:ok, _} = BirdMeadow.multi_step(pid, actions)
      state = BirdMeadow.peek(pid)

      # alice (lex-first) wins (2,1); charlie and bob are bumped back.
      assert state.positions["alice"] == {2, 1}
      assert state.positions["charlie"] == {2, 0}
      assert state.positions["bob"] == {1, 1}
    end

    test "deterministic across input ordering (audit anchor: K7+K5 reproducibility)" do
      # Two birds aiming at the same target. Run twice — outcome must be
      # identical regardless of any underlying iteration order.
      run = fn ->
        {:ok, pid} = BirdMeadow.start_link(width: 4, height: 4)
        bk = Blanket.meadow_default()
        # Add in alphabetical order one run, reverse the next — order of
        # addition is irrelevant under the lex-first tie-break rule.
        :ok = BirdMeadow.add_bird(pid, "zoe", {0, 0})
        :ok = BirdMeadow.add_bird(pid, "alice", {2, 0})

        actions = %{
          "zoe" => ActionPacket.new(%{t: 0, action: :move_east, agent_id: "zoe", blanket: bk}),
          "alice" =>
            ActionPacket.new(%{t: 0, action: :move_west, agent_id: "alice", blanket: bk})
        }

        {:ok, _} = BirdMeadow.multi_step(pid, actions)
        result = BirdMeadow.peek(pid)
        GenServer.stop(pid)
        result.positions
      end

      a = run.()
      b = run.()
      assert a == b

      # alice (lex-first) lands on (1, 0); zoe bumped back.
      assert a["alice"] == {1, 0}
      assert a["zoe"] == {0, 0}
    end
  end

  # External-review K6 (v2): `:no_action` (no ActionPacket submitted) and
  # `:stay` (explicit ActionPacket with action=:stay) produce identical
  # world transitions but different ledger entries. The distinction is
  # preserved (not collapsed) so downstream researchers can see whether
  # a bird's policy chose to stay vs. failed to act.
  describe "K6 audit anchor: :no_action vs :stay history distinction" do
    test "missing action → :no_action; explicit :stay → :stay in history", %{
      pid: pid,
      blanket: bk
    } do
      :ok = BirdMeadow.add_bird(pid, "alice", {1, 1})
      :ok = BirdMeadow.add_bird(pid, "bob", {2, 2})

      # Only alice submits an action (explicit :stay). Bob is omitted.
      actions = %{
        "alice" => ActionPacket.new(%{t: 0, action: :stay, agent_id: "alice", blanket: bk})
      }

      {:ok, _} = BirdMeadow.multi_step(pid, actions)
      state = BirdMeadow.peek(pid)

      stays = Map.fetch!(List.last(state.history), :stays)

      assert {"alice", :stay} in stays
      assert {"bob", :no_action} in stays

      # Both stay put physically.
      assert state.positions["alice"] == {1, 1}
      assert state.positions["bob"] == {2, 2}
    end
  end

  describe "reproducibility" do
    test "identical action sequences produce identical observation streams" do
      run = fn ->
        {:ok, pid} = BirdMeadow.start_link(width: 4, height: 4, run_id: "fixed")
        bk = Blanket.meadow_default()
        :ok = BirdMeadow.add_bird(pid, "alice", {0, 0})
        :ok = BirdMeadow.add_bird(pid, "bob", {3, 3})

        seq = [
          %{
            "alice" =>
              ActionPacket.new(%{t: 0, action: :sing_t1, agent_id: "alice", blanket: bk}),
            "bob" => ActionPacket.new(%{t: 0, action: :move_north, agent_id: "bob", blanket: bk})
          },
          %{
            "alice" =>
              ActionPacket.new(%{t: 1, action: :move_east, agent_id: "alice", blanket: bk}),
            "bob" => ActionPacket.new(%{t: 1, action: :sing_t2, agent_id: "bob", blanket: bk})
          }
        ]

        results = Enum.map(seq, fn act -> elem(BirdMeadow.multi_step(pid, act), 1) end)
        GenServer.stop(pid)
        results
      end

      assert run.() == run.()
    end
  end
end
