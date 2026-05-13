defmodule WorldPlane.Worlds.BirdsongCallResponseTest do
  use ExUnit.Case, async: true

  alias SharedContracts.{ActionPacket, Blanket}
  alias WorldPlane.Worlds.BirdsongCallResponse

  setup do
    {:ok, world} = BirdsongCallResponse.start_link(motifs: [:a])
    on_exit(fn -> if Process.alive?(world), do: GenServer.stop(world) end)
    %{world: world, blanket: Blanket.birdsong_default()}
  end

  test "starts as a separate world with its own dimensions and blanket", %{world: world} do
    assert BirdsongCallResponse.id() == :birdsong_call_response
    assert BirdsongCallResponse.dims() == %{n_obs: 360, n_states: 360}

    obs = BirdsongCallResponse.current_observation(world)
    assert obs.channels.heard_motif == :a
    assert obs.channels.turn_phase == :call
    assert obs.channels.self_sang_motif == :none
  end

  test "records self-audition and response fit after a complement action", %{
    world: world,
    blanket: blanket
  } do
    packet = ActionPacket.new(%{t: 0, action: :sing_b, agent_id: "agent", blanket: blanket})

    assert {:ok, obs} = BirdsongCallResponse.step(world, packet)
    assert obs.channels.self_sang_motif == :b
    assert obs.channels.response_fit == :good_fit

    snap = BirdsongCallResponse.peek(world)
    assert [%{token: :b}] = snap.response_events
  end
end
