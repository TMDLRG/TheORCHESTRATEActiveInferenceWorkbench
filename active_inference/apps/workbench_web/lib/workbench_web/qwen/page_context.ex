defmodule WorkbenchWeb.Qwen.PageContext do
  @moduledoc """
  Per-request page-aware tutor context.

  `build/1` takes the params map POSTed to `/api/uber-help` and returns a
  `t:packet/0` that describes *everything* Qwen needs to know about the
  learner's current screen: route, page type, on-page content, live episode
  state (labs/studio), navigation affordances.

  One builder clause per page type. Adding a new route to the tutor is
  adding one clause here (and one in `WorkbenchWeb.Qwen.SystemPrompt` +
  one in `WorkbenchWeb.Qwen.Presets`). Every builder reuses existing
  registry modules — no duplicate data fetching.

  ## Accepted params

  Preferred (sent by the new `QwenDrawer` JS hook + `Qwen.Hook` on_mount):

      %{
        "page_type"  => "cookbook_recipe",
        "page_key"   => "pomdp-tiny-corridor",
        "route"      => "/cookbook/pomdp-tiny-corridor",
        "page_title" => "Tiny POMDP Corridor",
        "path"       => "real",
        "seed"       => "…"
      }

  Legacy (session routes; kept for backwards compatibility during S1-S4):

      %{"chapter" => "2", "session" => "s1_…", "path" => "real", "seed" => "…"}
  """

  alias WorkbenchWeb.Book.{Chapters, Sessions, Glossary}
  alias WorkbenchWeb.Cookbook.Loader, as: Cookbook
  alias WorkbenchWeb.LearningCatalog
  alias ActiveInferenceCore.Equations

  @excerpt_budget_chars 2500
  @glossary_budget_chars 800

  @type path_tier :: :kid | :real | :equation | :derivation

  @type nav_link :: %{url: String.t(), label: String.t()}

  @type nav :: %{
          prev: nav_link() | nil,
          next: nav_link() | nil,
          related: [%{url: String.t(), label: String.t(), kind: atom()}]
        }

  @type packet :: %{
          page_type: atom(),
          page_key: String.t() | nil,
          route: String.t(),
          page_title: String.t() | nil,
          path: String.t(),
          path_tier: path_tier(),
          chapter: map() | nil,
          session: map() | nil,
          excerpt: String.t() | nil,
          excerpt_truncated?: boolean(),
          glossary_terms: [String.t()],
          recipe: map() | nil,
          equation: map() | nil,
          lab: map() | nil,
          guide_topic: atom() | nil,
          episode: map() | nil,
          instance: map() | nil,
          nav: nav(),
          seed: String.t() | nil,
          budgets: %{excerpt: pos_integer(), glossary: pos_integer()}
        }

  @empty_nav %{prev: nil, next: nil, related: []}

  @doc "Assemble a packet from request params."
  @spec build(map()) :: packet()
  def build(params) when is_map(params) do
    path = to_string(Map.get(params, "path", "real"))
    page_type = resolve_page_type(params)
    page_key = Map.get(params, "page_key")

    base = %{
      page_type: page_type,
      page_key: page_key,
      route: Map.get(params, "route") || "",
      page_title: Map.get(params, "page_title"),
      path: path,
      path_tier: path_tier(path),
      chapter: nil,
      session: nil,
      excerpt: nil,
      excerpt_truncated?: false,
      glossary_terms: [],
      recipe: nil,
      equation: nil,
      lab: nil,
      guide_topic: nil,
      episode: nil,
      instance: nil,
      nav: @empty_nav,
      seed: empty_to_nil(Map.get(params, "seed", "")),
      budgets: %{excerpt: @excerpt_budget_chars, glossary: @glossary_budget_chars}
    }

    build_specific(page_type, params, base)
  end

  # ----- page-type dispatch ------------------------------------------------

  # :session — full parity with the pre-refactor controller path.
  defp build_specific(:session, params, base) do
    chapter_num = session_chapter(params)
    session_slug = session_slug(params)
    ch = chapter_num && Chapters.get(chapter_num)
    s = if ch, do: Sessions.find(chapter_num, session_slug), else: nil

    {excerpt, truncated?} = session_excerpt(ch, s)

    base
    |> Map.put(:chapter, ch)
    |> Map.put(:session, s)
    |> Map.put(:excerpt, excerpt)
    |> Map.put(:excerpt_truncated?, truncated?)
    |> Map.put(:glossary_terms, (s && s.concepts) || [])
    |> Map.put(:nav, session_nav(s))
  end

  defp build_specific(:chapter, params, base) do
    chapter_num = parse_int(Map.get(params, "chapter") || Map.get(params, "page_key"))
    ch = chapter_num && Chapters.get(chapter_num)

    related =
      if ch do
        ch.num
        |> Sessions.for_chapter()
        |> Enum.take(6)
        |> Enum.map(fn s ->
          %{
            url: "/learn/session/#{s.chapter}/#{s.slug}",
            label: "§#{s.ordinal} · #{s.title}",
            kind: :session
          }
        end)
      else
        []
      end

    base
    |> Map.put(:chapter, ch)
    |> Map.put(:nav, %{prev: nil, next: nil, related: related})
  end

  defp build_specific(:cookbook_recipe, params, base) do
    slug = to_string(Map.get(params, "page_key") || "")

    case Cookbook.get(slug) do
      nil ->
        base

      recipe ->
        related =
          []
          |> then(&(&1 ++ linked_equations(recipe)))
          |> then(&(&1 ++ linked_labs(recipe)))
          |> then(&(&1 ++ linked_recipe_sessions(recipe)))
          |> then(&(&1 ++ recipe_run_links(slug, recipe)))
          |> Enum.uniq_by(& &1.url)

        glossary_terms =
          (Map.get(recipe, "concepts") || [])
          |> Enum.map(&to_string/1)

        base
        |> Map.put(:recipe, recipe)
        |> Map.put(:glossary_terms, glossary_terms)
        |> Map.put(:nav, %{prev: nil, next: nil, related: related})
    end
  end

  defp build_specific(:cookbook_index, _params, base) do
    related =
      safe_cookbook_list()
      |> Enum.take(8)
      |> Enum.map(fn r ->
        %{
          url: "/cookbook/#{r["slug"]}",
          label: "L#{r["level"] || "?"} · #{r["title"]}",
          kind: :recipe
        }
      end)

    Map.put(base, :nav, %{prev: nil, next: nil, related: related})
  end

  defp build_specific(:equation, params, base) do
    id = to_string(Map.get(params, "page_key") || "")
    eq = safe_equation_fetch(id)

    related =
      if eq do
        deps =
          (Map.get(eq, :dependencies) || [])
          |> Enum.take(4)
          |> Enum.map(fn dep ->
            %{url: "/equations/#{dep}", label: "Depends on #{dep}", kind: :equation}
          end)

        recipes = recipes_citing_equation(id)

        deps ++ recipes
      else
        []
      end

    base
    |> Map.put(:equation, eq)
    |> Map.put(:nav, %{prev: nil, next: nil, related: related})
  end

  defp build_specific(:labs_run, params, base) do
    recipe_slug = Map.get(params, "recipe") || Map.get(params, "page_key")
    recipe = recipe_slug && Cookbook.get(to_string(recipe_slug))
    episode = episode_snapshot(Map.get(params, "session_id"))

    base
    |> Map.put(:recipe, recipe)
    |> Map.put(:episode, episode)
    |> Map.put(:nav, %{
      prev: nil,
      next: nil,
      related:
        (recipe &&
           [
             %{
               url: "/cookbook/#{recipe["slug"]}",
               label: "Recipe · #{recipe["title"]}",
               kind: :recipe
             }
           ]) || []
    })
  end

  defp build_specific(:studio_run, params, base) do
    session_id = to_string(Map.get(params, "page_key") || Map.get(params, "session_id") || "")
    episode = episode_snapshot(session_id)
    instance = instance_lookup(episode && episode.agent_id)

    related =
      []
      |> then(fn acc ->
        if instance do
          [
            %{
              url: "/studio/agents/#{instance.agent_id}",
              label: "Agent panel · #{instance.agent_id}",
              kind: :studio_agent
            }
            | acc
          ]
        else
          acc
        end
      end)
      |> then(fn acc ->
        if episode && episode.agent_id do
          [
            %{
              url: "/glass/agent/#{episode.agent_id}",
              label: "Glass trace",
              kind: :glass
            }
            | acc
          ]
        else
          acc
        end
      end)

    base
    |> Map.put(:episode, episode)
    |> Map.put(:instance, instance)
    |> Map.put(:nav, %{prev: nil, next: nil, related: Enum.reverse(related)})
  end

  defp build_specific(:studio_agent, params, base) do
    agent_id = to_string(Map.get(params, "page_key") || "")
    instance = instance_lookup(agent_id)

    related = [
      %{url: "/glass/agent/#{agent_id}", label: "Glass trace", kind: :glass},
      %{url: "/studio/new?agent=#{agent_id}", label: "Attach to a world", kind: :studio_new}
    ]

    base
    |> Map.put(:instance, instance)
    |> Map.put(:nav, %{prev: nil, next: nil, related: related})
  end

  defp build_specific(:guide, params, base) do
    topic = params |> Map.get("page_key") |> atomize_topic()

    related =
      case topic do
        :blocks -> [link("/cookbook", "Browse runnable recipes", :recipe), link("/builder/new", "Open builder", :builder)]
        :cookbook -> [link("/cookbook", "Cookbook index", :recipe), link("/builder/new", "Open builder", :builder)]
        :labs -> [link("/labs", "Labs index", :labs), link("/guide/blocks", "Block catalogue", :guide)]
        :studio -> [link("/studio", "Studio dashboard", :studio), link("/guide/labs", "Labs overview", :guide)]
        :learning -> [link("/learn", "Learn hub", :learning_hub), link("/guide/workbench", "Workbench tour", :guide)]
        :jido -> [link("/guide/jido", "Knowledgebase index", :guide)]
        :orchestrate -> [link("/guide/orchestrate", "Framework primer", :guide)]
        :level_up -> [link("/guide/level-up", "AI-UMM primer", :guide)]
        :creator -> [link("/guide/credits", "Credits & attributions", :guide)]
        _ -> [link("/guide", "Guide home", :guide)]
      end

    base
    |> Map.put(:guide_topic, topic)
    |> Map.put(:nav, %{prev: nil, next: nil, related: related})
  end

  defp build_specific(:builder, params, base) do
    recipe_slug = Map.get(params, "recipe") || Map.get(params, "page_key")
    recipe = recipe_slug && Cookbook.get(to_string(recipe_slug))

    related =
      [link("/cookbook", "Pick a recipe", :recipe), link("/labs", "Labs index", :labs)] ++
        if recipe, do: [link("/cookbook/#{recipe["slug"]}", "Recipe · #{recipe["title"]}", :recipe)], else: []

    base
    |> Map.put(:recipe, recipe)
    |> Map.put(:nav, %{prev: nil, next: nil, related: related})
  end

  defp build_specific(:learning_hub, _params, base) do
    chapters =
      Chapters.all()
      |> Enum.take(10)
      |> Enum.map(fn ch ->
        %{url: "/learn/chapter/#{ch.num}", label: "Ch #{ch.num} · #{ch.title}", kind: :chapter}
      end)

    Map.put(base, :nav, %{prev: nil, next: nil, related: chapters})
  end

  defp build_specific(:labs_index, _params, base) do
    related = [
      link("/cookbook", "Recipe index", :recipe),
      link("/studio", "Studio (long-lived agents)", :studio),
      link("/guide/labs", "How Labs work", :guide)
    ]

    Map.put(base, :nav, %{prev: nil, next: nil, related: related})
  end

  defp build_specific(:studio_index, _params, base) do
    related = [
      link("/studio/new", "Start a new run", :studio_new),
      link("/studio/trash", "Trash (restore/empty)", :studio),
      link("/guide/studio", "Studio vs Labs", :guide)
    ]

    Map.put(base, :nav, %{prev: nil, next: nil, related: related})
  end

  defp build_specific(:studio_new, _params, base) do
    related = [
      link("/cookbook", "Browse recipes", :recipe),
      link("/builder/new", "Open builder", :builder),
      link("/guide/studio", "Studio guide", :guide)
    ]

    Map.put(base, :nav, %{prev: nil, next: nil, related: related})
  end

  defp build_specific(:studio_trash, _params, base) do
    Map.put(base, :nav, %{prev: nil, next: nil, related: [link("/studio", "Studio dashboard", :studio)]})
  end

  defp build_specific(:glass, _params, base) do
    Map.put(base, :nav, %{prev: nil, next: nil, related: [link("/studio", "Studio", :studio)]})
  end

  defp build_specific(:glass_agent, params, base) do
    agent_id = to_string(Map.get(params, "page_key") || "")
    instance = instance_lookup(agent_id)

    related = [
      link("/studio/agents/#{agent_id}", "Studio panel", :studio_agent),
      link("/glass", "All agents", :glass)
    ]

    base
    |> Map.put(:instance, instance)
    |> Map.put(:nav, %{prev: nil, next: nil, related: related})
  end

  defp build_specific(:equations_index, _params, base) do
    Map.put(base, :nav, %{prev: nil, next: nil, related: [link("/models", "Model taxonomy", :models)]})
  end

  defp build_specific(:models, _params, base) do
    Map.put(base, :nav, %{
      prev: nil,
      next: nil,
      related: [link("/equations", "Equation registry", :equations_index)]
    })
  end

  defp build_specific(:world, _params, base) do
    Map.put(base, :nav, %{prev: nil, next: nil, related: [link("/labs", "Labs index", :labs)]})
  end

  defp build_specific(:home, _params, base) do
    Map.put(base, :nav, %{
      prev: nil,
      next: nil,
      related: [
        link("/learn", "Start learning", :learning_hub),
        link("/cookbook", "Browse recipes", :recipe),
        link("/guide", "Tour the app", :guide)
      ]
    })
  end

  defp build_specific(:learn_progress, _params, base) do
    Map.put(base, :nav, %{prev: nil, next: nil, related: [link("/learn", "Back to Learn hub", :learning_hub)]})
  end

  defp build_specific(_unknown, _params, base), do: base

  # ----- page-type resolution ---------------------------------------------

  @known_types ~w(session chapter cookbook_recipe cookbook_index equation equations_index
                  labs_run labs_index studio_index studio_new studio_run studio_agent
                  studio_trash builder glass glass_agent guide learning_hub learn_progress
                  models world home)a

  defp resolve_page_type(params) do
    case atomize_type(Map.get(params, "page_type")) do
      nil ->
        # Legacy: if chapter + session are present, assume :session.
        cond do
          Map.get(params, "session") not in [nil, ""] -> :session
          Map.get(params, "chapter") not in [nil, ""] -> :chapter
          true -> :unknown
        end

      t ->
        t
    end
  end

  defp atomize_type(nil), do: nil
  defp atomize_type(""), do: nil

  defp atomize_type(s) when is_binary(s) do
    atom = String.to_atom(s)
    if atom in @known_types, do: atom, else: :unknown
  end

  defp atomize_type(a) when is_atom(a) do
    if a in @known_types, do: a, else: :unknown
  end

  defp atomize_topic(nil), do: nil

  defp atomize_topic(s) when is_binary(s) do
    s
    |> String.replace("-", "_")
    |> String.to_atom()
  end

  defp atomize_topic(a) when is_atom(a), do: a

  # ----- helpers ----------------------------------------------------------

  @doc "Resolve a path string to a path_tier atom used by SystemPrompt."
  @spec path_tier(String.t() | atom()) :: path_tier()
  def path_tier("kid"), do: :kid
  def path_tier("derivation"), do: :derivation
  def path_tier("equation"), do: :equation
  def path_tier(_), do: :real

  defp session_chapter(params) do
    case Map.get(params, "page_key") do
      <<key::binary>> ->
        case String.split(key, "/", parts: 2) do
          [ch, _slug] -> parse_int(ch)
          _ -> parse_int(Map.get(params, "chapter"))
        end

      _ ->
        parse_int(Map.get(params, "chapter"))
    end
  end

  defp session_slug(params) do
    case Map.get(params, "page_key") do
      <<key::binary>> ->
        case String.split(key, "/", parts: 2) do
          [_ch, slug] -> slug
          _ -> to_string(Map.get(params, "session", ""))
        end

      _ ->
        to_string(Map.get(params, "session", ""))
    end
  end

  defp session_excerpt(nil, _), do: {nil, false}
  defp session_excerpt(_ch, nil), do: {nil, false}

  defp session_excerpt(ch, s) do
    path =
      Path.join([
        Application.app_dir(:workbench_web, "priv"),
        "book/sessions",
        "#{ch.slug}__#{s.slug}.txt"
      ])

    case File.read(path) do
      {:ok, text} ->
        clipped = String.slice(text, 0, @excerpt_budget_chars)
        truncated? = String.length(text) > @excerpt_budget_chars
        {clipped, truncated?}

      _ ->
        {nil, false}
    end
  end

  defp session_nav(nil), do: @empty_nav

  defp session_nav(s) do
    prev = Sessions.prev(s)
    next = Sessions.next(s)

    related =
      (s.labs || [])
      |> Enum.map(fn %{slug: sl, beat: b} ->
        case LearningCatalog.find(sl) do
          nil ->
            %{url: "/learninglabs/#{sl}.html?beat=#{b}", label: "Lab · #{sl}", kind: :lab}

          lab ->
            %{
              url: "/learninglabs/#{lab.file}?beat=#{b}",
              label: "Lab · #{lab.title}",
              kind: :lab
            }
        end
      end)

    %{
      prev:
        prev &&
          %{
            url: "/learn/session/#{prev.chapter}/#{prev.slug}",
            label: "Ch #{prev.chapter} · #{prev.title}"
          },
      next:
        next &&
          %{
            url: "/learn/session/#{next.chapter}/#{next.slug}",
            label: "Ch #{next.chapter} · #{next.title}"
          },
      related: related
    }
  end

  defp linked_equations(recipe) do
    (Map.get(recipe, "equation_refs") || [])
    |> Enum.map(fn id ->
      %{url: "/equations/#{id}", label: "Equation · #{id}", kind: :equation}
    end)
  end

  defp linked_labs(recipe) do
    (Map.get(recipe, "labs") || [])
    |> Enum.map(fn slug ->
      case LearningCatalog.find(slug) do
        nil ->
          %{url: "/learninglabs/#{slug}.html", label: "Lab · #{slug}", kind: :lab}

        lab ->
          %{url: "/learninglabs/#{lab.file}", label: "Lab · #{lab.title}", kind: :lab}
      end
    end)
  end

  defp linked_recipe_sessions(recipe) do
    (Map.get(recipe, "session_refs") || [])
    |> Enum.map(fn ref ->
      %{url: "/learn", label: "Session · #{ref}", kind: :session}
    end)
  end

  defp recipe_run_links(slug, _recipe) do
    [
      %{url: "/studio/run_recipe?recipe=#{slug}", label: "Run in Studio", kind: :studio_run},
      %{url: "/labs?recipe=#{slug}", label: "Run in Labs", kind: :labs_run},
      %{url: "/builder/new?recipe=#{slug}", label: "Open in Builder", kind: :builder}
    ]
  end

  defp recipes_citing_equation(id) do
    safe_cookbook_list()
    |> Enum.filter(fn r -> id in (Map.get(r, "equation_refs") || []) end)
    |> Enum.take(4)
    |> Enum.map(fn r ->
      %{url: "/cookbook/#{r["slug"]}", label: "Recipe · #{r["title"]}", kind: :recipe}
    end)
  end

  defp safe_cookbook_list do
    try do
      Cookbook.list()
    rescue
      _ -> []
    end
  end

  defp safe_equation_fetch(""), do: nil

  defp safe_equation_fetch(id) do
    try do
      Equations.fetch(id)
    rescue
      _ -> nil
    end
  end

  defp episode_snapshot(nil), do: nil
  defp episode_snapshot(""), do: nil

  defp episode_snapshot(session_id) when is_binary(session_id) do
    try do
      WorkbenchWeb.Qwen.EpisodeSnap.from_session_id(session_id)
    rescue
      _ -> nil
    end
  end

  defp instance_lookup(nil), do: nil
  defp instance_lookup(""), do: nil

  defp instance_lookup(agent_id) when is_binary(agent_id) do
    try do
      case AgentPlane.Instances.get(agent_id) do
        {:ok, inst} -> inst
        _ -> nil
      end
    rescue
      _ -> nil
    end
  end

  defp instance_lookup(_), do: nil

  defp link(url, label, kind), do: %{url: url, label: label, kind: kind}

  defp parse_int(nil), do: nil
  defp parse_int(n) when is_integer(n), do: n

  defp parse_int(s) when is_binary(s) do
    case Integer.parse(s) do
      {n, _} -> n
      :error -> nil
    end
  end

  defp parse_int(_), do: nil

  defp empty_to_nil(""), do: nil
  defp empty_to_nil(nil), do: nil
  defp empty_to_nil(s) when is_binary(s), do: s

  @doc "Render glossary concepts with tier-aware definitions, respecting a char budget."
  @spec render_glossary([String.t()], path_tier(), pos_integer()) :: [String.t()]
  def render_glossary(concepts, tier, budget \\ @glossary_budget_chars) when is_list(concepts) do
    tier_key =
      case tier do
        :kid -> :kid
        :derivation -> :phd
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

            if used + line_len > budget do
              {used, acc}
            else
              {used + line_len, [line | acc]}
            end
        end
      end)

    Enum.reverse(lines)
  end
end
