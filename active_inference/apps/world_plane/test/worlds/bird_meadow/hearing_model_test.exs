defmodule WorldPlane.Worlds.BirdMeadow.HearingModelTest do
  use ExUnit.Case, async: true

  alias WorldPlane.Worlds.BirdMeadow.HearingModel

  describe "distance/2" do
    test "Manhattan, symmetric, zero on equality" do
      assert HearingModel.distance({3, 4}, {3, 4}) == 0
      assert HearingModel.distance({0, 0}, {1, 0}) == 1
      assert HearingModel.distance({0, 0}, {3, 4}) == 7
      assert HearingModel.distance({3, 4}, {0, 0}) == 7
      assert HearingModel.distance({2, 5}, {7, 1}) == 9
    end
  end

  describe "attenuate/3" do
    test "linear with hard cutoff at d_max" do
      assert HearingModel.attenuate(0) == 1.0
      assert_in_delta HearingModel.attenuate(1), 0.8, 1.0e-9
      assert_in_delta HearingModel.attenuate(2), 0.6, 1.0e-9
      assert_in_delta HearingModel.attenuate(3), 0.4, 1.0e-9
      assert_in_delta HearingModel.attenuate(4), 0.2, 1.0e-9
      assert_in_delta HearingModel.attenuate(5), 0.0, 1.0e-9
      # Beyond cutoff is exactly zero (no negative ringing).
      assert HearingModel.attenuate(6) == 0.0
      assert HearingModel.attenuate(100) == 0.0
    end

    test "honours custom d_max and source_amp" do
      assert_in_delta HearingModel.attenuate(2, 4, 1.0), 0.5, 1.0e-9
      assert_in_delta HearingModel.attenuate(2, 4, 0.5), 0.25, 1.0e-9
    end
  end

  describe "bin_amp/1" do
    test "boundaries match the meadow blanket spec" do
      assert HearingModel.bin_amp(0.0) == :silence
      assert HearingModel.bin_amp(0.1) == :soft
      assert HearingModel.bin_amp(1.0 / 3.0) == :soft
      # Just over 1/3 → :medium
      assert HearingModel.bin_amp(0.34) == :medium
      assert HearingModel.bin_amp(2.0 / 3.0) == :medium
      # Just over 2/3 → :loud
      assert HearingModel.bin_amp(0.7) == :loud
      assert HearingModel.bin_amp(1.0) == :loud
    end
  end

  describe "bearing_of/2" do
    test "same tile is :none" do
      assert HearingModel.bearing_of({2, 2}, {2, 2}) == :none
    end

    test "pure cardinal directions" do
      # listener at {2, 2}; source axis-aligned
      assert HearingModel.bearing_of({2, 0}, {2, 2}) == :north
      assert HearingModel.bearing_of({2, 5}, {2, 2}) == :south
      assert HearingModel.bearing_of({5, 2}, {2, 2}) == :east
      assert HearingModel.bearing_of({0, 2}, {2, 2}) == :west
    end

    test "ties between row and column resolve to the vertical axis (deterministic)" do
      # |Δrow| == |Δcol| should yield N/S, not E/W, for reproducibility.
      assert HearingModel.bearing_of({4, 0}, {2, 2}) == :north
      assert HearingModel.bearing_of({0, 4}, {2, 2}) == :south
    end

    test "unequal magnitudes pick the larger axis" do
      # Δr = -3, Δc = 1 → :north dominates
      assert HearingModel.bearing_of({3, -1}, {2, 2}) == :north
      # Δr = 1, Δc = 3 → :east dominates
      assert HearingModel.bearing_of({5, 3}, {2, 2}) == :east
    end
  end

  describe "aggregate_per_listener/3" do
    test "no events → silent default" do
      assert HearingModel.aggregate_per_listener([], {0, 0}) == HearingModel.silent()
    end

    test "single in-range event populates fully" do
      ev = %{agent_id: "a", token: :t1, position: {1, 0}, source_amp: 1.0, t: 0}
      heard = HearingModel.aggregate_per_listener([ev], {0, 0})

      assert heard.token == :t1
      assert heard.amp_bin == :loud
      assert heard.bearing == :east
      assert heard.source_id == "a"
      assert heard.distance == 1
      assert_in_delta heard.raw_amp, 0.8, 1.0e-9
    end

    test "out-of-range events are dropped" do
      # d = 6, d_max default 5 → silent
      ev = %{agent_id: "a", token: :t1, position: {6, 0}, source_amp: 1.0}
      assert HearingModel.aggregate_per_listener([ev], {0, 0}) == HearingModel.silent()
    end

    test "loudest wins; tie-break is amplitude→distance→agent_id" do
      # Two equally close sources, equal amp, different agent_ids → ABC
      a = %{agent_id: "z", token: :t1, position: {1, 0}, source_amp: 1.0}
      b = %{agent_id: "a", token: :t2, position: {0, 1}, source_amp: 1.0}
      heard = HearingModel.aggregate_per_listener([a, b], {0, 0})
      assert heard.source_id == "a"
      assert heard.token == :t2
    end

    test "amplitude trumps distance" do
      # Closer but quieter
      near_quiet = %{agent_id: "z", token: :t1, position: {1, 0}, source_amp: 0.1}
      # Farther but loud
      far_loud = %{agent_id: "a", token: :t2, position: {3, 0}, source_amp: 1.0}
      heard = HearingModel.aggregate_per_listener([near_quiet, far_loud], {0, 0})
      assert heard.source_id == "a"
      assert heard.token == :t2
    end

    test "deterministic across runs (audit anchor: reproducibility)" do
      events =
        for c <- 0..3, r <- 0..3, c != 0 or r != 0 do
          %{agent_id: "agent_#{c}_#{r}", token: :t1, position: {c, r}, source_amp: 1.0}
        end

      a = HearingModel.aggregate_per_listener(events, {0, 0})
      b = HearingModel.aggregate_per_listener(events, {0, 0})
      assert a == b
    end
  end
end
