defmodule WorkbenchWeb.Qwen.EpisodeSnapTest do
  @moduledoc """
  Unit coverage for `WorkbenchWeb.Qwen.EpisodeSnap.from_session_id/1`.

  Focus: the module must be bulletproof against dead / missing / slow
  episodes, since it runs per-Qwen-request and any exception or timeout
  would break the drawer.
  """
  use ExUnit.Case, async: true

  alias WorkbenchWeb.Qwen.EpisodeSnap

  describe "from_session_id/1 — degenerate inputs" do
    test "nil returns nil" do
      assert EpisodeSnap.from_session_id(nil) == nil
    end

    test "empty string is treated as missing" do
      # from_session_id/1 only has a string clause; "" trips the registry lookup
      # which exits, which is caught -> nil.
      assert EpisodeSnap.from_session_id("") == nil
    end

    test "unknown session_id returns nil" do
      assert EpisodeSnap.from_session_id("no-such-session-" <> random()) == nil
    end

    test "non-binary input returns nil" do
      assert EpisodeSnap.from_session_id(:atom) == nil
      assert EpisodeSnap.from_session_id(42) == nil
    end
  end

  defp random do
    :crypto.strong_rand_bytes(4) |> Base.url_encode64(padding: false)
  end
end
