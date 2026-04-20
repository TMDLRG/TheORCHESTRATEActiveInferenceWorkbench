defmodule WorkbenchWeb.Qwen.Presets do
  @moduledoc """
  Per-page-type preset chips for the Qwen drawer.

  Chips are pure data. The `QwenDrawer` JS hook reads them on every
  `qwen:page` event and re-renders the chip row so the learner always sees
  prompts appropriate to the page they're on.
  """

  @type chip :: %{id: String.t(), label: String.t(), prompt: String.t()}

  @doc """
  Return the chip row for a packet. Accepts the full packet so chips can
  react to episode state (e.g. labs with a live run gets different chips
  than labs idle).

  Also accepts a thin "pseudo packet" from `WorkbenchWeb.Qwen.Hook` that
  may lack fields like `guide_topic` or `episode`; this function derives
  them from `page_key` when possible so chip selection is identical whether
  called from the server-side Qwen controller or the handle_params hook.
  """
  @spec chips_for(map()) :: [chip()]
  def chips_for(%{page_type: page_type} = packet) do
    chips(page_type, normalize(packet))
  end

  def chips_for(_), do: default_chips()

  defp normalize(%{page_type: :guide, page_key: key} = p)
       when is_binary(key) and key != "" do
    Map.put_new(p, :guide_topic, atomize_topic(key))
  end

  defp normalize(p), do: p

  defp atomize_topic(s) when is_binary(s),
    do: s |> String.replace("-", "_") |> String.to_atom()

  defp atomize_topic(a) when is_atom(a), do: a

  # ---- per-page-type chips -----------------------------------------------

  defp chips(:session, _),
    do: [
      c("explain", "Explain this", "Explain the hero concept of this session in 3 sentences."),
      c("why", "Why does this matter?", "Why does this session matter in the arc of the chapter?"),
      c("math", "Show the math", "Walk me through the math behind this session, step by step."),
      c("lab", "Try it in a lab", "Which lab on this page should I try, and what beat should I start on?"),
      c("narrate", "🔊 Narrate", "Narrate your answer.")
    ]

  defp chips(:chapter, _),
    do: [
      c("arc", "Chapter arc", "Give me the arc of this chapter in 4 sentences."),
      c("start", "Where to start", "Which session should I start with, and why?"),
      c("eq", "Pick one equation", "Pick one equation from this chapter to learn first and justify the pick.")
    ]

  defp chips(:cookbook_recipe, _),
    do: [
      c("math", "Walk me through the math", "Walk me through the math of this recipe, symbol by symbol."),
      c("vs_session", "How is this different?", "How does this recipe differ from my current session — what's the bridge?"),
      c("run", "Run this recipe", "Which runtime parameters should I use on the first run, and what will I see?"),
      c("simplest", "Simplest version?", "What's the simplest toy version of this recipe I can reason about?")
    ]

  defp chips(:labs_run, %{episode: nil}),
    do: [
      c("predict", "What will happen?", "What will happen when I press Run? Walk through the first 3 ticks."),
      c("params", "Why these params?", "Why these parameters? What would be a sensible adjustment?"),
      c("fit", "Which world fits?", "Which world is the best fit for this spec, and why?")
    ]

  defp chips(:labs_run, _),
    do: episode_chips()

  defp chips(:studio_run, _), do: episode_chips()

  defp chips(:studio_agent, _),
    do: [
      c("summary", "Agent summary", "Summarise this agent's lifecycle and what it has learned."),
      c("dirichlet", "Dirichlet updates", "What has this agent learned from Dirichlet updates so far?"),
      c("next", "What should I try?", "What's a sensible next experiment with this agent?")
    ]

  defp chips(:equation, _),
    do: [
      c("break", "Break it down", "Break this equation down symbol by symbol in plain English."),
      c("deps", "What depends on it?", "Which other equations depend on this one — what's the chain?"),
      c("recipes", "Which recipes use it?", "Which cookbook recipes use this equation?")
    ]

  defp chips(:equations_index, _),
    do: [
      c("map", "Map of equations", "Give me a map of the equations by chapter in one paragraph."),
      c("first", "Learn one first", "If I could only learn one equation, which should it be and why?")
    ]

  defp chips(:guide, %{guide_topic: :blocks}),
    do: [
      c("curious", "Block for a curious agent", "Which block do I need for a curious agent? Explain the pipeline."),
      c("smallest", "Smallest useful topology", "What's the smallest useful topology I can drop on the Builder canvas?"),
      c("tour", "Tour the blocks", "Tour the 5 most important blocks in one paragraph.")
    ]

  defp chips(:guide, %{guide_topic: :cookbook}),
    do: [
      c("pick", "Pick a recipe for me", "Based on the real-world path, pick a cookbook recipe and explain why."),
      c("structure", "How recipes work", "How is a recipe card structured — what are the key fields?")
    ]

  defp chips(:guide, %{guide_topic: :studio}),
    do: [
      c("vs_labs", "Studio vs Labs", "Studio vs Labs — when do I use which?"),
      c("lifecycle", "Lifecycle model", "Walk me through the live / stopped / archived / trashed lifecycle.")
    ]

  defp chips(:guide, _),
    do: [
      c("summary", "Summarise this guide", "Summarise this guide topic in 3 bullets."),
      c("fit", "Where does it fit?", "Where does this fit in the bigger picture of the suite?")
    ]

  defp chips(:builder, _),
    do: [
      c("smallest", "Smallest useful graph", "Build the smallest useful graph that teaches one concept."),
      c("explain", "Explain the banner", "Explain the recipe banner at the top — what does this spec do?"),
      c("compile", "What will compile do?", "What will pressing Compile actually do under the hood?")
    ]

  defp chips(:learning_hub, _),
    do: [
      c("start", "Where to start", "Given my current progress, which chapter should I open next?"),
      c("paths", "Explain the paths", "Explain the four learning paths (kid / real / equation / derivation)."),
      c("path", "Pick my path", "Which path should I pick given I want to learn quickly?")
    ]

  defp chips(:labs_index, _),
    do: [
      c("cards", "Explain the cards", "Explain what each Labs card shows before I press Run."),
      c("diff", "Labs vs Studio", "How is Labs different from Studio?")
    ]

  defp chips(:studio_index, _),
    do: [
      c("started", "Get me started", "How do I get a first agent running in Studio?"),
      c("states", "State machine", "Walk me through the live / stopped / archived / trashed states.")
    ]

  defp chips(:studio_new, _),
    do: [
      c("flows", "3 flows", "Explain the three flows (Attach / Spec / Recipe) and which I should pick."),
      c("preflight", "Preflight check", "What does the preflight check verify?")
    ]

  defp chips(:studio_trash, _),
    do: [
      c("restore", "Restore safely", "What happens when I restore an agent, and what state does it come back in?"),
      c("empty", "Empty the trash", "What's the safe way to empty the trash?")
    ]

  defp chips(:glass_agent, _),
    do: [
      c("river", "Read the signal river", "Read the last 5 signals and tell me what the agent is doing."),
      c("eq", "Which equation?", "Which equation produced the most recent signal?")
    ]

  defp chips(:glass, _),
    do: [
      c("pick_agent", "Which agent?", "Which agent has the most interesting trace right now?"),
      c("read", "How to read Glass", "How do I read the Glass Engine display?")
    ]

  defp chips(:cookbook_index, _),
    do: [
      c("pick_level", "Pick a level", "Given my path, which level (L1-L5) should I start with?"),
      c("random", "Surprise me", "Pick one recipe at random and explain it in 3 sentences.")
    ]

  defp chips(:models, _),
    do: [
      c("overview", "Overview", "Give me an overview of the model-family taxonomy."),
      c("picks", "Starting picks", "Which 3 model families should I learn first?")
    ]

  defp chips(:world, _),
    do: [
      c("explain", "Explain the world", "Explain what this world is testing — what would a good agent do?"),
      c("try", "Try an action", "If I send action :forward, what happens?")
    ]

  defp chips(:home, _), do: default_chips()
  defp chips(_, _), do: default_chips()

  defp default_chips,
    do: [
      c("here", "Where am I?", "Where am I, and what's this page for?"),
      c("do", "What can I do?", "What can I do on this page?"),
      c("walk", "Walk me through", "Walk me through this page as if I just arrived.")
    ]

  defp episode_chips do
    [
      c("why", "Why that action?", "Why did the agent pick that action? Cite the live episode state."),
      c("depth", "Raise policy depth?", "What would change if I raised policy depth by 2?"),
      c("epistemic", "Epistemic or pragmatic?", "Is the agent being epistemic or pragmatic right now? Cite the posterior."),
      c("heatmap", "Read the heatmap", "What does the belief heatmap tell you about the agent's uncertainty?"),
      c("next", "Next move?", "Predict the agent's next move and explain the bet.")
    ]
  end

  defp c(id, label, prompt), do: %{id: id, label: label, prompt: prompt}
end
