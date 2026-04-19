defmodule ActiveInferenceCore.DiscreteTimeTelemetryTest do
  @moduledoc """
  Plan §8.4 + §12 Phase 4 — per-equation telemetry spans.

  Every public `DiscreteTime` function wraps its body in
  `:telemetry.span/3` with a shared base event name
  `[:active_inference_core, :discrete_time, :call]` and metadata
  `{fn: atom, arity: int}`. This gives Glass Engine a uniform stream
  of equation-level calls without coupling the math core to the
  equation registry.
  """

  use ExUnit.Case, async: false

  alias ActiveInferenceCore.DiscreteTime

  @event_start [:active_inference_core, :discrete_time, :call, :start]
  @event_stop [:active_inference_core, :discrete_time, :call, :stop]

  setup do
    parent = self()
    handler_id = "dt-telemetry-test-#{System.unique_integer([:positive])}"

    :ok =
      :telemetry.attach_many(
        handler_id,
        [@event_start, @event_stop],
        fn event, measures, meta, _ ->
          send(parent, {:tm, event, measures, meta})
        end,
        nil
      )

    on_exit(fn -> :telemetry.detach(handler_id) end)
    :ok
  end

  describe "T1: predict_obs emits :start and :stop spans" do
    test "event shape includes fn and arity" do
      a = [[0.9, 0.1], [0.1, 0.9]]
      s = [0.5, 0.5]

      _ = DiscreteTime.predict_obs(a, s)

      assert_receive {:tm, @event_start, _, %{fn: :predict_obs, arity: 2}}, 500
      assert_receive {:tm, @event_stop, %{duration: d}, %{fn: :predict_obs, arity: 2}}, 500
      assert is_integer(d) and d >= 0
    end
  end

  describe "T2: every public function emits a span" do
    test "policy_posterior" do
      _ = DiscreteTime.policy_posterior([0.0, 1.0], [0.0, 0.5])
      assert_receive {:tm, @event_stop, _, %{fn: :policy_posterior}}, 500
    end

    test "update_state_beliefs" do
      _ =
        DiscreteTime.update_state_beliefs(
          nil,
          [0.5, 0.5],
          nil,
          [1.0, 0.0],
          [[0.9, 0.1], [0.1, 0.9]],
          nil,
          nil,
          1.0
        )

      assert_receive {:tm, @event_stop, _, %{fn: :update_state_beliefs}}, 500
    end
  end

  describe "T3: span metadata includes process-dict telemetry context" do
    test "forwarder reads :wm_telemetry_context via process dict" do
      # The span itself only carries fn/arity. The *forwarder* picks up
      # context via Process.get/1 — this test asserts Process.get works
      # in the synchronous handler context (so the forwarder can rely on it).
      Process.put(:wm_telemetry_context, %{agent_id: "agent-ctx-test"})

      parent = self()
      handler_id = "dt-ctx-test-#{System.unique_integer([:positive])}"

      :ok =
        :telemetry.attach(
          handler_id,
          @event_stop,
          fn _e, _m, _meta, _ ->
            send(parent, {:ctx, Process.get(:wm_telemetry_context)})
          end,
          nil
        )

      _ = DiscreteTime.predict_obs([[0.5, 0.5]], [1.0, 0.0])

      assert_receive {:ctx, %{agent_id: "agent-ctx-test"}}, 500

      :telemetry.detach(handler_id)
      Process.delete(:wm_telemetry_context)
    end
  end
end
