defmodule AgentPlane.Telemetry.ContextTest do
  @moduledoc """
  AUDIT REGRESSION (external review K3, v1+v2): document and verify
  the parallelisation behaviour of `AgentPlane.Telemetry.Context`.

  The `Process.put/get`-based context does not propagate across
  `Task.async` or `Task.async_stream` boundaries. This is a documented
  caveat in the moduledoc; this test asserts the behaviour at runtime
  so any future refactor that breaks the explicit-threading
  requirement fails-loud.
  """

  use ExUnit.Case, async: true

  alias AgentPlane.Telemetry.Context

  describe "K3: process dict does not propagate to Task children" do
    test "with_agent_context sets context within the calling process" do
      Context.with_agent_context(%{agent_id: "k3-a", spec_id: "s"}, fn ->
        assert Context.current() == %{
                 agent_id: "k3-a",
                 spec_id: "s",
                 bundle_id: nil,
                 family_id: nil,
                 verification_status: nil
               }
      end)

      # After the with_agent_context block ends, dict is cleared.
      refute Context.current()
    end

    test "Task.async children do NOT see the parent's context" do
      results =
        Context.with_agent_context(%{agent_id: "k3-parent"}, fn ->
          # Capture parent's view inside the block.
          parent_view = Context.current()

          # Child sees nothing — process dict does not propagate.
          child_view =
            Task.async(fn -> Context.current() end)
            |> Task.await()

          {parent_view, child_view}
        end)

      {parent_view, child_view} = results

      assert parent_view.agent_id == "k3-parent"

      assert child_view == nil,
             "Task.async child unexpectedly inherited the parent's process dict — " <>
               "this would break the K3 invariant that propagation is explicit-only"
    end

    test "Task.async_stream children do NOT see the parent's context" do
      child_views =
        Context.with_agent_context(%{agent_id: "k3-stream"}, fn ->
          1..5
          |> Task.async_stream(fn _ -> Context.current() end, max_concurrency: 4)
          |> Enum.map(fn {:ok, v} -> v end)
        end)

      assert Enum.all?(child_views, &is_nil/1),
             "Task.async_stream children inherited parent's context: #{inspect(child_views)}"
    end

    test "explicit threading: capture parent context, re-establish in child" do
      # The supported pattern when parallelisation is required.
      results =
        Context.with_agent_context(%{agent_id: "k3-explicit", bundle_id: "b1"}, fn ->
          captured = Context.current()

          1..3
          |> Task.async_stream(
            fn i ->
              # Child re-establishes the context explicitly.
              Context.with_agent_context(captured, fn ->
                {i, Context.current()}
              end)
            end,
            max_concurrency: 2
          )
          |> Enum.map(fn {:ok, v} -> v end)
        end)

      Enum.each(results, fn {_i, view} ->
        assert view.agent_id == "k3-explicit"
        assert view.bundle_id == "b1"
      end)
    end

    test "nested with_agent_context restores the previous context on exit" do
      Context.with_agent_context(%{agent_id: "outer"}, fn ->
        outer = Context.current()

        Context.with_agent_context(%{agent_id: "inner"}, fn ->
          assert Context.current().agent_id == "inner"
        end)

        # After inner block, outer context is restored, not cleared.
        assert Context.current() == outer
      end)
    end
  end
end
