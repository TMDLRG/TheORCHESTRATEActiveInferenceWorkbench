defmodule WorkbenchWeb.StudioController do
  @moduledoc """
  Direct HTTP entry points for Studio -- bypasses LiveView event wiring
  for one-shot "Run this recipe in Studio" links from the cookbook.

  The LV (`StudioLive.New`) remains the interactive picker for the
  Attach / Spec / Recipe flows.  This controller is the cookbook-direct
  shortcut: GET `/studio/run_recipe?recipe=<slug>&world=<id>` spawns a
  tracked agent and attaches it to the world, redirecting to the live
  run page.
  """
  use WorkbenchWeb, :controller

  require Logger

  alias AgentPlane.{Instance, Runtime}
  alias WorkbenchWeb.{Cookbook.Loader, Episode, SpecCompiler}
  alias WorldModels.AgentRegistry
  alias WorldPlane.{Maze, Worlds}

  def run_recipe(conn, %{"recipe" => slug} = params) do
    world_id =
      case params["world"] do
        w when is_binary(w) -> String.to_existing_atom(w)
        _ -> :tiny_open_goal
      end

    with spec_id when is_binary(spec_id) <- Loader.spec_id_for(slug),
         {:ok, spec} <- AgentRegistry.fetch_spec(spec_id),
         %Maze{} = maze <- Worlds.fetch(world_id),
         blanket = SharedContracts.Blanket.maze_default(),
         {:ok, bundle, _agent_opts} <- SpecCompiler.compile(spec, maze, blanket: blanket),
         goal_idx = bundle.dims.n_states - 1,
         agent_id = rand_agent_id(),
         {:ok, %Instance{}, _pid} <-
           Runtime.start_tracked_agent(
             %{
               agent_id: agent_id,
               spec_id: spec_id,
               bundle: bundle,
               blanket: bundle_blanket(bundle),
               goal_idx: goal_idx
             },
             source: :cookbook,
             recipe_slug: slug,
             name: "cookbook: #{slug}"
           ),
         {:ok, _ep_pid, session_id} <-
           Episode.attach(
             agent_id: agent_id,
             world_id: world_id,
             max_steps: 36
           ) do
      redirect(conn, to: ~p"/studio/run/#{session_id}")
    else
      {:error, reason} ->
        Logger.warning("[studio.run_recipe] error: #{inspect(reason)}")

        conn
        |> put_flash(:error, "Could not start Studio run: #{inspect(reason)}")
        |> redirect(to: ~p"/cookbook/#{slug}")

      nil ->
        conn
        |> put_flash(:error, "Unknown world or spec for recipe #{slug}.")
        |> redirect(to: ~p"/cookbook/#{slug}")

      other ->
        Logger.warning("[studio.run_recipe] fallthrough: #{inspect(other)}")

        conn
        |> put_flash(:error, "Unexpected error starting run.")
        |> redirect(to: ~p"/cookbook/#{slug}")
    end
  end

  defp bundle_blanket(bundle) do
    Map.get(bundle, :blanket) || SharedContracts.Blanket.maze_default()
  end

  defp rand_agent_id do
    "agent-cookbook-" <> (:crypto.strong_rand_bytes(6) |> Base.url_encode64(padding: false))
  end
end
