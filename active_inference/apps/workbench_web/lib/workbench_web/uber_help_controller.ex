defmodule WorkbenchWeb.UberHelpController do
  @moduledoc """
  Embedded Qwen "uber help" assistant.  Accepts a short user message plus
  the current session context (slug + path + optional seed) and returns
  a single non-streaming response from the local Qwen 3.6 llama-server.

  * Reads the dynamic port from `Qwen3.6/.qwen_port` at request time.
  * Falls back to a polite "Qwen is sleeping" if the upstream is offline.
  * Uses OTP's `:httpc` (no extra deps).

  Request:   POST /api/uber-help  {session?, path?, seed?, user_msg}
  Response:  200 {reply, thinking?, latency_ms}
             503 {error: "qwen offline", hint: "..."}
  """
  use WorkbenchWeb, :controller

  alias WorkbenchWeb.Book.{Chapters, Sessions, Glossary}

  @default_port 8090
  @timeout_ms 180_000
  @connect_timeout_ms 5_000
  @max_tokens 600

  # Token budget for in-context RAG. Keep the uber-help system prompt tight —
  # the drawer is for quick answers, not long treatises.  The "Full chat"
  # bridge page handles the longer conversations with the full excerpt.
  @excerpt_budget_chars 2500
  @glossary_budget_chars 800

  def ask(conn, params) do
    user_msg = Map.get(params, "user_msg", "")

    cond do
      not is_binary(user_msg) or byte_size(user_msg) == 0 ->
        conn |> put_status(400) |> json(%{error: "user_msg required"})

      true ->
        path = Map.get(params, "path", "real")
        seed = Map.get(params, "seed", "")
        session_slug = Map.get(params, "session", "")
        chapter_num = parse_int(Map.get(params, "chapter"))

        sys_prompt = build_system_prompt(seed, session_slug, chapter_num, path)

        case port_from_file() do
          nil ->
            qwen_offline(conn)

          port ->
            call_qwen(conn, port, sys_prompt, user_msg)
        end
    end
  end

  defp call_qwen(conn, port, sys_prompt, user_msg) do
    Application.ensure_all_started(:inets)
    Application.ensure_all_started(:ssl)

    url = "http://127.0.0.1:#{port}/v1/chat/completions"

    body =
      Jason.encode!(%{
        model: "Qwen3.6-35B-A3B-Q8_0",
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
          json(conn, %{reply: content, latency_ms: dt, port: port})
        else
          _ -> conn |> put_status(502) |> json(%{error: "qwen malformed response"})
        end

      {:ok, {{_, status, _}, _h, resp}} ->
        conn
        |> put_status(status)
        |> json(%{error: "qwen #{status}", detail: String.slice(resp, 0, 500)})

      {:error, err} ->
        conn
        |> put_status(503)
        |> json(%{
          error: "qwen upstream unreachable",
          detail: inspect(err),
          hint: "./Qwen3.6/scripts/start_qwen.ps1"
        })
    end
  end

  defp qwen_offline(conn) do
    conn
    |> put_status(503)
    |> json(%{
      error: "qwen offline",
      hint:
        "Start Qwen: cd Qwen3.6 && ./scripts/start_qwen.ps1 (Windows) or ./scripts/start_qwen.sh",
      reply:
        "Qwen is currently asleep. Start the local model with the command above, then try again."
    })
  end

  defp port_from_file do
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
      nil -> if qwen_up?(@default_port), do: @default_port, else: nil
      n -> n
    end
  end

  defp qwen_up?(port) do
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

  # Build a rich, on-page-aware system prompt:
  #
  #   1. Base persona + path tone.
  #   2. Chapter tag (num, title, hero concept, part).
  #   3. Session tag (ordinal, title, minutes, concepts, linked labs/workbench).
  #   4. In-context RAG: the literal book excerpt for this session, truncated
  #      to fit a conservative token budget.
  #   5. Path-tier glossary definitions for every concept on the page.
  #   6. Soft anchor to adjacent sessions so "what's next" has direction.
  #   7. Explicit scoping rules (stay on-topic, cite chapter when relevant,
  #      avoid speculation, match path tone).
  defp build_system_prompt(seed, session_slug, chapter_num, path) do
    path_tier = path_tier(path)

    ch = chapter_num && Chapters.get(chapter_num)
    s = if ch, do: Sessions.find(chapter_num, session_slug), else: nil

    base = """
    You are the tutor of an Active Inference masterclass built around the Parr,
    Pezzulo & Friston (2022) MIT Press book. The learner is on the "#{path_label(path)}"
    learning path — match that tone.

    SCOPING RULES
    - Answer using the on-page excerpt below when possible; quote sparingly.
    - Keep replies under 250 words unless the learner asks for depth.
    - When you cite the book, say "(Ch #{(ch && ch.num) || "?"})" inline.
    - For a #{path_tier} reader: #{path_scope(path)}.
    - If the question is off-page, answer briefly and point to the relevant chapter.
    """

    chapter_tag =
      case ch do
        nil ->
          ""

        _ ->
          """

          CHAPTER CONTEXT
          Part: #{Chapters.part_label(ch.part)}
          Chapter #{ch.num} · #{ch.title}
          Hero concept: #{ch.hero}
          Summary: #{ch.blurb}
          """
      end

    session_tag =
      case s do
        nil ->
          ""

        _ ->
          lab_labels =
            s.labs
            |> Enum.map(fn %{slug: sl, beat: b} -> "#{sl} (beat #{b})" end)
            |> Enum.join(", ")

          wb_labels =
            s.workbench
            |> Enum.map(& &1.label)
            |> Enum.join(", ")

          """

          SESSION CONTEXT
          Session #{s.ordinal} of Chapter #{chapter_num} · #{s.title}
          Estimated time: #{s.minutes} minutes
          On-page narration (#{path_tier} tier):
          #{Map.get(s.path_text, String.to_atom(path), Map.get(s.path_text, :real, ""))}
          Linked labs: #{if lab_labels == "", do: "(none)", else: lab_labels}
          Linked Workbench surfaces: #{if wb_labels == "", do: "(none)", else: wb_labels}
          """
      end

    excerpt = if s, do: read_excerpt_block(ch, s), else: ""
    glossary = if s, do: glossary_block(s.concepts, path_tier), else: ""
    neighbours = if s, do: neighbour_block(s), else: ""
    seed_line = if seed != "", do: "\n\nSESSION TUTOR SEED\n#{seed}", else: ""

    base <> chapter_tag <> session_tag <> excerpt <> glossary <> neighbours <> seed_line
  end

  defp read_excerpt_block(nil, _), do: ""
  defp read_excerpt_block(_ch, nil), do: ""

  defp read_excerpt_block(ch, s) do
    path =
      Path.join([
        Application.app_dir(:workbench_web, "priv"),
        "book/sessions",
        "#{ch.slug}__#{s.slug}.txt"
      ])

    case File.read(path) do
      {:ok, text} ->
        clipped = String.slice(text, 0, @excerpt_budget_chars)

        suffix =
          if String.length(text) > @excerpt_budget_chars, do: "…\n[excerpt truncated]", else: ""

        """

        ON-PAGE EXCERPT (verbatim from Chapter #{ch.num}; treat as ground truth):
        ---
        #{clipped}#{suffix}
        ---
        """

      _ ->
        ""
    end
  end

  defp glossary_block([], _), do: ""

  defp glossary_block(concepts, tier) do
    tier_key =
      case tier do
        "kid" -> :kid
        "phd" -> :phd
        _ -> :adult
      end

    {_used, lines} =
      Enum.reduce(concepts, {0, []}, fn k, {used, acc} ->
        case Glossary.get(k) do
          nil ->
            {used, acc}

          e ->
            body = Map.get(e, tier_key) || e.adult
            line = "- #{e.name}: #{body}"
            line_len = String.length(line)

            if used + line_len > @glossary_budget_chars do
              {used, acc}
            else
              {used + line_len, [line | acc]}
            end
        end
      end)

    lines = Enum.reverse(lines)

    if lines == [] do
      ""
    else
      "\n\nGLOSSARY (#{tier} tier, on-page concepts)\n" <> Enum.join(lines, "\n")
    end
  end

  defp neighbour_block(s) do
    prev = Sessions.prev(s)
    next = Sessions.next(s)

    parts =
      []
      |> then(fn acc ->
        if prev, do: ["Prev: Ch #{prev.chapter} · #{prev.title}" | acc], else: acc
      end)
      |> then(fn acc ->
        if next, do: ["Next: Ch #{next.chapter} · #{next.title}" | acc], else: acc
      end)

    if parts == [] do
      ""
    else
      "\n\nADJACENT SESSIONS (for orientation)\n" <> (parts |> Enum.reverse() |> Enum.join("\n"))
    end
  end

  defp path_tier("kid"), do: "kid"
  defp path_tier("derivation"), do: "phd"
  defp path_tier("equation"), do: "adult"
  defp path_tier(_), do: "adult"

  defp path_scope("kid"),
    do:
      "use grade-5 vocabulary, prefer one concrete image per concept, avoid equations unless the learner asks"

  defp path_scope("real"),
    do: "use grade-8 vocabulary with everyday analogies; equations only when they clarify"

  defp path_scope("equation"),
    do: "use Unicode math freely, cite equation numbers, keep derivations tight"

  defp path_scope("derivation"),
    do:
      "full formalism welcome; cite proof sources, flag when a step is heuristic; may assume undergrad analysis"

  defp path_scope(_), do: "use grade-8 vocabulary with everyday analogies"

  defp path_label("kid"), do: "story"
  defp path_label("real"), do: "real-world"
  defp path_label("equation"), do: "equation"
  defp path_label("derivation"), do: "derivation"
  defp path_label(_), do: "real-world"

  defp parse_int(nil), do: nil
  defp parse_int(n) when is_integer(n), do: n

  defp parse_int(s) when is_binary(s) do
    case Integer.parse(s) do
      {n, _} -> n
      :error -> nil
    end
  end
end
