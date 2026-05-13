defmodule WorkbenchWeb.BirdsongCallResponseLive.Index do
  @moduledoc """
  LiveView for the separate Birdsong Call-Response lab.
  """

  use WorkbenchWeb, :live_view

  alias AgentPlane.{BirdsongSongbook, BundleBuilder.Birdsong}
  alias WorkbenchWeb.Episode.BirdsongEpisode
  alias WorldPlane.Worlds.BirdsongCallResponse
  alias WorldPlane.Worlds.BirdsongCallResponse.AudioFeatures
  alias WorldPlane.Worlds.BirdsongCallResponse.Synth

  @impl true
  def mount(_params, _session, socket) do
    wav = Synth.demo_call_wav(:a)
    {:ok, opts} = BirdsongCallResponse.from_wav(wav)

    socket =
      socket
      |> assign(:motif_text, "a")
      |> assign(:target_text, "b")
      |> assign(:training_repetitions, "8")
      |> assign(:songbook_counts, nil)
      |> assign(:learning_updates, 0)
      |> assign(:learning_message, "Fixed complement prior; no songbook examples learned yet.")
      |> assign(:input_wav, wav)
      |> assign(:input_data_url, data_url(wav))
      |> assign(:world_opts, opts)
      |> assign(:extracted, Keyword.get(opts, :extracted))
      |> assign(:episode_pid, nil)
      |> assign(:snapshot, nil)
      |> assign(:status, :ready)
      |> assign(:message, nil)
      |> allow_upload(:birdsong,
        accept: ~w(.wav audio/wav),
        max_entries: 1,
        max_file_size: 5_000_000
      )

    {:ok, socket}
  end

  @impl true
  def handle_event("load_demo", %{"motif" => motif}, socket) do
    motif_atom = String.to_existing_atom(motif)
    wav = Synth.demo_call_wav(motif_atom)
    {:ok, opts} = BirdsongCallResponse.from_wav(wav)

    {:noreply,
     socket
     |> stop_existing()
     |> assign_input(wav, opts, Atom.to_string(motif_atom))
     |> assign(:snapshot, nil)
     |> assign(:status, :ready)
     |> assign(:message, nil)}
  end

  def handle_event("load_text", %{"motifs" => motifs}, socket) do
    with {:ok, motif_list} <- parse_motifs(motifs) do
      wav = Synth.render_wav(motif_list)
      extracted = symbolic_extracted(motif_list)
      opts = [ticks: extracted.ticks, extracted: extracted]

      {:noreply,
       socket
       |> stop_existing()
       |> assign_input(wav, opts, Enum.map_join(motif_list, ",", &Atom.to_string/1))
       |> assign(:snapshot, nil)
       |> assign(:status, :ready)
       |> assign(:message, nil)}
    else
      {:error, msg} -> {:noreply, assign(socket, :message, inspect(msg))}
    end
  end

  def handle_event(
        "train_songbook",
        %{"motifs" => heard_text, "target_motifs" => target_text, "repetitions" => reps_text},
        socket
      ) do
    with {:ok, heard} <- parse_motifs(heard_text),
         {:ok, targets} <- parse_motifs(target_text),
         :ok <- same_length(heard, targets),
         {repetitions, ""} <- Integer.parse(reps_text),
         true <- repetitions > 0 do
      counts =
        BirdsongSongbook.learn_pairs(socket.assigns.songbook_counts, heard, targets,
          repetitions: repetitions,
          learning_rate: 1.0,
          prior_concentration: 1.0
        )

      {:noreply,
       socket
       |> assign(:songbook_counts, counts)
       |> assign(:target_text, Enum.map_join(targets, ",", &Atom.to_string/1))
       |> assign(:training_repetitions, Integer.to_string(repetitions))
       |> update(:learning_updates, &(&1 + repetitions * length(heard)))
       |> assign(
         :learning_message,
         "Learned #{length(heard)} paired motif(s) for #{repetitions} repetition(s)."
       )
       |> assign(:message, nil)}
    else
      {:error, msg} ->
        {:noreply, assign(socket, :message, msg)}

      false ->
        {:noreply, assign(socket, :message, "Training repetitions must be a positive integer.")}

      :error ->
        {:noreply, assign(socket, :message, "Training repetitions must be a positive integer.")}

      _ ->
        {:noreply, assign(socket, :message, "Could not train songbook from those examples.")}
    end
  end

  def handle_event("reset_learning", _params, socket) do
    {:noreply,
     socket
     |> assign(:songbook_counts, nil)
     |> assign(:learning_updates, 0)
     |> assign(:learning_message, "Fixed complement prior; no songbook examples learned yet.")}
  end

  def handle_event("load_upload", _params, socket) do
    results =
      consume_uploaded_entries(socket, :birdsong, fn %{path: path}, _entry ->
        with {:ok, wav} <- File.read(path),
             {:ok, opts} <- BirdsongCallResponse.from_wav(wav) do
          {:ok, {wav, opts}}
        else
          {:error, reason} -> {:postpone, reason}
        end
      end)

    case results do
      [{wav, opts}] ->
        {:noreply,
         socket
         |> stop_existing()
         |> assign_input(wav, opts, motif_text_from_opts(opts))
         |> assign(:snapshot, nil)
         |> assign(:status, :ready)
         |> assign(:message, nil)}

      [] ->
        {:noreply, assign(socket, :message, "Choose a mono 16 kHz 16-bit PCM WAV first.")}

      other ->
        {:noreply, assign(socket, :message, "Could not load WAV: #{inspect(other)}")}
    end
  end

  def handle_event("run", _params, socket) do
    socket = stop_existing(socket)

    bundle =
      Birdsong.build(
        policy_depth: 1,
        action_selection: :argmax,
        softmax_temperature: 0.35,
        songbook_counts: socket.assigns.songbook_counts
      )

    sequence = BirdsongEpisode.run_motif_sequence(socket.assigns.extracted.motifs, bundle)

    snapshot =
      Map.merge(sequence.last_snapshot, %{
        sequence: sequence,
        response_data_url: sequence.response_data_url
      })

    {:noreply,
     socket
     |> assign(:episode_pid, nil)
     |> assign(:snapshot, snapshot)
     |> assign(:status, :ran)
     |> assign(:message, nil)}
  end

  def handle_event("reset", _params, socket) do
    {:noreply,
     socket
     |> stop_existing()
     |> assign(:snapshot, nil)
     |> assign(:status, :ready)}
  end

  def handle_event("noop", _params, socket), do: {:noreply, socket}

  @impl true
  def terminate(_reason, socket) do
    _ = stop_existing(socket)
    :ok
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="birdsong-page">
      <header class="birdsong-header">
        <h1>Birdsong Call-Response</h1>
        <p>
          Teach a compact songbook, then watch a Jido Active Inference agent
          infer the heard motifs, evaluate policies with expected free energy,
          and sing a real WAV response.
        </p>
      </header>

      <section class="birdsong-flow" aria-label="Lab flow">
        <div>
          <strong>1. Hear</strong>
          <span>Load a motif song or WAV.</span>
        </div>
        <div>
          <strong>2. Teach</strong>
          <span>Pair it with the response song.</span>
        </div>
        <div>
          <strong>3. Infer</strong>
          <span>Run Jido Perceive -> Plan -> Act.</span>
        </div>
        <div>
          <strong>4. Sing</strong>
          <span>Play the generated response WAV.</span>
        </div>
      </section>

      <%= if @message do %>
        <div class="birdsong-alert"><%= @message %></div>
      <% end %>

      <section class="birdsong-band">
        <div class="birdsong-controls">
          <h2>Build The Call</h2>
          <form phx-submit="load_text">
            <label for="motifs">Song heard by the agent</label>
            <input id="motifs" name="motifs" value={@motif_text} placeholder="a,b,c,d" />
            <button type="submit">Load Song</button>
          </form>

          <div class="birdsong-demo-buttons">
            <button phx-click="load_demo" phx-value-motif="a">Demo A</button>
            <button phx-click="load_demo" phx-value-motif="b">Demo B</button>
            <button phx-click="load_demo" phx-value-motif="c">Demo C</button>
            <button phx-click="load_demo" phx-value-motif="d">Demo D</button>
          </div>

          <form phx-submit="load_upload" phx-change="noop">
            <label>Or upload a short motif WAV</label>
            <.live_file_input upload={@uploads.birdsong} />
            <button type="submit">Load WAV</button>
          </form>
        </div>

        <div class="birdsong-panel">
          <h2>Input Evidence</h2>
          <audio controls src={@input_data_url}></audio>
          <dl>
            <dt>Heard motifs</dt>
            <dd><%= inspect(@extracted && @extracted.motifs || []) %></dd>
            <dt>Extractor confidence</dt>
            <dd><%= confidence(@extracted) %></dd>
            <dt>Discrete ticks</dt>
            <dd><%= length(@extracted && @extracted.ticks || []) %></dd>
          </dl>
        </div>
      </section>

      <section class="birdsong-band">
        <div class="birdsong-controls">
          <h2>Teach The Response</h2>
          <form phx-submit="train_songbook">
            <label for="target_motifs">Correct response song</label>
            <input id="target_motifs" name="target_motifs" value={@target_text} placeholder="b,a,d,c" />
            <label for="repetitions">Training repetitions</label>
            <input id="repetitions" name="repetitions" value={@training_repetitions} />
            <input type="hidden" name="motifs" value={@motif_text} />
            <button type="submit">Train Songbook</button>
          </form>

          <button phx-click="reset_learning">Reset Learning</button>
          <p class="birdsong-note">
            Learning means the Dirichlet songbook table changes.
            No examples means the agent falls back to the fixed complement prior.
          </p>
        </div>

        <div class="birdsong-panel">
          <h2>Learning State</h2>
          <dl>
            <dt>Mode</dt>
            <dd><%= model_mode(@songbook_counts) %></dd>
            <dt>Latest update</dt>
            <dd><%= @learning_message %></dd>
            <dt>Example updates</dt>
            <dd><%= @learning_updates %></dd>
          </dl>
          <h3>Learned Songbook</h3>
          <table class="birdsong-small-table">
            <thead>
              <tr><th>Heard</th><th>Predicts</th><th>P(a)</th><th>P(b)</th><th>P(c)</th><th>P(d)</th></tr>
            </thead>
            <tbody>
              <%= for row <- songbook_rows(@songbook_counts) do %>
                <tr>
                  <td><%= row.heard %></td>
                  <td><%= row.predicted_response %></td>
                  <td><%= fmt(row.probabilities.a) %></td>
                  <td><%= fmt(row.probabilities.b) %></td>
                  <td><%= fmt(row.probabilities.c) %></td>
                  <td><%= fmt(row.probabilities.d) %></td>
                </tr>
              <% end %>
            </tbody>
          </table>
        </div>
      </section>

      <section class="birdsong-actions">
        <button class="primary" phx-click="run">Run Active Inference Response</button>
        <button phx-click="reset">Reset</button>
      </section>

      <%= if @snapshot do %>
        <section class="birdsong-band">
          <div class="birdsong-panel">
            <h2>Agent State</h2>
            <dl>
              <dt>Last action</dt>
              <dd><%= @snapshot.agent.last_action %></dd>
              <dt>Best policy</dt>
              <dd><%= inspect(@snapshot.agent.best_policy) %></dd>
              <dt>Best policy index</dt>
              <dd><%= @snapshot.agent.best_policy_index %></dd>
              <dt>Policy posterior entropy</dt>
              <dd><%= entropy(@snapshot.agent.policy_posterior) %></dd>
              <dt>Active path</dt>
              <dd>Jido Perceive -> Plan -> Act</dd>
            </dl>
          </div>

          <div class="birdsong-panel">
            <h2>Response</h2>
            <%= if @snapshot.response_data_url do %>
              <audio controls src={@snapshot.response_data_url}></audio>
            <% else %>
              <p>No response WAV emitted yet.</p>
            <% end %>
            <dl>
              <dt>World t</dt>
              <dd><%= @snapshot.world.t %></dd>
              <dt>Song response</dt>
              <dd><%= inspect(get_in(@snapshot, [:sequence, :response_motifs]) || []) %></dd>
              <dt>Response events</dt>
              <dd><%= inspect(@snapshot.world.response_events) %></dd>
              <dt>Terminal</dt>
              <dd><%= @snapshot.world.terminal? %></dd>
            </dl>
          </div>
        </section>

        <section class="birdsong-panel">
          <h2>Policy Quantities</h2>
          <table>
            <thead>
              <tr><th>#</th><th>Policy</th><th>q(pi)</th><th>F</th><th>G</th></tr>
            </thead>
            <tbody>
              <%= for row <- top_policy_rows(@snapshot) do %>
                <tr>
                  <td><%= row.index %></td>
                  <td><%= inspect(row.policy) %></td>
                  <td><%= fmt(row.q) %></td>
                  <td><%= fmt(row.f) %></td>
                  <td><%= fmt(row.g) %></td>
                </tr>
              <% end %>
            </tbody>
          </table>
        </section>

        <section class="birdsong-panel">
          <h2>Learned Songbook</h2>
          <table>
            <thead>
              <tr><th>Heard</th><th>Predicted response</th><th>P(a)</th><th>P(b)</th><th>P(c)</th><th>P(d)</th></tr>
            </thead>
            <tbody>
              <%= for row <- songbook_rows(@songbook_counts) do %>
                <tr>
                  <td><%= row.heard %></td>
                  <td><%= row.predicted_response %></td>
                  <td><%= fmt(row.probabilities.a) %></td>
                  <td><%= fmt(row.probabilities.b) %></td>
                  <td><%= fmt(row.probabilities.c) %></td>
                  <td><%= fmt(row.probabilities.d) %></td>
                </tr>
              <% end %>
            </tbody>
          </table>
        </section>

        <section class="birdsong-proof">
          <div>
            <h2>What This Proves</h2>
            <p>
              The response is not copied from a hidden audio file. The lab renders
              a new WAV from the selected action sequence. Repeated teaching
              changes <code>P(response | heard)</code>; planning then scores
              policies with F, G, and q(pi).
            </p>
          </div>
          <div>
            <h2>What This Does Not Claim</h2>
            <p>
              This is motif-level song learning. It does not identify real species,
              understand arbitrary wild recordings, or claim general intelligence.
              If the agent has never been taught a mapping, it uses its stated prior.
            </p>
          </div>
        </section>
      <% end %>
    </div>

    <style>
      .birdsong-page { max-width: 1120px; padding: 1.5rem 2rem; color: #e8e8e8; }
      .birdsong-header h1 { margin: 0 0 0.25rem; font-size: 1.7rem; color: #ffffff; }
      .birdsong-header p { margin: 0 0 1.25rem; color: #aeb8c5; }
      .birdsong-flow { display: grid; grid-template-columns: repeat(4, minmax(160px, 1fr)); gap: 0.75rem; margin: 0 0 1rem; }
      .birdsong-flow div { border: 1px solid #344154; background: #101a29; border-radius: 6px; padding: 0.75rem; min-height: 76px; }
      .birdsong-flow strong { display: block; color: #7dd3fc; margin-bottom: 0.25rem; }
      .birdsong-flow span { color: #dbe7f5; font-size: 0.92rem; }
      .birdsong-band { display: grid; grid-template-columns: minmax(300px, 1fr) minmax(300px, 1fr); gap: 1rem; align-items: start; margin: 1rem 0; }
      .birdsong-controls, .birdsong-panel { border: 1px solid #344154; background: #182231; border-radius: 6px; padding: 1rem; }
      .birdsong-controls form { margin-bottom: 0.8rem; display: grid; gap: 0.35rem; }
      .birdsong-demo-buttons { display: flex; gap: 0.4rem; flex-wrap: wrap; margin-bottom: 0.8rem; }
      .birdsong-note { margin: 0.75rem 0 0; color: #bfd0e4; line-height: 1.4; }
      .birdsong-actions { display: flex; gap: 0.5rem; margin: 1rem 0; }
      .birdsong-alert { background: #4d3c1a; border: 1px solid #b88a30; color: #ffd070; border-radius: 6px; padding: 0.6rem 0.8rem; }
      .birdsong-page button { border: 1px solid #4a5568; background: #263449; color: #f2f5f8; border-radius: 5px; padding: 0.5rem 0.8rem; cursor: pointer; }
      .birdsong-page button.primary { background: #0f766e; border-color: #14b8a6; font-weight: 700; }
      .birdsong-page input { background: #111827; border: 1px solid #4a5568; color: #ffffff; border-radius: 4px; padding: 0.5rem; }
      .birdsong-page audio { width: 100%; margin: 0.4rem 0 0.8rem; }
      .birdsong-page h2 { font-size: 1rem; color: #ffffff; margin: 0 0 0.6rem; }
      .birdsong-page h3 { font-size: 0.9rem; color: #dbeafe; margin: 0.9rem 0 0.4rem; }
      .birdsong-page dl { display: grid; grid-template-columns: 150px 1fr; gap: 0.25rem 0.75rem; margin: 0; }
      .birdsong-page dt { color: #9fb0c4; }
      .birdsong-page dd { margin: 0; color: #ffffff; overflow-wrap: anywhere; }
      .birdsong-page table { width: 100%; border-collapse: collapse; font-size: 0.9rem; }
      .birdsong-small-table { font-size: 0.82rem; margin-top: 0.35rem; }
      .birdsong-page th, .birdsong-page td { border: 1px solid #344154; padding: 0.4rem 0.5rem; text-align: left; }
      .birdsong-page th { color: #7dd3fc; background: #203047; }
      .birdsong-proof { display: grid; grid-template-columns: 1fr 1fr; gap: 1rem; margin: 1rem 0; }
      .birdsong-proof div { border: 1px solid #344154; background: #111d2b; border-radius: 6px; padding: 1rem; }
      .birdsong-proof p { margin: 0; color: #c8d8ea; line-height: 1.45; }
      .birdsong-proof code { color: #7dd3fc; }
      @media (max-width: 800px) { .birdsong-band, .birdsong-flow, .birdsong-proof { grid-template-columns: 1fr; } }
    </style>
    """
  end

  defp assign_input(socket, wav, opts, motif_text) do
    socket
    |> assign(:motif_text, motif_text)
    |> assign(:input_wav, wav)
    |> assign(:input_data_url, data_url(wav))
    |> assign(:world_opts, opts)
    |> assign(:extracted, Keyword.get(opts, :extracted))
  end

  defp parse_motifs(text) do
    motifs =
      text
      |> String.split([",", " ", "\n", "\t"], trim: true)
      |> Enum.map(&String.downcase/1)

    valid = ~w(a b c d)

    cond do
      motifs == [] ->
        {:error, "Enter at least one motif: a, b, c, or d."}

      Enum.any?(motifs, &(&1 not in valid)) ->
        {:error, "Motifs must be drawn from a, b, c, d."}

      true ->
        {:ok, Enum.map(motifs, &String.to_existing_atom/1)}
    end
  end

  defp same_length(a, b) do
    if length(a) == length(b) do
      :ok
    else
      {:error, "Input motif song and target response song must have the same number of notes."}
    end
  end

  defp stop_existing(socket) do
    case socket.assigns[:episode_pid] do
      pid when is_pid(pid) ->
        if Process.alive?(pid), do: BirdsongEpisode.stop(pid)
        assign(socket, :episode_pid, nil)

      _ ->
        socket
    end
  end

  defp motif_text_from_opts(opts) do
    opts
    |> Keyword.get(:extracted, %{})
    |> Map.get(:motifs, [])
    |> Enum.map_join(",", &Atom.to_string/1)
  end

  defp data_url(wav), do: "data:audio/wav;base64," <> Base.encode64(wav)

  defp songbook_rows(counts), do: BirdsongSongbook.summary(counts)

  defp symbolic_extracted(motifs) do
    %{
      sample_rate: Synth.sample_rate(),
      duration_ms: length(motifs) * 220,
      motifs: motifs,
      confidence: 1.0,
      ticks: AudioFeatures.observation_ticks(motifs)
    }
  end

  defp model_mode(nil), do: "Fixed prior"
  defp model_mode(_counts), do: "Learned songbook"

  defp confidence(nil), do: "n/a"
  defp confidence(%{confidence: c}), do: fmt(c)

  defp entropy([]), do: "n/a"

  defp entropy(p) do
    h =
      Enum.reduce(p, 0.0, fn x, acc ->
        if x > 0.0, do: acc - x * :math.log(x), else: acc
      end)

    fmt(h)
  end

  defp top_policy_rows(%{agent: agent}) do
    posterior = agent.policy_posterior || []
    f = agent.last_f || []
    g = agent.last_g || []

    posterior
    |> Enum.with_index()
    |> Enum.map(fn {q, idx} ->
      %{
        index: idx,
        q: q,
        f: Enum.at(f, idx),
        g: Enum.at(g, idx),
        policy: Enum.at(agent.policies, idx)
      }
    end)
    |> Enum.sort_by(& &1.q, :desc)
    |> Enum.take(5)
  end

  defp fmt(nil), do: "n/a"
  defp fmt(x) when is_float(x), do: :erlang.float_to_binary(x, decimals: 4)
  defp fmt(x) when is_integer(x), do: Integer.to_string(x)
end
