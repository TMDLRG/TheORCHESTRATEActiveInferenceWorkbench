defmodule WorkbenchWeb.Qwen.Hook do
  @moduledoc """
  LiveView `on_mount` that keeps the Qwen drawer page-aware on every route.

  Attached once in `WorkbenchWeb.live_view/0`; no per-LV wiring required
  (other than the 1–3 `assign(:qwen_page_type, ...)` lines each LV sets in
  its `mount/3` or `handle_params/3`).

  On every `handle_params`, this module pushes a `qwen:page` event to the
  client carrying the current `page_type`, `page_key`, `page_title`, `route`,
  learning `path`, optional session-scoped `seed`, and the per-page-type
  `preset_chips`. The `QwenDrawer` JS hook writes those into `dataset` and
  re-renders the chip row, so the drawer always reflects the LV the learner
  is currently on — even across `live_patch`.
  """

  import Phoenix.LiveView
  import Phoenix.Component, only: [assign_new: 3]

  alias WorkbenchWeb.Qwen.{PageContext, Presets}

  @doc "on_mount entry — default fallback assigns + handle_params hook."
  def on_mount(:default, _params, _session, socket) do
    socket =
      socket
      |> assign_new(:qwen_page_type, fn -> :unknown end)
      |> assign_new(:qwen_page_key, fn -> nil end)
      |> assign_new(:qwen_page_title, fn -> nil end)
      |> assign_new(:qwen_seed, fn -> nil end)
      |> assign_new(:learning_path, fn -> "real" end)

    {:cont, attach_hook(socket, :qwen_page_push, :handle_params, &push_page/3)}
  end

  # ----- handle_params hook -----------------------------------------------

  defp push_page(_params, uri, socket) do
    route =
      case URI.parse(uri || "") do
        %URI{path: p} when is_binary(p) -> p
        _ -> ""
      end

    page_type = socket.assigns[:qwen_page_type] || :unknown
    page_key = socket.assigns[:qwen_page_key]

    page_title =
      socket.assigns[:qwen_page_title] ||
        socket.assigns[:page_title]

    path = socket.assigns[:learning_path] || "real"
    seed = socket.assigns[:qwen_seed]

    pseudo_packet = %{
      page_type: page_type,
      page_key: page_key,
      route: route,
      page_title: page_title,
      path: to_string(path),
      path_tier: PageContext.path_tier(to_string(path))
    }

    chips = Presets.chips_for(pseudo_packet)

    payload = %{
      page_type: Atom.to_string(page_type),
      page_key: page_key,
      route: route,
      page_title: page_title,
      path: to_string(path),
      seed: seed,
      chips: chips
    }

    {:cont, push_event(socket, "qwen:page", payload)}
  end
end
