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

  ## What this lint catches and what it doesn't (C4 efficacy boundary)

  External-review C4 (v2, Cantrill): this lint allows the disclaimer
  phrase `"analogical only"` (or `"analogy only"` / `"not literal"`)
  *anywhere in the file* to excuse forbidden tokens *anywhere else in
  the file*. A future contributor who learns the rule can satisfy the
  lint by adding the disclaimer phrase as a docstring header at the top
  of a file, regardless of whether the rest of the file's prose
  maintains the analogy-versus-mechanism distinction.

  This is a textual lint, not a semantic check. **It catches naive
  overclaim** (someone who writes "the variational free energy is the
  Helmholtz free energy" in a moduledoc with no disclaimer anywhere).
  **It does not catch sophisticated overclaim** (someone who adds the
  disclaimer phrase once at the top of the file, then proceeds to use
  thermodynamic vocabulary as if it were literal mechanism throughout).

  A future hardening would tighten the proximity: require the
  disclaimer phrase within ~5 lines or the same docstring block as
  the forbidden token. Tracked as future work; the v1.1 lint is
  documented honestly so readers know what it does and doesn't do.

  Per Cantrill's framing: source-code-level enforcement is much better
  than no enforcement, even if the enforcement isn't airtight.
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
