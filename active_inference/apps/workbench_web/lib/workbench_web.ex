defmodule WorkbenchWeb do
  @moduledoc """
  Entry point for the UI layer. Provides `controller/0`, `live_view/0`,
  `live_component/0`, and `router/0` helpers in the standard Phoenix style.
  """

  def static_paths, do: ~w(assets fonts images favicon.ico robots.txt learninglabs book)

  def router do
    quote do
      use Phoenix.Router, helpers: false

      import Plug.Conn
      import Phoenix.Controller
      import Phoenix.LiveView.Router
    end
  end

  def controller do
    quote do
      use Phoenix.Controller,
        formats: [:html, :json],
        layouts: [html: WorkbenchWeb.Layouts]

      import Plug.Conn

      unquote(verified_routes())
    end
  end

  def live_view do
    quote do
      use Phoenix.LiveView, layout: {WorkbenchWeb.Layouts, :app}

      # Keep the Qwen drawer page-aware on every route. See
      # WorkbenchWeb.Qwen.Hook for the event + assigns contract.
      on_mount WorkbenchWeb.Qwen.Hook

      unquote(html_helpers())
    end
  end

  def live_component do
    quote do
      use Phoenix.LiveComponent
      unquote(html_helpers())
    end
  end

  def html do
    quote do
      use Phoenix.Component
      import Phoenix.Controller, only: [get_csrf_token: 0, view_module: 1, view_template: 1]
      unquote(html_helpers())
    end
  end

  defp html_helpers do
    quote do
      import Phoenix.HTML
      import WorkbenchWeb.CoreComponents
      alias Phoenix.LiveView.JS
      unquote(verified_routes())
    end
  end

  def verified_routes do
    quote do
      use Phoenix.VerifiedRoutes,
        endpoint: WorkbenchWeb.Endpoint,
        router: WorkbenchWeb.Router,
        statics: WorkbenchWeb.static_paths()
    end
  end

  defmacro __using__(which) when is_atom(which) do
    apply(__MODULE__, which, [])
  end
end
