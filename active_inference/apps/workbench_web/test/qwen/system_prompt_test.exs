defmodule WorkbenchWeb.Qwen.SystemPromptTest do
  @moduledoc """
  Golden-ish text tests for `WorkbenchWeb.Qwen.SystemPrompt.render/1`.

  Rather than asserting exact bytes (fragile), these tests assert that each
  packet yields a prompt with the expected sections present/absent, the
  tutor-mentor persona lines, the ROUTE MAP, and a NAVIGATION block where
  appropriate. That gives the author confidence the Qwen prompt has the
  learner-visible sections while staying resilient to copy tweaks.
  """
  use ExUnit.Case, async: true

  alias WorkbenchWeb.Qwen.{PageContext, SystemPrompt}

  describe "identity + persona" do
    test "every rendered prompt carries the tutor-mentor preamble" do
      prompt = SystemPrompt.render(PageContext.build(%{"path" => "real"}))

      assert prompt =~ "in-app tutor-mentor"
      assert prompt =~ "IDENTITY"
      assert prompt =~ "HOW YOU BEHAVE ON EVERY ANSWER"
      assert prompt =~ "one concrete next step"
    end

    test "persona path label follows the path param" do
      assert SystemPrompt.render(PageContext.build(%{"path" => "kid"})) =~ ~s|"story" path|

      assert SystemPrompt.render(PageContext.build(%{"path" => "derivation"})) =~
               ~s|"derivation" path|
    end
  end

  describe "ROUTE MAP + NAVIGATION" do
    test "ROUTE MAP is always present so Qwen can link to any page" do
      prompt = SystemPrompt.render(PageContext.build(%{}))
      assert prompt =~ "ROUTE MAP"
      assert prompt =~ "/cookbook"
      assert prompt =~ "/studio/run/"
    end

    test "NAVIGATION block appears when the packet has nav entries" do
      s = hd(WorkbenchWeb.Book.Sessions.all())

      prompt =
        SystemPrompt.render(
          PageContext.build(%{
            "page_type" => "session",
            "page_key" => "#{s.chapter}/#{s.slug}",
            "path" => "real"
          })
        )

      assert prompt =~ "NAVIGATION FROM THIS PAGE"
    end

    test "no NAVIGATION block on an empty packet" do
      refute SystemPrompt.render(PageContext.build(%{})) =~ "NAVIGATION FROM THIS PAGE"
    end
  end

  describe ":session packet" do
    test "includes chapter + session + excerpt sections when available" do
      s = hd(WorkbenchWeb.Book.Sessions.all())

      prompt =
        SystemPrompt.render(
          PageContext.build(%{
            "page_type" => "session",
            "page_key" => "#{s.chapter}/#{s.slug}",
            "path" => "real"
          })
        )

      assert prompt =~ "CHAPTER CONTEXT"
      assert prompt =~ "SESSION CONTEXT"
      # Excerpt only if the txt file exists; tolerate both.
      if prompt =~ "ON-PAGE EXCERPT", do: assert(prompt =~ "ground truth")
    end
  end

  describe ":cookbook_recipe packet" do
    test "includes RECIPE CARD with title + runtime" do
      recipe = hd(WorkbenchWeb.Cookbook.Loader.list())

      prompt =
        SystemPrompt.render(
          PageContext.build(%{
            "page_type" => "cookbook_recipe",
            "page_key" => recipe["slug"],
            "path" => "real"
          })
        )

      assert prompt =~ "RECIPE CARD"
      assert prompt =~ recipe["title"]
    end
  end

  describe ":live_episode rendering" do
    test "emits LIVE EPISODE section when episode is present in packet" do
      packet = %{
        page_type: :studio_run,
        page_key: "ep-abc",
        route: "/studio/run/ep-abc",
        page_title: "Studio run · ep-abc",
        path: "real",
        path_tier: :real,
        chapter: nil,
        session: nil,
        excerpt: nil,
        excerpt_truncated?: false,
        glossary_terms: [],
        recipe: nil,
        equation: nil,
        lab: nil,
        guide_topic: nil,
        instance: nil,
        episode: %{
          session_id: "ep-abc",
          agent_id: "agent-xyz",
          steps: 7,
          max_steps: 36,
          terminal?: false,
          goal_reached?: false,
          last_action: :forward,
          last_f: -0.42,
          last_g: 0.18,
          top_policies: [%{idx: 12, p: 0.61}, %{idx: 4, p: 0.18}, %{idx: 7, p: 0.09}],
          planned_actions: [:forward, :right, :forward]
        },
        nav: %{prev: nil, next: nil, related: []},
        seed: nil,
        budgets: %{excerpt: 2500, glossary: 800}
      }

      prompt = SystemPrompt.render(packet)

      assert prompt =~ "LIVE EPISODE"
      assert prompt =~ "ep-abc"
      assert prompt =~ "Steps: 7/36"
      assert prompt =~ "Last action: :forward"
      assert prompt =~ "P#12=0.61"
    end
  end

  describe "scoping section" do
    test "contains all four path rules" do
      prompt = SystemPrompt.render(PageContext.build(%{"path" => "real"}))
      assert prompt =~ "kid: grade-5"
      assert prompt =~ "real: grade-8"
      assert prompt =~ "equation: use Unicode math"
      assert prompt =~ "derivation: full formalism"
    end
  end

  describe "size envelope" do
    test "stays under 8 KB even with a full session packet" do
      s = hd(WorkbenchWeb.Book.Sessions.all())

      prompt =
        SystemPrompt.render(
          PageContext.build(%{
            "page_type" => "session",
            "page_key" => "#{s.chapter}/#{s.slug}",
            "path" => "real"
          })
        )

      assert byte_size(prompt) < 8_192
    end
  end
end
