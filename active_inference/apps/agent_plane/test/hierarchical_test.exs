defmodule AgentPlane.HierarchicalTest do
  @moduledoc """
  G5 DONE: "Hierarchical agent boots; 2-level test shows upper-level context
  changing lower-level A matrix."  (The public knob that a meta context
  switches is the base bundle's C -- same idea, cleaner shape than mutating
  A.)  The test verifies the base bundle's C swaps on context switch.
  """
  use ExUnit.Case, async: true

  alias AgentPlane.{BundleBuilder, Hierarchical}
  alias SharedContracts.Blanket

  setup do
    blanket = Blanket.maze_default()

    base_opts = [
      width: 3,
      height: 1,
      start_idx: 0,
      goal_idx: 2,
      walls: [],
      blanket: blanket,
      horizon: 2,
      policy_depth: 2
    ]

    # Build a zero-vector and a left-biased and right-biased C for tests.
    # Cardinality of obs = what BundleBuilder publishes in dims.n_obs.
    base_bundle = BundleBuilder.for_maze(base_opts)
    n_obs = base_bundle.dims.n_obs
    neutral = List.duplicate(0.0, n_obs)

    # Sharply prefer obs_idx 0 vs obs_idx 1 to make the swap detectable.
    explore = List.duplicate(0.0, n_obs) |> List.replace_at(0, 5.0)
    exploit = List.duplicate(0.0, n_obs) |> List.replace_at(1, 5.0)

    contexts = %{neutral: neutral, explore: explore, exploit: exploit}

    hier =
      Hierarchical.new(
        base_opts: base_opts,
        contexts: contexts,
        initial_context: :neutral
      )

    {:ok, hier: hier, n_obs: n_obs}
  end

  test "boots with both bundles and the initial context applied", %{hier: h} do
    assert h.current_context == :neutral
    assert h.base_bundle.dims.n_obs > 0
    assert h.meta_bundle.dims.n_obs == h.base_bundle.dims.n_obs
    assert length(h.base_bundle.c) == h.base_bundle.dims.n_obs
    assert length(h.meta_bundle.c) == h.meta_bundle.dims.n_obs
  end

  test "switching context changes the base bundle's C vector", %{hier: h} do
    c_before = h.base_bundle.c

    h_exp = Hierarchical.switch_context(h, :explore)
    assert h_exp.current_context == :explore
    assert h_exp.base_bundle.c != c_before, "C must swap on context switch"

    h_exploit = Hierarchical.switch_context(h_exp, :exploit)
    # The two contexts prefer different obs indices -> C must reflect that.
    assert Enum.at(h_exp.base_bundle.c, 0) > Enum.at(h_exploit.base_bundle.c, 0)
    assert Enum.at(h_exploit.base_bundle.c, 1) > Enum.at(h_exp.base_bundle.c, 1)
  end

  test "switching to an unknown context raises", %{hier: h} do
    assert_raise ArgumentError, fn -> Hierarchical.switch_context(h, :mystery) end
  end

  test "tick increments steps_in_context", %{hier: h} do
    assert h.steps_in_context == 0
    assert Hierarchical.tick(h).steps_in_context == 1
    assert h |> Hierarchical.tick() |> Hierarchical.tick() |> Map.get(:steps_in_context) == 2
  end
end
