defmodule AgentPlane.MeadowObsAdapterTest do
  use ExUnit.Case, async: true

  alias AgentPlane.MeadowObsAdapter
  alias SharedContracts.{Blanket, ObservationPacket}

  describe "n_obs/0 and channel cardinalities" do
    test "n_obs is 1000 and matches the product of all channel cardinalities" do
      assert MeadowObsAdapter.n_obs() ==
               length(MeadowObsAdapter.wall_sig_values()) *
                 length(MeadowObsAdapter.amp_values()) *
                 length(MeadowObsAdapter.token_values()) *
                 length(MeadowObsAdapter.bearing_values()) *
                 length(MeadowObsAdapter.self_sang_values())

      assert MeadowObsAdapter.n_obs() == 1000
    end

    test "channel value lists match Blanket.meadow_default channel specs exactly" do
      blanket = Blanket.meadow_default()

      assert blanket.channel_specs[:wall_sig].values == MeadowObsAdapter.wall_sig_values()
      assert blanket.channel_specs[:hearing_amp].values == MeadowObsAdapter.amp_values()
      assert blanket.channel_specs[:hearing_token].values == MeadowObsAdapter.token_values()

      assert blanket.channel_specs[:hearing_bearing].values ==
               MeadowObsAdapter.bearing_values()

      assert blanket.channel_specs[:self_sang_token].values ==
               MeadowObsAdapter.self_sang_values()
    end
  end

  describe "obs_index/5 and decode_index/1 are inverses" do
    test "round-trip every index" do
      Enum.each(0..(MeadowObsAdapter.n_obs() - 1), fn idx ->
        {w, a, t, b, s} = MeadowObsAdapter.decode_index(idx)
        assert MeadowObsAdapter.obs_index(w, a, t, b, s) == idx
      end)
    end

    test "round-trip every (atom-tuple)" do
      for w <- MeadowObsAdapter.wall_sig_values(),
          a <- MeadowObsAdapter.amp_values(),
          t <- MeadowObsAdapter.token_values(),
          b <- MeadowObsAdapter.bearing_values(),
          s <- MeadowObsAdapter.self_sang_values() do
        idx = MeadowObsAdapter.obs_index(w, a, t, b, s)
        assert MeadowObsAdapter.decode_index(idx) == {w, a, t, b, s}
      end
    end

    test "rejects bad atom values" do
      assert_raise ArgumentError, fn ->
        MeadowObsAdapter.obs_index(:bogus, :silence, :none, :none, :none)
      end
    end
  end

  describe "to_obs_vector/1" do
    test "produces a one-hot of dimension n_obs" do
      blanket = Blanket.meadow_default()

      packet =
        ObservationPacket.new(%{
          t: 0,
          channels: %{
            wall_sig: :open,
            hearing_amp: :silence,
            hearing_token: :none,
            hearing_bearing: :none,
            self_sang_token: :none
          },
          world_run_id: "test",
          terminal?: false,
          blanket: blanket
        })

      vec = MeadowObsAdapter.to_obs_vector(packet)
      assert length(vec) == MeadowObsAdapter.n_obs()
      assert Enum.sum(vec) == 1.0
      # All-defaults observation is the (open, silence, none, none, none) tuple,
      # which is index 0 by construction.
      assert hd(vec) == 1.0
    end

    test "different observations produce different one-hots" do
      blanket = Blanket.meadow_default()

      mk = fn ch ->
        ObservationPacket.new(%{
          t: 0,
          channels: ch,
          world_run_id: "test",
          terminal?: false,
          blanket: blanket
        })
      end

      a =
        mk.(%{
          wall_sig: :open,
          hearing_amp: :loud,
          hearing_token: :t1,
          hearing_bearing: :east,
          self_sang_token: :none
        })

      b =
        mk.(%{
          wall_sig: :open,
          hearing_amp: :loud,
          hearing_token: :t2,
          hearing_bearing: :east,
          self_sang_token: :none
        })

      refute MeadowObsAdapter.to_obs_vector(a) == MeadowObsAdapter.to_obs_vector(b)
    end
  end
end
