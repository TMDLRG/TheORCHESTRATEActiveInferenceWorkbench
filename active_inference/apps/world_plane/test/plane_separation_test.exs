defmodule WorldPlane.PlaneSeparationTest do
  use ExUnit.Case, async: true

  @world_plane_dir Path.join([__DIR__, "..", "lib"])

  test "T3 — no source file under world_plane/lib imports :agent_plane symbols" do
    files = Path.wildcard(Path.join(@world_plane_dir, "**/*.ex"))

    offenders =
      for f <- files,
          contents = File.read!(f),
          stripped = strip_docstrings(contents),
          Regex.match?(
            ~r/\balias\s+(AgentPlane|ActiveInferenceCore)\b|(AgentPlane|ActiveInferenceCore)\.[A-Z]/,
            stripped
          ),
          do: f

    assert offenders == [],
           "world plane must not reference agent-plane or active-inference-core symbols. Offenders: #{inspect(offenders)}"
  end

  test "T3 — world_plane mix.exs does not DEPEND on :agent_plane" do
    mix_file = Path.join([__DIR__, "..", "mix.exs"])
    contents = File.read!(mix_file)

    # Look for actual dep tuples, not comments.
    refute Regex.match?(~r/\{\s*:agent_plane\s*,/, contents)
    refute Regex.match?(~r/\{\s*:active_inference_core\s*,/, contents)
  end

  defp strip_docstrings(source) do
    source
    |> String.replace(~r/@(module)?doc\s+"""[\s\S]*?"""/m, "")
  end
end
