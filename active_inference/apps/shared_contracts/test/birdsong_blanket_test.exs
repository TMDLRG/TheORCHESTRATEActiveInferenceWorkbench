defmodule SharedContracts.BirdsongBlanketTest do
  use ExUnit.Case, async: true

  alias SharedContracts.{ActionPacket, Blanket, ObservationPacket}

  test "birdsong_default exposes a separate call-response blanket" do
    blanket = Blanket.birdsong_default()

    assert blanket.observation_channels == [
             :heard_motif,
             :turn_phase,
             :self_sang_motif,
             :response_fit
           ]

    assert blanket.action_vocabulary == [:listen, :sing_a, :sing_b, :sing_c, :sing_d]
    assert Blanket.birdsong_motifs() == [:a, :b, :c, :d]
    assert blanket.channel_specs.heard_motif.values == [:silence, :a, :b, :c, :d, :unknown]
  end

  test "birdsong packets enforce the blanket boundary" do
    blanket = Blanket.birdsong_default()

    obs =
      ObservationPacket.new(%{
        t: 0,
        channels: %{
          heard_motif: :a,
          turn_phase: :call,
          self_sang_motif: :none,
          response_fit: :none
        },
        world_run_id: "birdsong-test",
        terminal?: false,
        blanket: blanket
      })

    assert obs.channels.heard_motif == :a

    assert_raise ArgumentError, ~r/blanket violation/, fn ->
      ObservationPacket.new(%{
        t: 0,
        channels: %{heard_motif: :a, hidden_species: :sparrow},
        world_run_id: "birdsong-test",
        terminal?: false,
        blanket: blanket
      })
    end

    assert %ActionPacket{action: :sing_b} =
             ActionPacket.new(%{
               t: 1,
               action: :sing_b,
               agent_id: "birdsong-agent",
               blanket: blanket
             })

    assert_raise ArgumentError, ~r/blanket violation/, fn ->
      ActionPacket.new(%{t: 1, action: :move_north, agent_id: "agent", blanket: blanket})
    end
  end
end
