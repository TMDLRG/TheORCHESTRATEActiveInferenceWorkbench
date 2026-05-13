defmodule WorldPlane.Worlds.BirdsongCallResponse.SynthTest do
  use ExUnit.Case, async: true

  alias WorldPlane.Worlds.BirdsongCallResponse.Synth

  test "renders deterministic 16-bit mono WAV" do
    wav = Synth.render_wav([:a, :b])

    assert <<"RIFF", _::little-32, "WAVE", "fmt ", _::binary>> = wav
    assert byte_size(wav) > 44
    assert Synth.render_wav([:a, :b]) == wav
    assert Synth.sample_rate() == 16_000
  end
end
