defmodule WorkbenchWeb.UberHelpController do
  @moduledoc """
  Embedded Qwen "uber help" tutor endpoint.

  Thin shell — the real work lives in:

    * `WorkbenchWeb.Qwen.PageContext`  — params map → per-page context packet
    * `WorkbenchWeb.Qwen.SystemPrompt` — packet → Qwen system prompt
    * `WorkbenchWeb.Qwen.Client`       — httpc call to the local Qwen server
    * `WorkbenchWeb.Qwen.EpisodeSnap`  — live labs/studio snapshot

  Request:   POST /api/uber-help  {user_msg, page_type?, page_key?, route?,
                                   page_title?, path?, seed?,
                                   chapter?, session?, session_id?, recipe?}
  Response:  200 {reply, latency_ms, port}
             400 {error: "user_msg required"}
             502 {error: "qwen malformed response"}
             503 {error: "qwen offline" | "qwen upstream unreachable", hint: "..."}
  """
  use WorkbenchWeb, :controller

  alias WorkbenchWeb.Qwen.{PageContext, SystemPrompt, Client}

  def ask(conn, params) do
    user_msg = Map.get(params, "user_msg", "")

    if not is_binary(user_msg) or byte_size(user_msg) == 0 do
      conn |> put_status(400) |> json(%{error: "user_msg required"})
    else
      packet = PageContext.build(params)
      sys_prompt = SystemPrompt.render(packet)

      case Client.chat(sys_prompt, user_msg) do
        {:ok, reply} ->
          json(conn, reply)

        {:error, :offline} ->
          conn |> put_status(503) |> json(Client.offline_response())

        {:error, :unreachable} ->
          conn
          |> put_status(503)
          |> json(%{
            error: "qwen upstream unreachable",
            hint: "./Qwen3.6/scripts/start_qwen.ps1"
          })

        {:error, :malformed} ->
          conn |> put_status(502) |> json(%{error: "qwen malformed response"})

        {:error, {:upstream, status, detail}} ->
          conn |> put_status(status) |> json(%{error: "qwen #{status}", detail: detail})
      end
    end
  end
end
