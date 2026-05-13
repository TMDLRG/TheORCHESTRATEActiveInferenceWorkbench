defmodule AgentPlane.BirdsongObsAdapterTest do
  use ExUnit.Case, async: true

  alias AgentPlane.BirdsongObsAdapter
  alias SharedContracts.{Blanket, ObservationPacket}

  test "encodes and decodes all observation factors" do
    idx = BirdsongObsAdapter.obs_index(:a, :response_due, :b, :good_fit)

    assert idx in 0..359
    assert BirdsongObsAdapter.decode_index(idx) == {:a, :response_due, :b, :good_fit}
    assert BirdsongObsAdapter.n_obs() == 360
  end

  test "projects a packet to a one-hot vector" do
    blanket = Blanket.birdsong_default()

    packet =
      ObservationPacket.new(%{
        t: 0,
        channels: %{
          heard_motif: :c,
          turn_phase: :gap,
          self_sang_motif: :none,
          response_fit: :none
        },
        world_run_id: "adapter",
        terminal?: false,
        blanket: blanket
      })

    vec = BirdsongObsAdapter.to_obs_vector(packet)

    assert length(vec) == 360
    assert Enum.sum(vec) == 1.0
    assert Enum.count(vec, &(&1 == 1.0)) == 1
  end
end
