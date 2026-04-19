defmodule WorkbenchWeb.ChatLinks do
  @moduledoc """
  Resolves URLs to the LibreChat instance.  Chat links open in a new tab
  and point directly at `http://<host>:3080` so LibreChat's SPA (which
  hard-codes `<base href=\"/\">`) can load its own assets cleanly.

  The in-page reverse-proxy at `/chat/*` is retained as a health-check
  and fallback; it is not the primary way a learner reaches LibreChat.
  """

  @default_host "http://localhost:3080"

  def base do
    Application.get_env(:workbench_web, :librechat_url, @default_host)
  end

  @doc "Home URL — opens LibreChat landing (new tab)."
  def home, do: base()

  @doc """
  URL for a chapter-scoped conversation.

  Points at the Phoenix chat-bridge page which (a) shows the learner the
  on-page excerpt + glossary, (b) copies a rich starter prompt to the
  clipboard, (c) opens LibreChat in a new tab.  The starter prompt
  contains the literal book excerpt for this chapter so the LLM sees the
  same text the learner is looking at.
  """
  def chapter_url(num) when is_integer(num) do
    "/learn/chat-bridge/chapter/" <> Integer.to_string(num)
  end

  @doc """
  URL for a session-scoped conversation.

  Optional opts:
    * `:agent` — explicit agent slug (e.g. `aif-lab-bayes`).  Overrides the
      path-default tutor.
    * `:path` — learner path atom (`:real` default).  Used when no agent is
      given to pick the matching tutor.
  """
  def session_url(chapter_num, slug, opts \\ [])
      when is_integer(chapter_num) and is_binary(slug) do
    base = "/learn/chat-bridge/session/" <> Integer.to_string(chapter_num) <> "/" <> slug

    case Keyword.get(opts, :agent) do
      nil -> base
      agent_slug when is_binary(agent_slug) -> base <> "?agent=" <> agent_slug
    end
  end

  @doc "Same as `chapter_url/1` but accepts an `:agent` slug option."
  def chapter_url(num, opts) when is_integer(num) and is_list(opts) do
    base = chapter_url(num)

    case Keyword.get(opts, :agent) do
      nil -> base
      agent_slug when is_binary(agent_slug) -> base <> "?agent=" <> agent_slug
    end
  end
end
