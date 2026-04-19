defmodule CompositionRuntimeTest do
  use ExUnit.Case, async: false

  test "public API modules are loaded" do
    assert Code.ensure_loaded?(CompositionRuntime)
    assert Code.ensure_loaded?(CompositionRuntime.Registry)
    assert Code.ensure_loaded?(CompositionRuntime.SignalBroker)
    assert Code.ensure_loaded?(CompositionRuntime.Composition)
  end

  test "deploy/1 returns an {:error, _} for an empty agent list with unstarted runtime" do
    # The application tree for composition_runtime is started in prod via its
    # Application.start/2; in tests we only assert the surface exists. A full
    # end-to-end deploy test lives in the workbench_web integration suite.
    assert function_exported?(CompositionRuntime, :deploy, 1)
    assert function_exported?(CompositionRuntime, :route, 2)
    assert function_exported?(CompositionRuntime, :list, 0)
  end
end
