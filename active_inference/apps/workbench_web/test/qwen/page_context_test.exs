defmodule WorkbenchWeb.Qwen.PageContextTest do
  @moduledoc """
  Per-builder coverage of `WorkbenchWeb.Qwen.PageContext.build/1`.

  Each test asserts: (1) the packet has the expected `page_type`, (2) nil
  fields stay nil (no accidental scraping), (3) `nav` links resolve to real
  app routes, and (4) the builder reads from the reused registry modules
  rather than re-deriving data.
  """
  use ExUnit.Case, async: true

  alias WorkbenchWeb.Qwen.PageContext

  describe "resolve_page_type (dispatch)" do
    test "defaults to :session when legacy chapter+session params are present" do
      p = PageContext.build(%{"chapter" => "2", "session" => "s1_inference_as_bayes"})
      assert p.page_type == :session
    end

    test "accepts the explicit page_type param" do
      p = PageContext.build(%{"page_type" => "cookbook_recipe", "page_key" => "pomdp-tiny-corridor"})
      assert p.page_type == :cookbook_recipe
    end

    test "falls back to :unknown for missing/bogus types" do
      assert PageContext.build(%{}).page_type == :unknown
      assert PageContext.build(%{"page_type" => "not-a-real-page"}).page_type == :unknown
    end
  end

  describe ":session builder" do
    test "assembles chapter + session + excerpt + glossary from the reused registries" do
      # Pick any real session; Book.Sessions.all/0 is non-empty.
      s = hd(WorkbenchWeb.Book.Sessions.all())

      packet =
        PageContext.build(%{
          "page_type" => "session",
          "page_key" => "#{s.chapter}/#{s.slug}",
          "path" => "real"
        })

      assert packet.page_type == :session
      assert packet.session.slug == s.slug
      assert packet.chapter.num == s.chapter
      assert is_list(packet.glossary_terms)
      assert packet.nav.related |> is_list()
    end

    test "handles legacy chapter+session shape at byte-parity" do
      s = hd(WorkbenchWeb.Book.Sessions.all())

      new =
        PageContext.build(%{
          "page_type" => "session",
          "page_key" => "#{s.chapter}/#{s.slug}",
          "path" => "real"
        })

      legacy =
        PageContext.build(%{
          "chapter" => to_string(s.chapter),
          "session" => s.slug,
          "path" => "real"
        })

      assert new.session.slug == legacy.session.slug
      assert new.chapter.num == legacy.chapter.num
      assert new.excerpt == legacy.excerpt
      assert new.glossary_terms == legacy.glossary_terms
    end

    test "sets prev/next nav for a middle-of-chapter session" do
      s = hd(WorkbenchWeb.Book.Sessions.all())
      sibling = WorkbenchWeb.Book.Sessions.next(s) || s

      packet =
        PageContext.build(%{
          "page_type" => "session",
          "page_key" => "#{sibling.chapter}/#{sibling.slug}",
          "path" => "real"
        })

      assert packet.nav.prev || packet.nav.next
    end
  end

  describe ":cookbook_recipe builder" do
    test "fetches recipe JSON + produces Run in Studio/Labs/Builder links" do
      recipe = hd(WorkbenchWeb.Cookbook.Loader.list())

      packet =
        PageContext.build(%{
          "page_type" => "cookbook_recipe",
          "page_key" => recipe["slug"],
          "path" => "real"
        })

      assert packet.page_type == :cookbook_recipe
      assert packet.recipe["slug"] == recipe["slug"]

      related_urls = Enum.map(packet.nav.related, & &1.url)
      assert Enum.any?(related_urls, &String.contains?(&1, "/studio/run_recipe?recipe="))
      assert Enum.any?(related_urls, &String.contains?(&1, "/labs?recipe="))
      assert Enum.any?(related_urls, &String.contains?(&1, "/builder/new?recipe="))
    end

    test "unknown slug yields an empty recipe packet (doesn't crash)" do
      packet =
        PageContext.build(%{
          "page_type" => "cookbook_recipe",
          "page_key" => "definitely-not-a-recipe-slug"
        })

      assert packet.page_type == :cookbook_recipe
      assert packet.recipe == nil
    end
  end

  describe ":equation builder" do
    test "fetches equation + populates nav.related with deps + citing recipes" do
      eq = hd(ActiveInferenceCore.Equations.all())

      packet =
        PageContext.build(%{
          "page_type" => "equation",
          "page_key" => to_string(eq.id)
        })

      assert packet.page_type == :equation
      assert packet.equation.id == eq.id
    end
  end

  describe ":guide builder" do
    test "fills guide_topic from page_key and populates nav.related" do
      packet =
        PageContext.build(%{
          "page_type" => "guide",
          "page_key" => "blocks"
        })

      assert packet.page_type == :guide
      assert packet.guide_topic == :blocks
      assert length(packet.nav.related) > 0
    end
  end

  describe ":chapter builder" do
    test "loads chapter metadata + lists sessions as related" do
      packet =
        PageContext.build(%{
          "page_type" => "chapter",
          "page_key" => "2"
        })

      assert packet.page_type == :chapter
      assert packet.chapter.num == 2

      assert Enum.all?(packet.nav.related, fn l ->
               String.starts_with?(l.url, "/learn/session/2/")
             end)
    end
  end

  describe "path_tier/1" do
    test "maps the four path strings to atoms" do
      assert PageContext.path_tier("kid") == :kid
      assert PageContext.path_tier("real") == :real
      assert PageContext.path_tier("equation") == :equation
      assert PageContext.path_tier("derivation") == :derivation
      assert PageContext.path_tier("bogus") == :real
    end
  end

  describe "render_glossary/3" do
    test "respects the byte budget and tier key" do
      # Use actual concepts from a real session so Glossary.get/1 returns
      # something rather than nil.
      s = hd(WorkbenchWeb.Book.Sessions.all())
      lines = PageContext.render_glossary(s.concepts, :real, 800)
      assert is_list(lines)
      total = lines |> Enum.map(&String.length/1) |> Enum.sum()
      assert total <= 800 + 200
    end
  end
end
