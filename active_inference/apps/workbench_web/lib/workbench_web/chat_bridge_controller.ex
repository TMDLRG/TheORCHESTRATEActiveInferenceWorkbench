defmodule WorkbenchWeb.ChatBridgeController do
  @moduledoc """
  Chat bridge — when a learner clicks **Full chat about this chapter**
  (or session), we route through `/learn/chat-bridge/chapter/:num` or
  `/learn/chat-bridge/session/:num/:slug`.  This tiny controller
  renders a page that:

    1. Shows a preview of the chapter/session context (excerpt +
       glossary + metadata) so the learner sees what's being sent.
    2. Copies a pre-formatted starter message to the clipboard.
    3. Pops LibreChat open in a new tab.

  Result: even without deep LibreChat API integration (which requires
  user auth + RAG provisioning), the learner's first message to LibreChat
  is rich with on-page context.  The LLM sees the book excerpt and
  session scaffolding verbatim, so the chat experience stays "on the
  same page" as the session.

  If/when we wire a proper LibreChat preset/agent flow, the bridge
  becomes a redirect to the provisioned agent URL.
  """
  use WorkbenchWeb, :controller

  alias WorkbenchWeb.Book.{Chapters, Sessions, Glossary}
  alias WorkbenchWeb.LibreChatAgents

  def chapter(conn, %{"num" => num} = params) do
    case Chapters.get(num) do
      nil ->
        conn |> put_status(404) |> text("Unknown chapter")

      ch ->
        starter = chapter_starter(ch)
        agent_slug = pick_agent_slug(params, ch, nil)

        render_bridge(conn,
          title: ch.title,
          starter: starter,
          chapter: ch,
          session: nil,
          agent_slug: agent_slug
        )
    end
  end

  def session(conn, %{"num" => num, "slug" => slug} = params) do
    with ch when not is_nil(ch) <- Chapters.get(num),
         s when not is_nil(s) <- Sessions.find(ch.num, slug) do
      starter = session_starter(ch, s)
      agent_slug = pick_agent_slug(params, ch, s)

      render_bridge(conn,
        title: s.title,
        starter: starter,
        chapter: ch,
        session: s,
        agent_slug: agent_slug
      )
    else
      _ -> conn |> put_status(404) |> text("Unknown session")
    end
  end

  # Choose the agent slug for this bridge.  Priority:
  #   1. ?agent=<slug> in the URL (Phoenix link explicitly chose one).
  #   2. If the session links to exactly one lab, the matching lab coach.
  #   3. Path-default tutor (currently always :real -> aif-tutor-real).
  defp pick_agent_slug(params, _ch, s) do
    case Map.get(params, "agent") do
      slug when is_binary(slug) and slug != "" ->
        slug

      _ ->
        cond do
          is_map(s) and is_list(s.labs) and length(s.labs) == 1 ->
            [%{slug: lab}] = s.labs
            LibreChatAgents.agent_for_lab(lab) || LibreChatAgents.default_for_path(:real)

          true ->
            LibreChatAgents.default_for_path(:real)
        end
    end
  end

  defp render_bridge(conn, opts) do
    title = Keyword.fetch!(opts, :title)
    starter = Keyword.fetch!(opts, :starter)
    ch = Keyword.fetch!(opts, :chapter)
    s = Keyword.fetch!(opts, :session)
    agent_slug = Keyword.get(opts, :agent_slug)
    librechat_url = WorkbenchWeb.ChatLinks.home()

    # LibreChat `?prompt=` URL param is the supported way to auto-fill the
    # input field (see client/src/hooks/Input/useQueryParams.ts, v0.8.5-rc1).
    # LibreChat also has a max URL length (typically ~16 KB works); we clip the
    # prompt to 12 000 chars to stay safely under it.
    prompt_capped = String.slice(starter, 0, 12_000)
    encoded_prompt = URI.encode_www_form(prompt_capped)

    agent_id = LibreChatAgents.get(agent_slug)

    agent_qs =
      case agent_id do
        nil -> ""
        id -> "&agent_id=" <> URI.encode_www_form(id) <> "&endpoint=agents"
      end

    librechat_prompt_url = "#{librechat_url}/c/new?prompt=#{encoded_prompt}" <> agent_qs
    # Escape the starter for embedding in the textarea.
    escaped_starter = Phoenix.HTML.html_escape(starter) |> Phoenix.HTML.safe_to_string()

    body = """
    <!DOCTYPE html>
    <html lang="en"><head>
      <meta charset="utf-8"/>
      <title>#{title}</title>
      <link rel="stylesheet" href="/assets/suite-tokens.css"/>
      <style>
        body { background: #0b1020; color: #e8ecf1; font-family: ui-monospace, Menlo, monospace;
          margin: 0; padding: 32px 20px; }
        .wrap { max-width: 860px; margin: 0 auto; }
        h1 { color: #d8b56c; font-size: 22px; margin-bottom: 8px; }
        .sub { color: #9cb0d6; font-size: 13px; margin-bottom: 20px; }
        .card { background: #121a33; border: 1px solid #263257; border-radius: 8px;
          padding: 16px; margin-bottom: 16px; }
        textarea { width: 100%; height: 260px; background: #0a1226; color: #e8ecf1;
          border: 1px solid #263257; border-radius: 6px; padding: 12px;
          font-family: ui-monospace, Menlo, monospace; font-size: 12px; line-height: 1.5; resize: vertical; }
        .btns { display: flex; gap: 10px; flex-wrap: wrap; margin-top: 12px; }
        .btn { background: #1d4ed8; color: #fff; border: none; border-radius: 6px;
          padding: 10px 16px; font-weight: 700; cursor: pointer; font-family: inherit;
          text-decoration: none; display: inline-block; }
        .btn.primary { background: #b3863a; color: #1b1410; }
        .btn.secondary { background: transparent; border: 1px solid #9cb0d6; color: #e8ecf1; }
        .hint { font-size: 12px; color: #9cb0d6; margin-top: 8px; }
        .ok { color: #86efac; font-weight: 700; }
      </style>
    </head><body><div class="wrap">
      <a href="/learn" style="color:#7dd3fc;font-size:12px;">← back to Learn</a>
      <h1>💬 Full chat · #{title}</h1>
      <p class="sub">
        #{bridge_sub(ch, s)}
        #{agent_badge(agent_slug, agent_id)}
      </p>

      <div class="card">
        <strong style="color:#b1e4ff;">LibreChat starter — opens pre-loaded with this page's context</strong>
        <p class="sub">
          The button below opens LibreChat in a new tab with the starter message already
          typed into the input box. The LLM sees the on-page excerpt, glossary, and session
          metadata verbatim. (Auto-submit is OFF by default so you can review and edit before sending.)
        </p>
        <textarea id="starter" readonly>#{escaped_starter}</textarea>
        <div class="btns">
          <a
            id="open-chat"
            class="btn primary"
            href="#{librechat_prompt_url}"
            target="_blank"
            rel="noopener noreferrer"
          >
            💬 Open LibreChat with this context →
          </a>
          <a
            id="open-chat-submit"
            class="btn"
            href="#{librechat_prompt_url}&submit=true"
            target="_blank"
            rel="noopener noreferrer"
            title="Opens AND auto-submits — use when you want an immediate answer."
          >
            💬 Open + auto-submit
          </a>
          <button class="btn secondary" id="copy-only">📋 Copy starter only</button>
          <a class="btn secondary" href="#{librechat_url}" target="_blank" rel="noopener noreferrer">LibreChat home (no context)</a>
        </div>
        <div class="hint" id="status">
          Tip: in LibreChat pick “Qwen 3.6 · Direct” from the endpoint menu for quick answers, “Reasoning”
          for deep derivations. The starter is #{byte_size(prompt_capped)} chars; LibreChat tolerates up to ~16 KB.
        </div>
      </div>
    </div>

    <script>
      const starter = document.getElementById('starter');
      const status = document.getElementById('status');
      document.getElementById('copy-only').addEventListener('click', async () => {
        try { await navigator.clipboard.writeText(starter.value); status.innerHTML = '<span class="ok">✓ Copied.</span> Paste into LibreChat\\'s first message.'; }
        catch (_) { starter.select(); document.execCommand('copy'); status.innerHTML = '<span class="ok">✓ Copied (fallback).</span>'; }
      });
    </script></body></html>
    """

    conn
    |> put_resp_content_type("text/html")
    |> send_resp(200, body)
  end

  defp bridge_sub(ch, nil),
    do:
      "Chapter #{ch.num} · #{ch.title}. #{length(ch.podcasts)} podcasts · #{length(ch.figures)} figures."

  defp bridge_sub(ch, s) do
    "Chapter #{ch.num} · #{ch.title} → Session #{s.ordinal} · #{s.title} (#{s.minutes} min)."
  end

  defp agent_badge(slug, nil) when is_binary(slug),
    do:
      "<br/><span style=\"color:#fbbf24;\">⚠ agent <code>#{slug}</code> not yet seeded — chat opens with prompt only.</span>"

  defp agent_badge(slug, _id) when is_binary(slug),
    do:
      "<br/><span style=\"color:#86efac;\">🎓 agent <code>#{slug}</code> pre-armed (voice tool + RAG attached)</span>"

  defp agent_badge(_, _), do: ""

  # ----- Starter builders -----

  defp chapter_starter(ch) do
    text = chapter_excerpt(ch)

    """
    #{orchestrate_preamble()}

    You are tutoring me on the Parr/Pezzulo/Friston (2022) Active Inference textbook — Chapter #{ch.num}: #{ch.title}.

    CHAPTER HERO CONCEPT:
    #{ch.hero}

    WHAT THIS CHAPTER COVERS:
    #{ch.blurb}

    ===== ON-PAGE BOOK EXCERPT =====
    #{String.slice(text, 0, 6000)}
    ===== END EXCERPT =====

    Treat the excerpt above as ground truth. Answer my questions in that context; quote sparingly, cite section numbers when useful.

    Start by asking me what I'd most like to explore in this chapter, then tailor your answer.
    """
  end

  defp session_starter(ch, s) do
    excerpt = session_excerpt(ch, s)
    concepts = glossary_lines(s.concepts)

    labs =
      s.labs
      |> Enum.map(fn %{slug: sl, beat: b} -> "- #{sl} (beat #{b})" end)
      |> Enum.join("\n")

    wb =
      s.workbench
      |> Enum.map(fn %{route: r, label: l} -> "- #{l}: #{r}" end)
      |> Enum.join("\n")

    narration = Map.get(s.path_text, :real, "")

    """
    #{orchestrate_preamble()}

    You are tutoring me on the Parr/Pezzulo/Friston (2022) Active Inference textbook.
    I am on Chapter #{ch.num} (#{ch.title}), Session #{s.ordinal}: "#{s.title}" (#{s.minutes} minutes).

    SESSION HERO (real-world narration):
    #{narration}

    GLOSSARY FOR THIS SESSION:
    #{concepts}

    LINKED HANDS-ON LABS:
    #{if labs == "", do: "(none)", else: labs}

    LINKED WORKBENCH SURFACES:
    #{if wb == "", do: "(none)", else: wb}

    ===== ON-PAGE BOOK EXCERPT (verbatim, treat as ground truth) =====
    #{String.slice(excerpt, 0, 5000)}
    ===== END EXCERPT =====

    Answer my questions using the excerpt above; cite equation numbers (e.g. Eq. 4.14) when relevant. Keep explanations tight unless I ask for depth.

    Begin with a single clarifying question so you can tailor your answer.
    """
  end

  # E4 -- prepend the ORCHESTRATE Core Preamble to every chat-bridge starter
  # prompt so the LLM inherits the O-R-C discipline even when the learner
  # pastes the starter into a fresh chat (outside the seeded agents).
  # Mirrors the preamble in `tools/librechat_seed/agents.yaml`.
  defp orchestrate_preamble do
    "[ORCHESTRATE discipline (Polzin): lead every reply with a one-line " <>
      "Objective + your Role + the Context you use (chapter/lab/equation). " <>
      "Vague ask -> one clarifying question first.]"
  end

  defp chapter_excerpt(ch) do
    path =
      Path.join([
        Application.app_dir(:workbench_web, "priv"),
        "book/chapters",
        if(ch.num == 0, do: "preface.txt", else: "ch#{pad2(ch.num)}.txt")
      ])

    case File.read(path) do
      {:ok, text} ->
        text

      _ ->
        "(Chapter text not yet chunked.  Run `mix workbench_web.chunk_book` from the umbrella root.)"
    end
  end

  defp session_excerpt(ch, s) do
    path =
      Path.join([
        Application.app_dir(:workbench_web, "priv"),
        "book/sessions",
        "#{ch.slug}__#{s.slug}.txt"
      ])

    case File.read(path) do
      {:ok, text} -> text
      _ -> "(Session excerpt not yet chunked.)"
    end
  end

  defp glossary_lines([]), do: "(none)"

  defp glossary_lines(concepts) do
    concepts
    |> Enum.map(fn k ->
      case Glossary.get(k) do
        nil -> nil
        e -> "- #{e.name}: #{e.adult}"
      end
    end)
    |> Enum.reject(&is_nil/1)
    |> Enum.join("\n")
    |> case do
      "" -> "(none)"
      s -> s
    end
  end

  defp pad2(n) when n < 10, do: "0#{n}"
  defp pad2(n), do: "#{n}"
end
