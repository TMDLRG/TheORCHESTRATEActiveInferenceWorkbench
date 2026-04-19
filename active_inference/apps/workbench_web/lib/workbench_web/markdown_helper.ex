defmodule WorkbenchWeb.MarkdownHelper do
  @moduledoc """
  Minimal in-app Markdown-to-HTML converter for the Jido knowledgebase +
  upstream guides.  Dependency-light: no Earmark in the deps, so we do
  line-oriented regex substitution covering the subset that matters for
  code documentation -- headings, lists, paragraphs, fenced code, inline
  code, bold, italic, links.

  Good enough for in-app reading; not a full CommonMark renderer.  For
  fidelity, readers can always follow the linked file on GitHub (every
  Jido page has a github.com/agentjido/jido link).
  """

  import Phoenix.HTML, only: [raw: 1, html_escape: 1]

  @spec render(String.t()) :: Phoenix.HTML.safe()
  def render(markdown) when is_binary(markdown) do
    markdown
    |> String.split(~r/\r?\n/)
    |> process_lines([], :normal, [])
    |> Enum.join("\n")
    |> raw()
  end

  def render(_), do: raw("")

  # process_lines(lines_remaining, out_acc, state, buffer)
  #   :normal          -- streaming paragraphs/headings/lists
  #   {:code, fence}   -- inside a fenced code block; buffer holds its lines
  defp process_lines([], out, :normal, _buf), do: Enum.reverse(out)

  defp process_lines([], out, {:code, _fence}, buf) do
    Enum.reverse([close_code(buf) | out])
  end

  defp process_lines([line | rest], out, :normal, _buf) do
    cond do
      Regex.match?(~r/^```/, line) ->
        process_lines(rest, out, {:code, "```"}, [])

      Regex.match?(~r/^#+\s/, line) ->
        process_lines(rest, [render_heading(line) | out], :normal, [])

      Regex.match?(~r/^[-*]\s/, line) ->
        process_lines(rest, [render_li(line, "ul") | out], :normal, [])

      Regex.match?(~r/^\d+\.\s/, line) ->
        process_lines(rest, [render_li(line, "ol") | out], :normal, [])

      Regex.match?(~r/^>\s?/, line) ->
        body = line |> String.replace(~r/^>\s?/, "") |> inline()
        process_lines(rest, ["<blockquote>#{body}</blockquote>" | out], :normal, [])

      String.trim(line) == "---" ->
        process_lines(rest, ["<hr/>" | out], :normal, [])

      String.trim(line) == "" ->
        process_lines(rest, ["" | out], :normal, [])

      true ->
        process_lines(rest, ["<p>#{inline(line)}</p>" | out], :normal, [])
    end
  end

  defp process_lines([line | rest], out, {:code, fence}, buf) do
    if String.starts_with?(line, fence) do
      process_lines(rest, [close_code(buf) | out], :normal, [])
    else
      process_lines(rest, out, {:code, fence}, [line | buf])
    end
  end

  defp close_code(buf) do
    body = buf |> Enum.reverse() |> Enum.join("\n") |> safe()
    "<pre><code>#{body}</code></pre>"
  end

  defp render_heading(line) do
    case String.split(line, ~r/\s+/, parts: 2) do
      [hashes, rest] ->
        level = min(String.length(hashes), 6)
        "<h#{level}>#{inline(rest)}</h#{level}>"

      [only] ->
        "<p>#{safe(only)}</p>"
    end
  end

  defp render_li(line, tag) do
    body = line |> String.replace(~r/^[-*\d.]+\s+/, "", global: false) |> inline()
    "<#{tag}><li>#{body}</li></#{tag}>"
  end

  defp inline(text) do
    text
    |> safe()
    |> String.replace(~r/`([^`]+)`/, "<code>\\1</code>")
    |> String.replace(~r/\*\*([^*]+)\*\*/, "<strong>\\1</strong>")
    |> String.replace(~r/\*([^*]+)\*/, "<em>\\1</em>")
    |> String.replace(
      ~r/\[([^\]]+)\]\(([^)]+)\)/,
      "<a href=\"\\2\" target=\"_blank\" rel=\"noopener noreferrer\">\\1</a>"
    )
  end

  defp safe(text), do: text |> html_escape() |> Phoenix.HTML.safe_to_string()
end
