defmodule AgentPlane.PlaneSeparationTest do
  use ExUnit.Case, async: true

  @agent_plane_dir Path.join([__DIR__, "..", "lib"])

  test "T3 — no source file under agent_plane/lib imports :world_plane symbols" do
    files = Path.wildcard(Path.join(@agent_plane_dir, "**/*.ex"))

    # We detect real imports/aliases, not prose in docstrings. A real usage is
    # indicated by `WorldPlane.<Module>` or `alias WorldPlane`.
    offenders =
      for f <- files,
          contents = File.read!(f),
          Regex.match?(
            ~r/\balias\s+WorldPlane\b|\bWorldPlane\.[A-Z]/,
            strip_docstrings(contents)
          ),
          do: f

    assert offenders == [],
           "agent plane must not reference world-plane symbols. Offenders: #{inspect(offenders)}"
  end

  defp strip_docstrings(source) do
    # Remove @moduledoc and @doc heredoc strings so comments mentioning
    # WorldPlane in prose don't trip the plane-separation audit.
    source
    |> String.replace(~r/@(module)?doc\s+"""[\s\S]*?"""/m, "")
  end

  test "T3 — agent_plane mix.exs does not DEPEND on :world_plane" do
    mix_file = Path.join([__DIR__, "..", "mix.exs"])
    refute Regex.match?(~r/\{\s*:world_plane\s*,/, File.read!(mix_file))
  end
end
