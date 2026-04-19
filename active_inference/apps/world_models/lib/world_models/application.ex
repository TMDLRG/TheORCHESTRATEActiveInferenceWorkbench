defmodule WorldModels.Application do
  @moduledoc """
  Plan §11.5 — supervision for the bus + Mnesia-backed event log.

  Runs in dev/prod; tests (via `WorldModels.MnesiaCase`) take over the Mnesia
  lifecycle and opt out via `config :world_models, :auto_start_event_log, false`.
  """
  use Application

  @impl true
  def start(_type, _args) do
    if Application.get_env(:world_models, :auto_start_event_log, true) do
      :ok = WorldModels.EventLog.Setup.ensure_schema!()
    end

    children =
      if Application.get_env(:world_models, :auto_start_event_log, true) do
        [
          {Phoenix.PubSub, name: WorldModels.Bus},
          WorldModels.EventLog.Janitor,
          # Lego-uplift Phase C — seed the five prebuilt example specs on
          # every boot. Idempotent (Mnesia write overwrites on same id) so
          # safe to re-run. Seeding happens via a transient Task so it
          # doesn't block or get restarted.
          %{
            id: WorldModels.Seeds.Examples,
            start: {Task, :start_link, [fn -> WorldModels.Seeds.Examples.seed_all!() end]},
            restart: :transient,
            type: :worker
          }
        ]
      else
        []
      end

    Supervisor.start_link(children, strategy: :one_for_one, name: WorldModels.AppSup)
  end
end
