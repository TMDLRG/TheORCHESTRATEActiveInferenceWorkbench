defmodule AgentPlane.Meadow.QvsPNamingTest do
  @moduledoc """
  AUDIT ANCHOR: q (recognition density) and p(η|y) (exact posterior
  under the generative model) are distinct code paths with distinct
  names — they cannot be silently conflated.

  Project CLAUDE.md adjudication anchor:

      "q is variational/recognition density; p(η|y, m) is the exact
      posterior under the *generative model* (not the external
      process — those are distinct per SOURCE B Fig 2.2 caption,
      book line 1094). Markov blanket has three meanings; keep them
      separate."

  This test enforces the boundary at the source-code level:

    1. `AgentPlane.Skills.VariationalFreeEnergy` (the variational path)
       MUST NOT reference `AgentPlane.ExactInference` (the brute-force
       posterior path).

    2. `AgentPlane.ExactInference` MUST NOT take an agent struct as
       input — its public functions operate only on bundles (the
       generative-model side of the Markov blanket).

    3. The two modules MUST live in different files (so a future
       refactor that merges them shows up as a diff).
  """

  use ExUnit.Case, async: true

  @vfe_path "lib/agent_plane/skills/variational_free_energy.ex"
  @efe_path "lib/agent_plane/skills/expected_free_energy.ex"
  @exact_path "lib/agent_plane/exact_inference.ex"

  defp app_root do
    # Tests run from each app's own working directory.
    File.cwd!()
  end

  defp read_file_at(rel) do
    path = Path.join([app_root(), rel])

    if File.exists?(path) do
      File.read!(path)
    else
      flunk("Expected file not found: #{path}")
    end
  end

  describe "module file separation" do
    test "VariationalFreeEnergy and ExactInference live in distinct files" do
      vfe_path = Path.join([app_root(), @vfe_path])
      exact_path = Path.join([app_root(), @exact_path])

      assert File.exists?(vfe_path), "missing: #{vfe_path}"
      assert File.exists?(exact_path), "missing: #{exact_path}"
      refute vfe_path == exact_path
    end
  end

  describe "code-level boundary" do
    test "VariationalFreeEnergy source does not reference ExactInference" do
      src = read_file_at(@vfe_path)
      refute src =~ "ExactInference",
             "variational path must not reference the exact-posterior module"
    end

    test "ExpectedFreeEnergy source does not reference ExactInference" do
      src = read_file_at(@efe_path)
      refute src =~ "ExactInference",
             "EFE path must not reference the exact-posterior module"
    end

    test "ExactInference public functions do not accept ActiveInferenceAgent" do
      src = read_file_at(@exact_path)
      # The public @spec lines must not mention ActiveInferenceAgent — exact
      # posteriors are properties of the bundle (generative model), not of
      # any specific recognition density / agent struct.
      refute src =~ "ActiveInferenceAgent",
             "ExactInference must not take agent structs — bundles only"
    end

    # External-review C5 (v2): the q_vs_p boundary was previously asymmetric.
    # The variational path was tested to not reference the audit path, but
    # the audit path could still reference variational machinery if a future
    # refactor added an import. These two refutes close the boundary.
    test "ExactInference does not import VariationalFreeEnergy" do
      src = read_file_at(@exact_path)
      refute src =~ "VariationalFreeEnergy",
             "ExactInference (audit reference path) must not depend on the production VFE module"
    end

    test "ExactInference does not import ExpectedFreeEnergy" do
      src = read_file_at(@exact_path)
      refute src =~ "ExpectedFreeEnergy",
             "ExactInference (audit reference path) must not depend on the production EFE module"
    end
  end

  describe "naming discipline" do
    test "variational path uses 'q' / 'recognition' / 'beliefs' wording" do
      src = read_file_at(@vfe_path)

      assert src =~ ~r/\bq\b/ or src =~ "variational",
             "VFE module should use q/variational naming"
    end

    test "exact path uses 'posterior_exact' / 'log_evidence' wording" do
      src = read_file_at(@exact_path)

      assert src =~ "posterior_exact",
             "ExactInference should expose posterior_exact/3 explicitly"

      assert src =~ "log_evidence",
             "ExactInference should expose log_evidence explicitly"
    end
  end
end
