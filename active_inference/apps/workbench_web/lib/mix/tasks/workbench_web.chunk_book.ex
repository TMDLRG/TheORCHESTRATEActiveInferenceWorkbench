defmodule Mix.Tasks.WorkbenchWeb.ChunkBook do
  @moduledoc """
  Slice the root `book_9780262369978 (1).txt` into per-chapter text files
  under `priv/book/chapters/ch{NN}.txt` (01..10, plus `preface.txt`) and
  per-session excerpts under `priv/book/sessions/{chapter_slug}__{session_slug}.txt`.

  These files are consumed by:
    * the session page (Read-Mode excerpt),
    * the ClaudeSpeak narrator (full-chapter read-aloud),
    * the LibreChat per-chapter RAG preset (file uploads),
    * the uber-help context injection for Qwen.

  Idempotent. Source lives one level above the umbrella:

      WorldModels/book_9780262369978 (1).txt
      WorldModels/active_inference/apps/workbench_web/priv/book/chapters/ch04.txt
  """
  @shortdoc "Slice the book TXT into per-chapter + per-session files"

  use Mix.Task

  @impl true
  def run(_args) do
    # Resolve repo root from current working directory. Task is run from
    # either the umbrella (WorldModels/active_inference) or the app dir.
    cwd = File.cwd!()

    repo_root =
      cond do
        File.exists?(Path.join(cwd, "book_9780262369978 (1).txt")) ->
          cwd

        File.exists?(Path.join(cwd, "../book_9780262369978 (1).txt")) ->
          Path.expand("..", cwd)

        File.exists?(Path.join(cwd, "../../book_9780262369978 (1).txt")) ->
          Path.expand("../..", cwd)

        File.exists?(Path.join(cwd, "../../../book_9780262369978 (1).txt")) ->
          Path.expand("../../..", cwd)

        true ->
          nil
      end

    src =
      if repo_root do
        candidates = ["book_9780262369978 (1).txt", "book_9780262369978.txt"]

        Enum.find_value(candidates, fn c ->
          full = Path.join(repo_root, c)
          if File.exists?(full), do: full
        end)
      end

    unless src do
      Mix.shell().error(
        "book TXT not found (cwd=#{cwd}). See BOOK_SOURCES.md at the repo root " <>
          "for how to supply `book_9780262369978 (1).txt` locally. The book is " <>
          "CC BY-NC-ND from MIT Press; local copies are gitignored."
      )

      exit({:shutdown, 1})
    end

    body = File.read!(src)
    lines = String.split(body, "\n")
    total = length(lines)
    Mix.shell().info("Book TXT: #{Path.relative_to_cwd(src)}, #{total} lines")

    # Chapter excerpts are public (served under /book/chapters for the browser
    # TTS fallback); session excerpts stay server-side (priv/book/sessions).
    public_root = Path.join(repo_root, "active_inference/apps/workbench_web/priv/static/book")
    priv_root = Path.join(repo_root, "active_inference/apps/workbench_web/priv/book")
    dest_ch = Path.join(public_root, "chapters")
    dest_sess = Path.join(priv_root, "sessions")
    # Also mirror chapters under priv/book/chapters so SpeechController still finds them.
    dest_ch_priv = Path.join(priv_root, "chapters")
    File.mkdir_p!(dest_ch)
    File.mkdir_p!(dest_ch_priv)
    File.mkdir_p!(dest_sess)

    # Slice each chapter
    for ch <- WorkbenchWeb.Book.Chapters.all() do
      {a, b} = ch.txt_lines

      text =
        lines
        |> Enum.slice((a - 1)..(b - 1))
        |> Enum.join("\n")
        |> clean()

      name =
        case ch.num do
          0 -> "preface.txt"
          n -> "ch#{String.pad_leading(Integer.to_string(n), 2, "0")}.txt"
        end

      File.write!(Path.join(dest_ch, name), text)
      File.write!(Path.join(dest_ch_priv, name), text)
    end

    # Slice each session
    for sess <- WorkbenchWeb.Book.Sessions.all() do
      {a, b} = sess.txt_lines

      text =
        lines
        |> Enum.slice((a - 1)..(b - 1))
        |> Enum.join("\n")
        |> clean()

      ch = WorkbenchWeb.Book.Chapters.get(sess.chapter)
      fname = "#{ch.slug}__#{sess.slug}.txt"
      File.write!(Path.join(dest_sess, fname), text)
    end

    Mix.shell().info(
      "Wrote #{length(WorkbenchWeb.Book.Chapters.all())} chapter files and " <>
        "#{length(WorkbenchWeb.Book.Sessions.all())} session excerpts."
    )
  end

  # Strip repeated page headers and excessive blank lines so the excerpt reads
  # naturally when narrated aloud. Preserves inline equation markers like
  # "(4.19)" and "Figure 5.5".
  defp clean(text) do
    text
    |> String.replace(~r/^\s*Chapter\s+\d+\s*$/m, "")
    |> String.replace(~r/\n{3,}/, "\n\n")
    |> String.trim()
  end
end
