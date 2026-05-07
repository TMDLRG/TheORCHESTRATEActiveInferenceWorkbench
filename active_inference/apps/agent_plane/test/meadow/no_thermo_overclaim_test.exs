defmodule AgentPlane.Meadow.NoThermoOverclaimTest do
  @moduledoc """
  AUDIT ANCHOR: no thermodynamic over-claim in code or docstrings.

  Project CLAUDE.md adjudication anchor:

      "'Enthalpy' for E_q[-ln p] is analogical only; no pV term exists.
      Helmholtz/Gibbs distinction does not 'disappear' under metaphor."

  This test enforces the discipline at the source-code level — any
  occurrence of forbidden thermodynamic language outside of an
  explicitly disclaiming context fails.

  Forbidden tokens (case-insensitive): `enthalpy`, `helmholtz`, `gibbs`.
  Permitted only in:
    * the words "**not** Helmholtz", "**not** Gibbs", etc. (audit notes)
    * docstrings that explicitly mark the analogy as analogical (the
      sentinel string `analogical only` must appear in the same file)

  The lint runs over `apps/agent_plane/lib` and `apps/world_plane/lib`.
  """

  use ExUnit.Case, async: true

  @forbidden ["enthalpy", "enthalp", "helmholtz", "gibbs", "pv-work", "free-energy-principle"]

  defp lib_roots do
    cwd = File.cwd!()
    parent = Path.dirname(cwd)

    [
      Path.join(cwd, "lib"),
      Path.join([parent, "world_plane", "lib"])
    ]
    |> Enum.filter(&File.dir?/1)
  end

  defp scan_files do
    lib_roots()
    |> Enum.flat_map(fn root ->
      Path.wildcard(Path.join(root, "**/*.{ex,exs}"))
    end)
    |> Enum.reject(fn path ->
      # Don't lint THIS test file (which intentionally names the forbidden tokens).
      Path.basename(path) == "no_thermo_overclaim_test.exs"
    end)
  end

  test "no forbidden thermodynamic tokens in lib code, except in disclaimed docstrings" do
    offenses =
      scan_files()
      |> Enum.flat_map(fn path ->
        contents = File.read!(path)
        downcased = String.downcase(contents)

        violations =
          @forbidden
          |> Enum.filter(fn token -> String.contains?(downcased, token) end)
          |> Enum.reject(fn _token ->
            # Allow if the file explicitly disclaims the analogy.
            String.contains?(downcased, "analogical only") or
              String.contains?(downcased, "analogy only") or
              String.contains?(downcased, "not literal")
          end)

        Enum.map(violations, fn token -> {path, token} end)
      end)

    if offenses != [] do
      msg =
        offenses
        |> Enum.map(fn {p, t} -> "  - #{p}: #{t}" end)
        |> Enum.join("\n")

      flunk("""
      Thermodynamic over-claim detected — these files use forbidden tokens
      without an "analogical only" / "not literal" disclaimer:

      #{msg}

      Per the project CLAUDE.md audit adjudication anchor, terms like
      'enthalpy', 'Helmholtz', 'Gibbs' may only appear with an explicit
      analogy disclaimer in the same file.
      """)
    end

    assert offenses == []
  end
end
