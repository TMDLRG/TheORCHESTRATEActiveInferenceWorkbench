defmodule WorkbenchWeb.SpeechController do
  @moduledoc """
  Reverse-proxy for the ClaudeSpeak HTTP TTS wrapper.  Browsers call
  `POST /speech/speak` with `{text, voice?, rate?}`; we forward to
  `http://127.0.0.1:7712/speak` and stream the `audio/wav` body back.

  Also exposes:
    * `GET /speech/voices`    → list of voices (JSON),
    * `GET /speech/healthz`   → upstream liveness,
    * `GET /speech/narrate/chapter/:num` → narrate a whole chapter (convenience;
      reads the chunked chapter TXT, truncates to 12 000 chars, returns WAV).

  If the upstream is unreachable, the browser's `Narrator` JS hook falls
  back to `SpeechSynthesisUtterance` silently.
  """
  use WorkbenchWeb, :controller

  alias WorkbenchWeb.Book.Chapters

  @upstream_host Application.compile_env(:workbench_web, :voice_http_host, "127.0.0.1")
  @upstream_port Application.compile_env(:workbench_web, :voice_http_port, 7712)
  @timeout_ms 60_000

  def healthz(conn, _params) do
    url = "http://#{@upstream_host}:#{@upstream_port}/healthz"
    forward_json(conn, :get, url, nil)
  end

  def voices(conn, _params) do
    url = "http://#{@upstream_host}:#{@upstream_port}/voices"
    forward_json(conn, :get, url, nil)
  end

  def speak(conn, params) do
    text = Map.get(params, "text", "")
    voice = Map.get(params, "voice")
    rate = Map.get(params, "rate")

    if is_binary(text) and byte_size(text) > 0 do
      body =
        %{text: text}
        |> maybe_put(:voice, voice)
        |> maybe_put(:rate, rate)
        |> Jason.encode!()

      url = "http://#{@upstream_host}:#{@upstream_port}/speak"
      forward_audio(conn, :post, url, body)
    else
      conn |> put_status(400) |> json(%{error: "text required"})
    end
  end

  def narrate_chapter(conn, %{"num" => num}) do
    case Chapters.get(num) do
      nil ->
        conn |> put_status(404) |> json(%{error: "unknown chapter"})

      chapter ->
        path =
          Path.join([
            Application.app_dir(:workbench_web, "priv"),
            "book/chapters",
            if(chapter.num == 0, do: "preface.txt", else: "ch#{pad(chapter.num)}.txt")
          ])

        case File.read(path) do
          {:ok, text} ->
            truncated = String.slice(text, 0, 12_000)
            body = Jason.encode!(%{text: truncated})
            url = "http://#{@upstream_host}:#{@upstream_port}/speak"
            forward_audio(conn, :post, url, body)

          {:error, _} ->
            conn |> put_status(500) |> json(%{error: "chapter text not chunked yet"})
        end
    end
  end

  # -------- internals --------
  # Uses OTP's built-in :httpc (inets) to avoid adding a Finch dep.

  defp ensure_inets do
    _ = Application.ensure_all_started(:inets)
    _ = Application.ensure_all_started(:ssl)
    :ok
  end

  defp forward_json(conn, method, url, body) do
    ensure_inets()
    headers = [{~c"content-type", ~c"application/json"}]

    request =
      case method do
        :get -> {String.to_charlist(url), headers}
        :post -> {String.to_charlist(url), headers, ~c"application/json", body || ""}
      end

    opts = [timeout: @timeout_ms, connect_timeout: 2_000]

    case :httpc.request(method, request, opts, body_format: :binary) do
      {:ok, {{_, status, _}, _resp_headers, resp_body}} ->
        conn
        |> put_resp_content_type("application/json")
        |> send_resp(status, resp_body)

      {:error, err} ->
        conn
        |> put_status(503)
        |> json(%{error: "speech upstream unreachable", detail: inspect(err)})
    end
  end

  defp forward_audio(conn, method, url, body) do
    ensure_inets()
    headers = [{~c"content-type", ~c"application/json"}]

    request =
      case method do
        :get -> {String.to_charlist(url), headers}
        :post -> {String.to_charlist(url), headers, ~c"application/json", body || ""}
      end

    opts = [timeout: @timeout_ms, connect_timeout: 2_000]

    case :httpc.request(method, request, opts, body_format: :binary) do
      {:ok, {{_, 200, _}, resp_headers, audio}} ->
        ctype = find_header(resp_headers, "content-type") || "audio/wav"

        conn
        |> put_resp_content_type(to_string(ctype))
        |> put_resp_header("cache-control", "no-store")
        |> send_resp(200, audio)

      {:ok, {{_, status, _}, _resp_headers, resp_body}} ->
        conn |> put_status(status) |> send_resp(status, resp_body)

      {:error, err} ->
        conn
        |> put_status(503)
        |> json(%{error: "speech upstream unreachable", detail: inspect(err)})
    end
  end

  defp find_header(headers, name) do
    name = String.downcase(name)

    Enum.find_value(headers, fn
      {k, v} when is_list(k) ->
        if String.downcase(List.to_string(k)) == name, do: v

      {k, v} when is_binary(k) ->
        if String.downcase(k) == name, do: v

      _ ->
        nil
    end)
  end

  defp maybe_put(map, _k, nil), do: map
  defp maybe_put(map, k, v), do: Map.put(map, k, v)

  defp pad(n) when n < 10, do: "0#{n}"
  defp pad(n), do: "#{n}"
end
