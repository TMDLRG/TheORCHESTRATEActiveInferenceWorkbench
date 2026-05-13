defmodule WorldPlane.Worlds.BirdsongCallResponse do
  @moduledoc """
  Single-agent generative process for the Birdsong Call-Response lab.

  The world owns the input motif timeline and the consequences of emitted
  response actions. It never reads agent beliefs or free-energy quantities.
  """

  use GenServer
  @behaviour WorldPlane.WorldBehaviour

  alias SharedContracts.{ActionPacket, Blanket, ObservationPacket}
  alias WorldPlane.Worlds.BirdsongCallResponse.AudioFeatures

  @motifs [:a, :b, :c, :d]

  @doc "Unique world identifier for the Birdsong Call-Response lab."
  @impl WorldPlane.WorldBehaviour
  def id, do: :birdsong_call_response

  @doc "Human-readable world name."
  @impl WorldPlane.WorldBehaviour
  def name, do: "Birdsong Call-Response"

  @doc "Markov blanket exposed by this world."
  @impl WorldPlane.WorldBehaviour
  def blanket, do: Blanket.birdsong_default()

  @doc "Flat POMDP observation/state dimensionality expected by the matching bundle."
  @impl WorldPlane.WorldBehaviour
  def dims, do: %{n_obs: 360, n_states: 360}

  @doc "Boot a new birdsong call-response world process."
  @impl WorldPlane.WorldBehaviour
  def boot(opts), do: start_link(opts)

  @doc "Apply one action packet and return the next observation packet."
  @impl WorldPlane.WorldBehaviour
  def step(pid, %ActionPacket{} = action), do: GenServer.call(pid, {:step, action})

  @doc "Return whether the world has reached its terminal condition."
  @impl WorldPlane.WorldBehaviour
  def terminal?(pid), do: GenServer.call(pid, :terminal?)

  @doc "Reset the running world to its initial motif timeline."
  @impl WorldPlane.WorldBehaviour
  def reset(pid), do: GenServer.call(pid, :reset)

  @doc "Stop the running world process."
  @impl WorldPlane.WorldBehaviour
  def stop(pid), do: GenServer.stop(pid)

  @doc "Start a birdsong call-response world from `:motifs`, `:ticks`, or `:wav`."
  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts)
  end

  @doc "Decode a WAV binary into world boot options."
  @spec from_wav(binary()) :: {:ok, keyword()} | {:error, term()}
  def from_wav(wav) do
    with {:ok, extracted} <- AudioFeatures.extract(wav) do
      {:ok, [ticks: extracted.ticks, extracted: extracted]}
    end
  end

  @doc "Return a read-only snapshot for tests and the LiveView."
  @spec peek(pid()) :: map()
  def peek(pid), do: GenServer.call(pid, :peek)

  @doc "Return the current observation without advancing time."
  @spec current_observation(pid()) :: ObservationPacket.t()
  def current_observation(pid), do: GenServer.call(pid, :current_observation)

  @doc "Canonical complement response map."
  @spec complement(atom()) :: atom()
  def complement(:a), do: :b
  def complement(:b), do: :a
  def complement(:c), do: :d
  def complement(:d), do: :c
  def complement(_), do: :none

  @impl GenServer
  def init(opts) do
    blanket = Keyword.get(opts, :blanket, Blanket.birdsong_default())
    run_id = Keyword.get(opts, :run_id, random_id())

    {ticks, extracted} =
      cond do
        Keyword.has_key?(opts, :ticks) ->
          {Keyword.fetch!(opts, :ticks), Keyword.get(opts, :extracted)}

        Keyword.has_key?(opts, :motifs) ->
          motifs = Keyword.fetch!(opts, :motifs)
          {AudioFeatures.observation_ticks(motifs), %{motifs: motifs, confidence: 1.0}}

        true ->
          {AudioFeatures.observation_ticks([:a]), %{motifs: [:a], confidence: 1.0}}
      end

    {:ok,
     %{
       initial_ticks: ticks,
       ticks: ticks,
       extracted: extracted,
       t: 0,
       last_self: :none,
       last_fit: :none,
       response_events: [],
       blanket: blanket,
       run_id: run_id,
       terminal?: false
     }}
  end

  @impl GenServer
  def handle_call(:current_observation, _from, state) do
    {:reply, observation(state), state}
  end

  def handle_call({:step, %ActionPacket{action: action}}, _from, state) do
    self_token = action_to_token(action)
    current = current_tick(state)
    fit = response_fit(current.heard_motif, self_token)

    event =
      if self_token in @motifs do
        [%{t: state.t, action: action, token: self_token}]
      else
        []
      end

    next_t = state.t + 1

    new_state = %{
      state
      | t: next_t,
        last_self: self_token,
        last_fit: fit,
        response_events: state.response_events ++ event,
        terminal?: next_t >= length(state.ticks) and event != []
    }

    {:reply, {:ok, observation(new_state)}, new_state}
  end

  def handle_call(:terminal?, _from, state), do: {:reply, state.terminal?, state}
  def handle_call(:peek, _from, state), do: {:reply, state, state}

  def handle_call(:reset, _from, state) do
    {:reply, :ok,
     %{
       state
       | ticks: state.initial_ticks,
         t: 0,
         last_self: :none,
         last_fit: :none,
         response_events: [],
         terminal?: false
     }}
  end

  defp observation(state) do
    tick = current_tick(state)

    ObservationPacket.new(%{
      t: state.t,
      channels: %{
        heard_motif: tick.heard_motif,
        turn_phase: tick.turn_phase,
        self_sang_motif: state.last_self,
        response_fit: state.last_fit
      },
      world_run_id: state.run_id,
      terminal?: state.terminal?,
      blanket: state.blanket
    })
  end

  defp current_tick(%{ticks: []}), do: %{heard_motif: :silence, turn_phase: :call}

  defp current_tick(state) do
    Enum.at(state.ticks, min(state.t, length(state.ticks) - 1))
  end

  defp action_to_token(:listen), do: :none
  defp action_to_token(:sing_a), do: :a
  defp action_to_token(:sing_b), do: :b
  defp action_to_token(:sing_c), do: :c
  defp action_to_token(:sing_d), do: :d
  defp action_to_token(_), do: :none

  defp response_fit(_heard, :none), do: :none

  defp response_fit(heard, self) when heard in @motifs and self in @motifs do
    if complement(heard) == self, do: :good_fit, else: :poor_fit
  end

  defp response_fit(_, _), do: :none

  defp random_id do
    "birdsong-" <> (:crypto.strong_rand_bytes(6) |> Base.url_encode64(padding: false))
  end
end
