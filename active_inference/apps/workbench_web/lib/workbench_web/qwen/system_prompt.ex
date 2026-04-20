defmodule WorkbenchWeb.Qwen.SystemPrompt do
  @moduledoc """
  Turn a `WorkbenchWeb.Qwen.PageContext` packet into the Qwen system prompt.

  The prompt is sectioned — each section is only emitted if the packet has
  data for it. Order is stable so golden-text fixtures stay meaningful.
  Total size held under ~6 KB by the upstream excerpt + glossary budgets.

  Sections, in order:

    1. IDENTITY            persona + tutor-mentor behaviour contract
    2. PAGE CONTEXT        page_type + title + route
    3. ROUTE MAP           per-page-type slice of the app's URL map
    4. NAVIGATION          prev/next + related deep-links (packet.nav)
    5. CHAPTER CONTEXT     book chapter (if session/chapter page)
    6. SESSION CONTEXT     session title/minutes/on-page narration
    7. ON-PAGE EXCERPT     session txt / recipe card / equation body
    8. LIVE EPISODE        real-time snapshot (labs_run / studio_run)
    9. AGENT LIFECYCLE     Studio lifecycle state (tracked instance)
   10. GLOSSARY            path-tiered definitions of on-page concepts
   11. SESSION TUTOR SEED  optional one-liner override from session metadata
   12. SCOPING BY PATH     grade-5 / grade-8 / formal / derivation rules
  """

  alias WorkbenchWeb.Qwen.PageContext
  alias WorkbenchWeb.Book.Chapters

  @doc "Render a complete system prompt from a packet."
  @spec render(PageContext.packet()) :: String.t()
  def render(packet) when is_map(packet) do
    [
      identity_section(packet),
      page_context_section(packet),
      route_map_section(packet),
      navigation_section(packet),
      chapter_section(packet),
      session_section(packet),
      excerpt_section(packet),
      recipe_section(packet),
      equation_section(packet),
      guide_section(packet),
      live_episode_section(packet),
      instance_section(packet),
      glossary_section(packet),
      seed_section(packet),
      scoping_section(packet)
    ]
    |> Enum.reject(&(&1 == ""))
    |> Enum.join("\n\n")
  end

  # ----- sections ----------------------------------------------------------

  defp identity_section(packet) do
    path_label = path_label(packet.path)

    """
    You are the in-app tutor-mentor for The ORCHESTRATE Active Inference Learning
    Workbench. You sit with the learner at this exact screen. You see what they
    see, you know what comes next and what they just walked past, and you can
    open any part of the app for them.

    IDENTITY
    - Voice: patient, specific, second-person. No emojis, no fluff openers.
    - Path: learner is on the "#{path_label}" path — match that tone.

    HOW YOU BEHAVE ON EVERY ANSWER
    1. Ground every claim in the ON-PAGE block, the LIVE EPISODE block, or a
       named book chapter. If this page has no on-page block, say so in one
       sentence, then point to the closest NAVIGATION entry.
    2. End with exactly one concrete next step, phrased as a markdown link
       taken verbatim from the NAVIGATION block. Never invent URLs.
    3. On labs/studio pages, refer to the learner's real numbers (steps,
       action, policy index) rather than generalities.
    4. Under 250 words unless the learner says "deeper" or "derivation".
    5. When citing the book, write "(Ch <n>)" inline.\
    """
  end

  defp page_context_section(packet) do
    parts =
      [
        "- Page type: #{packet.page_type}",
        packet.page_title && "- Title: #{packet.page_title}",
        packet.route != "" && "- Route: #{packet.route}",
        packet.page_key && "- Key: #{packet.page_key}"
      ]
      |> Enum.reject(&is_nil/1)
      |> Enum.reject(&(&1 == false))

    if parts == [] do
      ""
    else
      "PAGE CONTEXT\n" <> Enum.join(parts, "\n")
    end
  end

  @app_routes [
    {"/learn", "Learning hub"},
    {"/learn/chapter/<n>", "Chapter 1..10 overview"},
    {"/learn/session/<n>/<slug>", "A single 8–15 min session"},
    {"/learn/progress", "Heatmap of completed sessions"},
    {"/cookbook", "Recipe index (50 runnable recipes)"},
    {"/cookbook/<slug>", "Recipe card + Run in Builder/Labs/Studio"},
    {"/labs", "Labs index — fresh agent+world per click"},
    {"/labs?recipe=<slug>", "Launch Labs from a recipe"},
    {"/studio", "Studio dashboard (tracked agents)"},
    {"/studio/new", "Start a new run: Attach / Spec / Recipe"},
    {"/studio/run/<session_id>", "Live attached episode view"},
    {"/studio/agents/<agent_id>", "Per-agent lifecycle panel"},
    {"/studio/trash", "Soft-deleted agents (restore / empty)"},
    {"/builder/new", "Lego-style composition canvas"},
    {"/equations", "Book equation registry"},
    {"/equations/<id>", "One equation with symbols + deps"},
    {"/models", "Model-family taxonomy"},
    {"/world", "Maze playground"},
    {"/glass", "Signal river (every agent)"},
    {"/glass/agent/<agent_id>", "Per-agent trace"},
    {"/guide", "Guide hub"},
    {"/guide/<topic>", "blocks|cookbook|studio|jido|orchestrate|level-up|…"}
  ]

  defp route_map_section(_packet) do
    lines =
      @app_routes
      |> Enum.map(fn {url, label} -> "- #{String.pad_trailing(url, 34)} #{label}" end)

    """
    ROUTE MAP (relative links open in-tab; never invent paths)
    #{Enum.join(lines, "\n")}\
    """
  end

  defp navigation_section(%{nav: %{prev: nil, next: nil, related: []}}), do: ""

  defp navigation_section(%{nav: nav}) do
    lines =
      []
      |> then(fn acc -> if nav.prev, do: ["- Prev: [#{nav.prev.label}](#{nav.prev.url})" | acc], else: acc end)
      |> then(fn acc -> if nav.next, do: ["- Next: [#{nav.next.label}](#{nav.next.url})" | acc], else: acc end)

    related =
      nav.related
      |> Enum.take(8)
      |> Enum.map(fn r -> "- #{kind_prefix(r.kind)}: [#{r.label}](#{r.url})" end)

    all = Enum.reverse(lines) ++ related

    "NAVIGATION FROM THIS PAGE (pick exactly one for your closing link)\n" <>
      Enum.join(all, "\n")
  end

  defp chapter_section(%{chapter: nil}), do: ""

  defp chapter_section(%{chapter: ch}) do
    """
    CHAPTER CONTEXT
    Part: #{Chapters.part_label(ch.part)}
    Chapter #{ch.num} · #{ch.title}
    Hero concept: #{safe(ch, :hero)}
    Summary: #{safe(ch, :blurb)}\
    """
  end

  defp session_section(%{session: nil}), do: ""

  defp session_section(%{session: s, path: path, path_tier: tier}) do
    narration = Map.get(s.path_text || %{}, String.to_atom(path)) || Map.get(s.path_text || %{}, :real) || ""

    lab_labels =
      (s.labs || [])
      |> Enum.map(fn %{slug: sl, beat: b} -> "#{sl} (beat #{b})" end)
      |> Enum.join(", ")

    wb_labels =
      (s.workbench || [])
      |> Enum.map(& &1.label)
      |> Enum.join(", ")

    """
    SESSION CONTEXT
    Session #{s.ordinal} of Chapter #{s.chapter} · #{s.title}
    Estimated time: #{s.minutes} minutes
    On-page narration (#{tier} tier):
    #{narration}
    Linked labs: #{if lab_labels == "", do: "(none)", else: lab_labels}
    Linked Workbench surfaces: #{if wb_labels == "", do: "(none)", else: wb_labels}\
    """
  end

  defp excerpt_section(%{excerpt: nil}), do: ""

  defp excerpt_section(%{excerpt: text, chapter: ch, excerpt_truncated?: truncated?}) do
    suffix = if truncated?, do: "…\n[excerpt truncated]", else: ""
    ch_num = (ch && ch.num) || "?"

    """
    ON-PAGE EXCERPT (verbatim from Chapter #{ch_num}; treat as ground truth):
    ---
    #{text}#{suffix}
    ---\
    """
  end

  defp recipe_section(%{recipe: nil}), do: ""

  defp recipe_section(%{recipe: r}) do
    math = get_in(r, ["math", "latex"]) || ""
    real = get_in(r, ["audiences", "real"]) || get_in(r, ["audiences", "equation"]) || ""
    runtime = Map.get(r, "runtime") || %{}

    parts =
      [
        "RECIPE CARD",
        "Title: #{r["title"]}",
        r["level"] && "Level: L#{r["level"]} — #{r["tier_label"] || ""}",
        r["minutes"] && "Estimated time: #{r["minutes"]} min",
        real != "" && "Real-world explanation:\n#{real}",
        math != "" && "Math:\n#{math}",
        runtime != %{} && "Runtime: agent=#{Map.get(runtime, "agent_module")} world=#{Map.get(runtime, "world")} horizon=#{Map.get(runtime, "horizon")} policy_depth=#{Map.get(runtime, "policy_depth")} preference_strength=#{Map.get(runtime, "preference_strength")}"
      ]
      |> Enum.reject(&(&1 in [nil, false, ""]))

    Enum.join(parts, "\n")
  end

  defp equation_section(%{equation: nil}), do: ""

  defp equation_section(%{equation: eq}) do
    symbols =
      case Map.get(eq, :symbols) do
        nil ->
          ""

        list when is_list(list) ->
          list
          |> Enum.map_join("\n", fn
            %{name: name, meaning: meaning} -> "  #{name} — #{meaning}"
            {sym, gloss} -> "  #{sym} — #{gloss}"
            other -> "  #{inspect(other)}"
          end)

        map when is_map(map) ->
          map |> Enum.map_join("\n", fn {sym, gloss} -> "  #{sym} — #{gloss}" end)

        _ ->
          ""
      end

    deps =
      case Map.get(eq, :dependencies) do
        nil -> "(none)"
        [] -> "(none)"
        list -> Enum.join(list, ", ")
      end

    ch = Map.get(eq, :chapter) || "?"
    section = Map.get(eq, :section) || ""
    label = Map.get(eq, :equation_number) || Map.get(eq, :id) || ""
    status = Map.get(eq, :verification_status) || "unverified"
    body = Map.get(eq, :normalized_latex) || Map.get(eq, :source_text_equation) || ""

    """
    EQUATION
    Label: #{label} · Chapter #{ch} · #{section}
    Verification: #{status}
    Body (LaTeX):
    #{body}
    Symbols:
    #{symbols}
    Dependencies: #{deps}\
    """
  end

  defp guide_section(%{guide_topic: nil}), do: ""

  defp guide_section(%{guide_topic: topic}) do
    summary =
      case topic do
        :blocks ->
          "The block catalogue lists every Jido Action, Skill, and Agent the Builder can drop on the canvas. Each block has typed ports; the Inspector round-trips params through Zoi validation."

        :cookbook ->
          "50 runnable recipes span Perception, Planning, Learning, Preferences, Sophisticated Plan, Continuous Time, Hierarchical, Multimodal, Predictive Coding, and Bayes. Each has Run in Builder/Labs/Studio."

        :studio ->
          "Studio is the flexible lab: attach any tracked agent to any world, with full live/stopped/archived/trashed lifecycle. Forward-compatible with the custom world builder via WorldPlane.WorldBehaviour."

        :labs ->
          "Labs is the stable runner: fresh agent+world per click. Snapshot-tested; never regresses."

        :learning ->
          "10-chapter curriculum with 39 sessions across 4 paths (kid/real/equation/derivation). Each session has path-specific narration, excerpt, glossary, labs, quiz."

        :jido ->
          "Jido v2.2.0 is the pure-Elixir agent framework. 26 curated topics in knowledgebase/jido/; see guide/jido for the primer."

        :orchestrate ->
          "THE ORCHESTRATE METHOD™ by Michael Polzin: 11-letter prompt-shaping framework (O-R-C foundation + H-E-S-T / R-A-T / E)."

        :level_up ->
          "LEVEL UP by Michael Polzin: AI Usage Maturity Model (AI-UMM) — 6 levels from Curious Dabbler to Amplified Human."

        :features ->
          "Honest state (works / partial / scaffold) for every feature; see /guide/features."

        :voice ->
          "Piper TTS narrator on every session; MCP/SSE voice tools in LibreChat via claude_speak."

        :chat ->
          "LibreChat + 27 ORCHESTRATE-shaped tutor agents, MCP-enabled, works with OpenAI/Anthropic/any OpenAI-compatible endpoint."

        :creator ->
          "Michael Polzin — author of THE ORCHESTRATE METHOD™ and LEVEL UP; creator of AI-UMM."

        :credits ->
          "Consolidated credits and attributions: Parr/Pezzulo/Friston (MIT Press, CC BY-NC-ND), agentjido, LibreChat, Piper, llama.cpp, Qwen."

        _ ->
          "Guide topic: #{topic}"
      end

    "GUIDE TOPIC SUMMARY\n#{summary}"
  end

  defp live_episode_section(%{episode: nil}), do: ""

  defp live_episode_section(%{episode: ep}) do
    top =
      (ep.top_policies || [])
      |> Enum.map(fn %{idx: i, p: p} -> "P##{i}=#{Float.round(p, 3)}" end)
      |> Enum.join(", ")

    planned =
      case ep.planned_actions do
        [] -> "(none)"
        list -> list |> Enum.map(&inspect/1) |> Enum.join(" → ")
      end

    f_str = if ep.last_f, do: Float.round(ep.last_f, 3) |> to_string(), else: "?"
    g_str = if ep.last_g, do: Float.round(ep.last_g, 3) |> to_string(), else: "?"

    """
    LIVE EPISODE (real-time; you are sitting with the learner in this run)
    - Session: #{ep.session_id} (agent: #{ep.agent_id || "?"})
    - Steps: #{ep.steps}/#{ep.max_steps}   terminal?: #{ep.terminal?}   goal_reached?: #{ep.goal_reached?}
    - Last action: #{inspect(ep.last_action)}   F=#{f_str}   G=#{g_str}
    - Top-3 policies now: #{if top == "", do: "(posterior unavailable)", else: top}
    - Agent's planned next actions: #{planned}
    When asked "why did it do X?", cite this block. When asked "what if…?",
    reason within one step of this state.\
    """
  end

  defp instance_section(%{instance: nil}), do: ""

  defp instance_section(%{instance: inst}) do
    """
    AGENT LIFECYCLE (tracked in Studio)
    - agent_id: #{Map.get(inst, :agent_id, "?")}
    - state: #{Map.get(inst, :state, "?")}
    - source: #{Map.get(inst, :source, "?")}
    - spec: #{Map.get(inst, :spec_id) || "(inline)"}
    - name: #{Map.get(inst, :name) || "(unnamed)"}\
    """
  end

  defp glossary_section(%{glossary_terms: []}), do: ""
  defp glossary_section(%{glossary_terms: nil}), do: ""

  defp glossary_section(%{glossary_terms: terms, path_tier: tier}) do
    case PageContext.render_glossary(terms, tier) do
      [] ->
        ""

      lines ->
        "GLOSSARY (#{tier} tier, on-page concepts)\n" <> Enum.join(lines, "\n")
    end
  end

  defp seed_section(%{seed: nil}), do: ""
  defp seed_section(%{seed: ""}), do: ""

  defp seed_section(%{seed: seed}) do
    "SESSION TUTOR SEED\n#{seed}"
  end

  defp scoping_section(%{path: path}) do
    """
    SCOPING BY PATH
    - kid: grade-5 vocabulary, one concrete image per concept, no equations unless asked.
    - real: grade-8 vocabulary with everyday analogies; equations only when they clarify.
    - equation: use Unicode math freely, cite equation numbers, keep derivations tight.
    - derivation: full formalism; cite proof sources; flag heuristic steps.
    Current path: #{path_label(path)} (#{path_scope(path)})\
    """
  end

  # ----- helpers -----------------------------------------------------------

  defp path_label("kid"), do: "story"
  defp path_label("real"), do: "real-world"
  defp path_label("equation"), do: "equation"
  defp path_label("derivation"), do: "derivation"
  defp path_label(_), do: "real-world"

  defp path_scope("kid"),
    do:
      "grade-5 vocabulary, one concrete image per concept, avoid equations unless the learner asks"

  defp path_scope("real"),
    do: "grade-8 vocabulary with everyday analogies; equations only when they clarify"

  defp path_scope("equation"),
    do: "Unicode math freely, cite equation numbers, keep derivations tight"

  defp path_scope("derivation"),
    do: "full formalism; cite proof sources, flag heuristic steps; undergrad analysis OK"

  defp path_scope(_), do: "grade-8 vocabulary with everyday analogies"

  defp kind_prefix(:session), do: "Session"
  defp kind_prefix(:chapter), do: "Chapter"
  defp kind_prefix(:recipe), do: "Recipe"
  defp kind_prefix(:equation), do: "Equation"
  defp kind_prefix(:lab), do: "Lab"
  defp kind_prefix(:builder), do: "Builder"
  defp kind_prefix(:labs), do: "Labs"
  defp kind_prefix(:labs_run), do: "Run in Labs"
  defp kind_prefix(:labs_index), do: "Labs"
  defp kind_prefix(:studio), do: "Studio"
  defp kind_prefix(:studio_run), do: "Run in Studio"
  defp kind_prefix(:studio_new), do: "Studio"
  defp kind_prefix(:studio_agent), do: "Studio agent"
  defp kind_prefix(:glass), do: "Glass"
  defp kind_prefix(:guide), do: "Guide"
  defp kind_prefix(:learning_hub), do: "Learn"
  defp kind_prefix(:equations_index), do: "Equations"
  defp kind_prefix(:models), do: "Models"
  defp kind_prefix(_), do: "Related"

  defp safe(map, key) when is_map(map), do: Map.get(map, key, "")
  defp safe(_, _), do: ""
end
