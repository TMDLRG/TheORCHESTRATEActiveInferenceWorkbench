defmodule ActiveInferenceCore.EquationRegistryTest do
  use ExUnit.Case, async: true

  alias ActiveInferenceCore.{Equation, Equations, Model, Models}

  describe "T1 — extraction completeness" do
    test "every equation carries the required ledger fields" do
      required_fields = [
        :id,
        :source_title,
        :chapter,
        :section,
        :equation_number,
        :source_text_equation,
        :normalized_latex,
        :symbols,
        :model_family,
        :model_type,
        :conceptual_role,
        :implementation_role,
        :dependencies,
        :verification_status,
        :verification_notes
      ]

      Enum.each(Equations.all(), fn %Equation{} = eq ->
        Enum.each(required_fields, fn f ->
          refute is_nil(Map.fetch!(eq, f)), "field #{inspect(f)} missing for #{eq.id}"
        end)
      end)
    end

    test "every id is unique" do
      ids = Enum.map(Equations.all(), & &1.id)
      assert length(ids) == length(Enum.uniq(ids))
    end

    test "every dependency id resolves to a real record" do
      all_ids = Enum.map(Equations.all(), & &1.id) |> MapSet.new()

      Enum.each(Equations.all(), fn eq ->
        Enum.each(eq.dependencies, fn dep ->
          assert MapSet.member?(all_ids, dep),
                 "#{eq.id} depends on #{inspect(dep)} but no such equation exists"
        end)
      end)
    end

    test "at least one equation exists per required model type" do
      required = [:general, :discrete, :continuous]
      Enum.each(required, fn t -> assert Equations.by_type(t) != [] end)
    end
  end

  describe "T2 — source fidelity (spot checks)" do
    test "Bayes rule (eq. 2.1) preserves the canonical form" do
      eq = Equations.fetch("eq_2_1_bayes_rule")
      assert eq.source_text_equation =~ "P(x | y)"
      assert eq.source_text_equation =~ "P(x)P(y | x)"
      assert eq.source_text_equation =~ "P(y)"
      assert eq.equation_number == "2.1"
    end

    test "VFE (eq. 2.5) records all three decompositions" do
      eq = Equations.fetch("eq_2_5_variational_free_energy")
      assert eq.source_text_equation =~ "Energy"
      assert eq.source_text_equation =~ "Complexity"
      assert eq.source_text_equation =~ "Divergence"
      assert eq.source_text_equation =~ "Evidence"
    end

    test "EFE (eq. 2.6 / 7.4) exposes epistemic and pragmatic terms" do
      eq = Equations.fetch("eq_7_4_efe_epistemic_pragmatic")
      assert eq.source_text_equation =~ "epistemic"
      assert eq.source_text_equation =~ "pragmatic"
    end

    test "discrete-time state update (4.13 / B.5) matches both chapter and appendix" do
      eq413 = Equations.fetch("eq_4_13_state_belief_update")
      eqB5 = Equations.fetch("eq_B_5_gradient_descent_states")
      assert eq413.verification_status == :verified_against_source_and_appendix
      assert eqB5.verification_status == :verified_against_source_and_appendix
      assert "eq_4_13_state_belief_update" in eqB5.dependencies
    end

    test "policy posterior (4.14 / B.9) matches both chapter and appendix" do
      eq414 = Equations.fetch("eq_4_14_policy_posterior")
      eqB9 = Equations.fetch("eq_B_9_policy_posterior_update")
      assert eq414.source_text_equation =~ "σ(−G − F)"
      assert eqB9.source_text_equation =~ "σ(ln E − F − G)"
    end

    test "continuous-time generative model vs process (8.1 vs 8.2)" do
      eq81 = Equations.fetch("eq_8_1_continuous_generative_model")
      eq82 = Equations.fetch("eq_8_2_continuous_generative_process")
      # 8.1 mentions v (cause), 8.2 mentions u (action)
      assert eq81.source_text_equation =~ "f(x, v)"
      assert eq82.source_text_equation =~ "f(x, u)"
    end
  end

  describe "T3 — taxonomy audit" do
    test "every model family lists at least one grounding equation id" do
      all_eq_ids = Enum.map(Equations.all(), & &1.id) |> MapSet.new()

      Enum.each(Models.all(), fn %Model{} = m ->
        refute m.source_basis == [], "#{m.model_name} lists no source equations"

        Enum.each(m.source_basis, fn id ->
          assert MapSet.member?(all_eq_ids, id),
                 "#{m.model_name} references missing equation #{id}"
        end)
      end)
    end

    test "MVP-primary models exist for discrete and general" do
      primary = Enum.filter(Models.all(), &(&1.mvp_suitability == :mvp_primary))
      assert Enum.any?(primary, &(&1.type == :discrete))
      assert Enum.any?(primary, &(&1.type == :general))
    end
  end
end
