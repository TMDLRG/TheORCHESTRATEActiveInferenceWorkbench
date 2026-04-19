defmodule WorkbenchWeb.LibreChatAgents do
  @moduledoc """
  Loads `priv/librechat/agents.json`, written by the seeder
  (`tools/librechat_seed/export_agent_ids.py`).  Maps workshop slugs
  (e.g. `aif-tutor-real`, `aif-lab-bayes`) to LibreChat agent ids
  (e.g. `agent_HAHH4bT0QNGaOlxKQnyH9`).

  Looked up at request time by `WorkbenchWeb.ChatBridgeController` to build
  `/c/new?agent_id=...` deep-links.  If the JSON file is absent (seeder hasn't
  run yet), every lookup returns `nil` and the bridge falls back to the
  prompt-only URL — no broken UI, just no auto-attached agent.  The file is
  gitignored; `priv/librechat/agents.json.example` documents the shape.

  Lab slug → agent slug pairing is here too (`agent_for_lab/1`) so a session
  page can derive the right coach without each LiveView duplicating the map.
  """

  # Every slug the rest of the suite uses for a lab (hyphenated, compact,
  # or short form) maps here.  Keep the keys synchronised with
  # `session.ex`'s `lab_file/1` head so deep-links never miss.
  @lab_to_agent %{
    "bayeschips" => "aif-lab-bayes",
    "bayes-chips" => "aif-lab-bayes",
    "bayes" => "aif-lab-bayes",
    "pomdp" => "aif-lab-pomdp",
    "pomdp-machine" => "aif-lab-pomdp",
    "forge" => "aif-lab-forge",
    "free-energy-forge" => "aif-lab-forge",
    "tower" => "aif-lab-tower",
    "laplace-tower" => "aif-lab-tower",
    "anatomy" => "aif-lab-anatomy",
    "anatomy-studio" => "aif-lab-anatomy",
    "atlas" => "aif-lab-atlas",
    "frog" => "aif-lab-frog",
    "jumping-frog" => "aif-lab-frog"
  }

  @doc "Return the labels-friendly short name for a lab (for UI copy)."
  def lab_short("bayes" <> _), do: "BayesChips"
  def lab_short("pomdp" <> _), do: "POMDP Machine"
  def lab_short("free-energy" <> _), do: "Free Energy Forge"
  def lab_short("forge"), do: "Free Energy Forge"
  def lab_short("laplace" <> _), do: "Laplace Tower"
  def lab_short("tower"), do: "Laplace Tower"
  def lab_short("anatomy" <> _), do: "Anatomy Studio"
  def lab_short("atlas"), do: "Cortical Atlas"
  def lab_short("jumping-frog"), do: "Jumping Frog"
  def lab_short("frog"), do: "Jumping Frog"
  def lab_short(s) when is_binary(s), do: s
  def lab_short(_), do: ""

  @doc "Return the full slug → agent_id map (loaded fresh from disk)."
  def all do
    case File.read(path()) do
      {:ok, body} -> Jason.decode!(body)
      _ -> %{}
    end
  end

  @doc "Return the agent_id for a slug (e.g. `aif-tutor-real`), or nil."
  def get(slug) when is_binary(slug), do: Map.get(all(), slug)
  def get(_), do: nil

  @doc "Default tutor slug for a learner path (`:real` is the workshop default)."
  def default_for_path(:kid), do: "aif-tutor-story"
  def default_for_path(:real), do: "aif-tutor-real"
  def default_for_path(:equation), do: "aif-tutor-equation"
  def default_for_path(:derivation), do: "aif-tutor-derivation"
  def default_for_path(_), do: "aif-tutor-real"

  @doc "Coach agent slug for a lab id, or nil if no coach is registered."
  def agent_for_lab(lab_id) when is_binary(lab_id), do: Map.get(@lab_to_agent, lab_id)
  def agent_for_lab(_), do: nil

  defp path do
    Path.join([Application.app_dir(:workbench_web, "priv"), "librechat", "agents.json"])
  end
end
