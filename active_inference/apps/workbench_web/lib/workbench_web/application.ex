defmodule WorkbenchWeb.Application do
  @moduledoc false
  use Application

  @impl true
  def start(_type, _args) do
    # Plan §11.5 — bus + event log live in the `world_models` umbrella app
    # (apps/world_models); workbench_web just boots the Phoenix stack.
    children = [
      {Phoenix.PubSub, name: WorkbenchWeb.PubSub},
      WorkbenchWeb.Endpoint,
      {Registry, keys: :unique, name: WorkbenchWeb.Episode.Registry},
      # Keeps LibreChat ACL grants in sync with the seeded workshop catalogue
      # so every user (including freshly-registered ones) sees every agent +
      # prompt group without a manual re-seed.  Set
      # WORKSHOP_GRANTS_WATCHER=false to disable.
      WorkbenchWeb.LibreChatGrantsWatcher
    ]

    opts = [strategy: :one_for_one, name: WorkbenchWeb.Supervisor]
    Supervisor.start_link(children, opts)
  end

  @impl true
  def config_change(changed, _new, removed) do
    WorkbenchWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
