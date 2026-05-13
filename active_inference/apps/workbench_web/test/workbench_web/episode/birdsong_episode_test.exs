defmodule WorkbenchWeb.Episode.BirdsongEpisodeTest do
  use ExUnit.Case, async: false

  alias AgentPlane.{BirdsongSongbook, BundleBuilder.Birdsong}
  alias WorkbenchWeb.Episode.BirdsongEpisode
  alias WorldPlane.Worlds.BirdsongCallResponse

  @tag timeout: 180_000
  test "runs the separate birdsong episode through Jido Active Inference" do
    {:ok, world} = BirdsongCallResponse.start_link(motifs: [:a])
    bundle = Birdsong.build(action_selection: :argmax, softmax_temperature: 0.35)

    {:ok, ep} = BirdsongEpisode.start_link(world_pid: world, bundle: bundle, max_steps: 6)

    snap = BirdsongEpisode.run_until_response(ep, 6, 120_000)

    assert snap.steps > 0
    assert snap.agent.last_action in bundle.actions
    assert is_list(snap.agent.policy_posterior)
    assert_in_delta Enum.sum(snap.agent.policy_posterior), 1.0, 1.0e-6
    assert length(snap.history) == snap.steps

    assert Enum.any?(snap.history, fn entry ->
             match?(<<"RIFF", _::binary>>, entry.response_wav)
           end)

    BirdsongEpisode.stop(ep)
    if Process.alive?(world), do: GenServer.stop(world)
  end

  @tag timeout: 180_000
  test "runs a learned multi-note song as repeated Active Inference trials" do
    counts = BirdsongSongbook.learn_pairs(nil, [:a, :b, :c], [:d, :c, :a], repetitions: 10)

    bundle =
      Birdsong.build(
        action_selection: :argmax,
        softmax_temperature: 0.35,
        songbook_counts: counts
      )

    result = BirdsongEpisode.run_motif_sequence([:a, :b, :c], bundle)

    assert result.response_motifs == [:d, :c, :a]
    assert <<"RIFF", _::binary>> = result.response_wav
    assert String.starts_with?(result.response_data_url, "data:audio/wav;base64,")
  end
end
