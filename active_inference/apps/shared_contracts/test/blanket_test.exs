defmodule SharedContracts.BlanketTest do
  use ExUnit.Case, async: true

  alias SharedContracts.{ActionPacket, Blanket, ObservationPacket}

  describe "T3 — blanket contracts reject violations" do
    test "ObservationPacket rejects channels not in the blanket" do
      blanket =
        Blanket.maze_default()
        |> Blanket.with_observation_channels([:wall_north])

      assert_raise ArgumentError, ~r/blanket violation/, fn ->
        ObservationPacket.new(%{
          t: 0,
          channels: %{wall_north: :open, secret_channel: :bad},
          world_run_id: "r",
          terminal?: false,
          blanket: blanket
        })
      end
    end

    test "ObservationPacket accepts only whitelisted channels" do
      blanket = Blanket.maze_default()

      packet =
        ObservationPacket.new(%{
          t: 0,
          channels: %{wall_north: :wall, tile: :empty},
          world_run_id: "r",
          terminal?: false,
          blanket: blanket
        })

      assert packet.channels.wall_north == :wall
      assert packet.channels.tile == :empty
    end

    test "ActionPacket rejects actions not in the vocabulary" do
      blanket =
        Blanket.maze_default()
        |> Blanket.with_action_vocabulary([:move_north])

      assert_raise ArgumentError, ~r/blanket violation/, fn ->
        ActionPacket.new(%{t: 0, action: :move_south, agent_id: "a", blanket: blanket})
      end
    end

    test "ActionPacket accepts whitelisted actions" do
      blanket = Blanket.maze_default()
      packet = ActionPacket.new(%{t: 0, action: :move_north, agent_id: "a", blanket: blanket})
      assert packet.action == :move_north
    end
  end
end
