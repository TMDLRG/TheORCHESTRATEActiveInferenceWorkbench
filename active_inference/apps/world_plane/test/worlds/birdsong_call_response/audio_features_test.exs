defmodule WorldPlane.Worlds.BirdsongCallResponse.AudioFeaturesTest do
  use ExUnit.Case, async: true

  alias WorldPlane.Worlds.BirdsongCallResponse.AudioFeatures
  alias WorldPlane.Worlds.BirdsongCallResponse.Synth

  test "extracts coarse motifs from local synthetic WAV input" do
    wav = Synth.render_wav([:a, :c])

    assert {:ok, extracted} = AudioFeatures.extract(wav)
    assert extracted.sample_rate == 16_000
    assert extracted.duration_ms > 0
    assert extracted.motifs == [:a, :c]
    assert extracted.confidence > 0.0

    assert [
             %{heard_motif: :a, turn_phase: :call},
             %{heard_motif: :silence, turn_phase: :response_due},
             %{heard_motif: :c, turn_phase: :gap},
             %{heard_motif: :silence, turn_phase: :response_due}
           ] = extracted.ticks
  end

  test "rejects unsupported input" do
    assert {:error, :invalid_wav} = AudioFeatures.extract("not a wav")
  end
end
