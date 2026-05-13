defmodule WorldPlane.Worlds.BirdsongCallResponse.AudioFeatures do
  @moduledoc """
  Small deterministic WAV-to-motif extractor for the Birdsong Call-Response lab.

  Scope is intentionally narrow: mono 16-bit PCM WAV, short clips, and coarse
  synthetic motif bins. Real species classification is outside this module.
  """

  @sample_rate 16_000
  @max_duration_ms 5_000
  @frame_ms 20
  @hop_ms 10

  @type extracted :: %{
          sample_rate: pos_integer(),
          duration_ms: non_neg_integer(),
          motifs: [atom()],
          confidence: float(),
          ticks: [map()]
        }

  @doc "Extract coarse motif tokens from a WAV binary."
  @spec extract(binary()) :: {:ok, extracted()} | {:error, term()}
  def extract(wav) when is_binary(wav) do
    with {:ok, %{sample_rate: @sample_rate, samples: samples}} <- decode_pcm16_mono(wav),
         :ok <- validate_duration(samples),
         {:ok, motifs, ticks, confidence} <- motifs_from_samples(samples) do
      {:ok,
       %{
         sample_rate: @sample_rate,
         duration_ms: round(length(samples) / @sample_rate * 1000),
         motifs: motifs,
         confidence: confidence,
         ticks: ticks
       }}
    else
      {:ok, %{sample_rate: sr}} -> {:error, {:unsupported_sample_rate, sr}}
      {:error, reason} -> {:error, reason}
    end
  end

  @doc "Build the observation timeline consumed by the birdsong world."
  @spec observation_ticks([atom()]) :: [map()]
  def observation_ticks([]), do: [%{heard_motif: :silence, turn_phase: :call}]

  def observation_ticks(motifs) do
    motifs
    |> Enum.with_index()
    |> Enum.flat_map(fn {motif, i} ->
      phase = if i == 0, do: :call, else: :gap

      [
        %{heard_motif: motif, turn_phase: phase},
        %{heard_motif: :silence, turn_phase: :response_due}
      ]
    end)
  end

  defp decode_pcm16_mono(
         <<"RIFF", _riff::little-32, "WAVE", "fmt ", fmt_size::little-32,
           fmt::binary-size(fmt_size), rest::binary>>
       ) do
    with <<1::little-16, 1::little-16, sample_rate::little-32, _byte_rate::little-32,
           _block_align::little-16, 16::little-16, _::binary>> <- fmt,
         {:ok, data} <- find_data_chunk(rest) do
      samples =
        for <<s::little-signed-16 <- data>> do
          s / 32_768.0
        end

      {:ok, %{sample_rate: sample_rate, samples: samples}}
    else
      _ -> {:error, :unsupported_wav_format}
    end
  end

  defp decode_pcm16_mono(_), do: {:error, :invalid_wav}

  defp find_data_chunk(<<"data", size::little-32, data::binary-size(size), _::binary>>),
    do: {:ok, data}

  defp find_data_chunk(
         <<_id::binary-size(4), size::little-32, _chunk::binary-size(size), rest::binary>>
       ),
       do: find_data_chunk(rest)

  defp find_data_chunk(_), do: {:error, :missing_data_chunk}

  defp validate_duration(samples) do
    duration_ms = length(samples) / @sample_rate * 1000

    if duration_ms <= @max_duration_ms do
      :ok
    else
      {:error, {:clip_too_long_ms, round(duration_ms)}}
    end
  end

  defp motifs_from_samples(samples) do
    frame = div(@frame_ms * @sample_rate, 1000)
    hop = div(@hop_ms * @sample_rate, 1000)
    frames = frame_samples(samples, frame, hop)

    energies = Enum.map(frames, &rms/1)
    threshold = max(0.02, percentile(energies, 0.95) * 0.15)

    active =
      frames
      |> Enum.zip(energies)
      |> Enum.with_index()
      |> Enum.filter(fn {{_frame, energy}, _idx} -> energy > threshold end)

    case active do
      [] ->
        {:ok, [:silence], observation_ticks([:silence]), 0.0}

      list ->
        segments = contiguous_segments(list)

        motif_scores =
          Enum.map(segments, fn seg ->
            samples = Enum.flat_map(seg, fn {{frame_samples, _energy}, _idx} -> frame_samples end)
            freq = estimate_frequency(samples)
            motif = motif_for_frequency(freq)
            confidence = confidence_for(motif, freq)
            {motif, confidence, freq}
          end)

        motifs =
          motif_scores
          |> Enum.map(fn {m, _c, _f} -> m end)
          |> squash_repeats()

        confidence =
          motif_scores
          |> Enum.map(fn {_m, c, _f} -> c end)
          |> mean()

        {:ok, motifs, observation_ticks(motifs), confidence}
    end
  end

  defp frame_samples(samples, frame, hop) do
    max_start = max(length(samples) - frame, 0)

    0..max_start//hop
    |> Enum.map(fn start -> samples |> Enum.drop(start) |> Enum.take(frame) end)
    |> Enum.reject(&(length(&1) < frame))
  end

  defp rms(samples) do
    :math.sqrt(Enum.reduce(samples, 0.0, fn x, acc -> acc + x * x end) / max(length(samples), 1))
  end

  defp percentile([], _), do: 0.0

  defp percentile(values, q) do
    sorted = Enum.sort(values)
    idx = round((length(sorted) - 1) * q)
    Enum.at(sorted, idx)
  end

  defp contiguous_segments(active) do
    active
    |> Enum.chunk_while(
      [],
      fn item, acc ->
        idx = elem(item, 1)

        case acc do
          [] -> {:cont, [item]}
          [prev | _] when elem(prev, 1) + 1 == idx -> {:cont, [item | acc]}
          _ -> {:cont, Enum.reverse(acc), [item]}
        end
      end,
      fn
        [] -> {:cont, []}
        acc -> {:cont, Enum.reverse(acc), []}
      end
    )
  end

  defp estimate_frequency(samples) do
    min_lag = div(@sample_rate, 6_000)
    max_lag = div(@sample_rate, 1_500)

    {best_lag, _score} =
      min_lag..max_lag
      |> Enum.map(fn lag -> {lag, autocorr(samples, lag)} end)
      |> Enum.max_by(fn {_lag, score} -> score end, fn -> {0, 0.0} end)

    if best_lag > 0, do: @sample_rate / best_lag, else: 0.0
  end

  defp autocorr(samples, lag) do
    samples
    |> Enum.drop(lag)
    |> Enum.zip(samples)
    |> Enum.reduce(0.0, fn {a, b}, acc -> acc + a * b end)
  end

  defp motif_for_frequency(freq) when freq >= 1_500 and freq < 2_450, do: :a
  defp motif_for_frequency(freq) when freq >= 2_450 and freq < 3_350, do: :b
  defp motif_for_frequency(freq) when freq >= 3_350 and freq < 4_250, do: :c
  defp motif_for_frequency(freq) when freq >= 4_250 and freq <= 6_000, do: :d
  defp motif_for_frequency(_), do: :unknown

  defp confidence_for(:unknown, _), do: 0.2
  defp confidence_for(_, _), do: 0.9

  defp squash_repeats(list) do
    list
    |> Enum.reduce([], fn
      x, [x | _] = acc -> acc
      x, acc -> [x | acc]
    end)
    |> Enum.reverse()
  end

  defp mean([]), do: 0.0
  defp mean(xs), do: Enum.sum(xs) / length(xs)
end
