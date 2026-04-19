defmodule AgentPlane.EquationMapTest do
  @moduledoc """
  Plan §8.4 — registry linking DiscreteTime operations to equation IDs.
  Closes GAP-R1 insofar as Glass Engine needs an authoritative mapping
  from "which function ran" → "which book equation it implements".
  """

  use ExUnit.Case, async: true

  alias ActiveInferenceCore.{DiscreteTime, Equations}
  alias AgentPlane.EquationMap

  describe "T1: lookup by {module, fn, arity}" do
    test "policy_posterior → eq_4_14_policy_posterior" do
      assert EquationMap.lookup(DiscreteTime, :policy_posterior, 3) ==
               "eq_4_14_policy_posterior"
    end

    test "update_state_beliefs → eq_4_13_state_belief_update" do
      assert EquationMap.lookup(DiscreteTime, :update_state_beliefs, 8) ==
               "eq_4_13_state_belief_update"
    end

    test "expected_free_energy → eq_4_10_efe_linear_algebra" do
      assert EquationMap.lookup(DiscreteTime, :expected_free_energy, 4) ==
               "eq_4_10_efe_linear_algebra"
    end

    test "unknown function returns nil" do
      assert EquationMap.lookup(DiscreteTime, :not_a_real_fn, 99) == nil
    end
  end

  describe "T2: every mapped equation resolves in the registry" do
    test "EquationMap.all values are real equation IDs" do
      mapped_ids = EquationMap.all() |> Map.values() |> Enum.uniq()

      for id <- mapped_ids do
        assert %ActiveInferenceCore.Equation{} = Equations.fetch(id),
               "EquationMap references #{id} which is not in the equation registry"
      end
    end

    test "every public DiscreteTime function has a mapping" do
      # List public functions from the DiscreteTime module, excluding
      # protocol and helper fns that aren't meant to be equation-grounded.
      expected =
        [
          {:predict_obs, 2},
          {:update_state_beliefs, 8},
          {:sweep_state_beliefs, 7},
          {:variational_free_energy, 6},
          {:expected_free_energy, 4},
          {:policy_posterior, 3},
          {:choose_action, 4},
          {:marginal_over_policies, 3},
          {:fresh_beliefs, 1},
          {:rollout_forward, 4}
        ]

      for {fn_name, arity} <- expected do
        assert is_binary(EquationMap.lookup(DiscreteTime, fn_name, arity)),
               "no equation mapping for DiscreteTime.#{fn_name}/#{arity}"
      end
    end
  end
end
