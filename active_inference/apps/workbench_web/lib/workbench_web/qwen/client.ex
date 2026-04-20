defmodule WorkbenchWeb.Qwen.Client do
  @moduledoc """
  Thin httpc wrapper around the local Qwen 3.6 llama-server (OpenAI-compatible
  `/v1/chat/completions`).

  Extracted from `WorkbenchWeb.UberHelpController` so the controller stays a
  40-line shell and so tests can inject a Bypass stub.
  """

  @default_port 8090
  @timeout_ms 180_000
  @connect_timeout_ms 5_000
  @max_tokens 600
  @model "Qwen3.6-35B-A3B-Q8_0"

  @type reply :: %{reply: String.t(), latency_ms: non_neg_integer(), port: pos_integer()}

  @doc """
  Send a single non-streaming chat completion. Returns `{:ok, reply}` or a
  tagged error. Caller maps the error to an HTTP status.
  """
  @spec chat(String.t(), String.t()) ::
          {:ok, reply()}
          | {:error, :offline}
          | {:error, :unreachable | :malformed | {:upstream, pos_integer(), String.t()}}
  def chat(sys_prompt, user_msg) when is_binary(sys_prompt) and is_binary(user_msg) do
    case port() do
      nil -> {:error, :offline}
      port -> call(port, sys_prompt, user_msg)
    end
  end

  @doc """
  Standard offline payload: a 503 body that the drawer renders as a friendly
  "Qwen is currently asleep" note with a copy-pasteable start command.
  """
  @spec offline_response() :: map()
  def offline_response do
    %{
      error: "qwen offline",
      hint: "Start Qwen: cd Qwen3.6 && ./scripts/start_qwen.ps1 (Windows) or ./scripts/start_qwen.sh",
      reply:
        "Qwen is currently asleep. Start the local model with the command above, then try again."
    }
  end

  @doc "Resolve the current Qwen port by reading `.qwen_port`, or nil."
  @spec port() :: pos_integer() | nil
  def port do
    candidates =
      [
        ".qwen_port",
        "Qwen3.6/.qwen_port",
        "../Qwen3.6/.qwen_port",
        "../../Qwen3.6/.qwen_port",
        "../../../Qwen3.6/.qwen_port",
        "../../../../Qwen3.6/.qwen_port",
        "../../../../../Qwen3.6/.qwen_port"
      ]

    candidates
    |> Enum.map(&Path.expand/1)
    |> Enum.find_value(fn p ->
      case File.read(p) do
        {:ok, v} ->
          v
          |> String.trim()
          |> Integer.parse()
          |> case do
            {n, _} -> n
            :error -> nil
          end

        _ ->
          nil
      end
    end)
    |> case do
      nil -> if up?(@default_port), do: @default_port, else: nil
      n -> n
    end
  end

  @doc "Health check: GET /v1/models on the given port."
  @spec up?(pos_integer()) :: boolean()
  def up?(port) when is_integer(port) do
    Application.ensure_all_started(:inets)
    Application.ensure_all_started(:ssl)
    url = "http://127.0.0.1:#{port}/v1/models" |> String.to_charlist()

    case :httpc.request(:get, {url, []}, [connect_timeout: 500, timeout: 1_500],
           body_format: :binary
         ) do
      {:ok, {{_, 200, _}, _, _}} -> true
      _ -> false
    end
  end

  # --- private -------------------------------------------------------------

  defp call(port, sys_prompt, user_msg) do
    Application.ensure_all_started(:inets)
    Application.ensure_all_started(:ssl)

    url = "http://127.0.0.1:#{port}/v1/chat/completions"

    body =
      Jason.encode!(%{
        model: @model,
        messages: [
          %{role: "system", content: sys_prompt},
          %{role: "user", content: user_msg}
        ],
        max_tokens: @max_tokens,
        temperature: 0.6,
        chat_template_kwargs: %{enable_thinking: false}
      })

    headers = [{~c"content-type", ~c"application/json"}]
    request = {String.to_charlist(url), headers, ~c"application/json", body}
    opts = [timeout: @timeout_ms, connect_timeout: @connect_timeout_ms]
    t0 = System.monotonic_time(:millisecond)

    case :httpc.request(:post, request, opts, body_format: :binary) do
      {:ok, {{_, 200, _}, _h, resp}} ->
        with {:ok, decoded} <- Jason.decode(resp),
             %{"choices" => [first | _]} <- decoded,
             %{"message" => %{"content" => content}} <- first do
          dt = System.monotonic_time(:millisecond) - t0
          {:ok, %{reply: content, latency_ms: dt, port: port}}
        else
          _ -> {:error, :malformed}
        end

      {:ok, {{_, status, _}, _h, resp}} ->
        {:error, {:upstream, status, String.slice(resp, 0, 500)}}

      {:error, _err} ->
        {:error, :unreachable}
    end
  end
end
