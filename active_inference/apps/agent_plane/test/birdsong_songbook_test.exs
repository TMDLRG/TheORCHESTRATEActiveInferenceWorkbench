defmodule AgentPlane.BirdsongSongbookTest do
  use ExUnit.Case, async: true

  alias AgentPlane.BirdsongSongbook

  test "learn_pairs shifts P(response | heard) toward repeated examples" do
    counts =
      nil
      |> BirdsongSongbook.learn_pairs([:b], [:d], repetitions: 10)

    dist = BirdsongSongbook.distribution(counts, :b)

    assert BirdsongSongbook.predict(counts, :b) == :d
    assert dist.d > dist.a
    assert dist.d > dist.b
    assert dist.d > dist.c
  end

  test "summary exposes learned predictions for all motifs" do
    counts = BirdsongSongbook.learn_pairs(nil, [:a, :b, :c], [:d, :c, :a], repetitions: 8)
    rows = BirdsongSongbook.summary(counts)

    assert Enum.find(rows, &(&1.heard == :a)).predicted_response == :d
    assert Enum.find(rows, &(&1.heard == :b)).predicted_response == :c
    assert Enum.find(rows, &(&1.heard == :c)).predicted_response == :a
  end
end
