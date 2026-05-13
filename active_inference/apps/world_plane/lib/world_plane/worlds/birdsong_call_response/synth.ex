defmodule WorldPlane.Worlds.BirdsongCallResponse.Synth do
  @moduledoc """
  Deterministic chirp renderer for the Birdsong Call-Response lab.

  The renderer is deliberately small and local: it maps symbolic response
  motifs to a 16-bit PCM WAV. It is not an AI audio model and performs no
  external calls.
  """

  @sample_rate 16_000
  @token_duration_ms 180
  @gap_ms 40
  @amp 0.65

  @type motif :: :a | :b | :c | :d

  @doc "Sample rate used by generated WAV files."
  @spec sample_rate() :: pos_integer()
  def sample_rate, do: @sample_rate

  @doc "Render a sequence of motifs to a PCM WAV binary."
  @spec render_wav([motif()]) :: binary()
  def render_wav(motifs) when is_list(motifs) do
    samples =
      motifs
      |> Enum.flat_map(fn motif -> chirp_samples(motif) ++ silence_samples(@gap_ms) end)
      |> trim_trailing_gap()

    pcm =
      samples
      |> Enum.map(&float_to_i16_le/1)
      |> IO.iodata_to_binary()

    wav_header(byte_size(pcm), @sample_rate) <> pcm
  end

  @doc "Built-in demo input call used by tests and the LiveView."
  @spec demo_call_wav(atom()) :: binary()
  def demo_call_wav(motif \\ :a), do: render_wav([motif])

  defp chirp_samples(motif) do
    {f0, f1} = freqs(motif)
    n_total = div(@token_duration_ms * @sample_rate, 1000)

    for n <- 0..(n_total - 1) do
      t = n / @sample_rate
      duration = n_total / @sample_rate
      phase = 2.0 * :math.pi() * (f0 * t + (f1 - f0) * t * t / (2.0 * duration))
      window = :math.pow(:math.sin(:math.pi() * n / max(n_total - 1, 1)), 2)
      @amp * window * :math.sin(phase)
    end
  end

  defp freqs(:a), do: {1_800.0, 2_400.0}
  defp freqs(:b), do: {2_600.0, 3_200.0}
  defp freqs(:c), do: {3_400.0, 4_000.0}
  defp freqs(:d), do: {4_500.0, 5_200.0}

  defp silence_samples(ms) do
    List.duplicate(0.0, div(ms * @sample_rate, 1000))
  end

  defp trim_trailing_gap([]), do: []

  defp trim_trailing_gap(samples) do
    gap_len = length(silence_samples(@gap_ms))
    Enum.take(samples, max(length(samples) - gap_len, 0))
  end

  defp float_to_i16_le(x) do
    clamped = max(-1.0, min(1.0, x))
    int = round(clamped * 32_767)
    <<int::little-signed-16>>
  end

  defp wav_header(data_bytes, sample_rate) do
    byte_rate = sample_rate * 2
    block_align = 2
    riff_size = 36 + data_bytes

    <<
      "RIFF",
      riff_size::little-32,
      "WAVE",
      "fmt ",
      16::little-32,
      1::little-16,
      1::little-16,
      sample_rate::little-32,
      byte_rate::little-32,
      block_align::little-16,
      16::little-16,
      "data",
      data_bytes::little-32
    >>
  end
end
