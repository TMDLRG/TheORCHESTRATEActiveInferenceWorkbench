defmodule WorkbenchWeb.GuideLive.Blocks do
  @moduledoc """
  Block catalogue — renders every node type currently registered in
  `WorldModels.Spec.Topology.node_types/0`. Regenerates on every mount
  so new blocks appear automatically.
  """
  use WorkbenchWeb, :live_view

  alias WorldModels.Spec.Topology

  @impl true
  def mount(_params, _session, socket) do
    blocks =
      Topology.node_types()
      |> Enum.sort_by(fn {id, _} -> id end)
      |> Enum.map(fn {id, spec} ->
        %{
          id: id,
          description: Map.get(spec, :description, ""),
          inputs: Map.get(spec, :ports, %{}) |> Map.get(:in, %{}),
          outputs: Map.get(spec, :ports, %{}) |> Map.get(:out, %{}),
          category: category_for(id)
        }
      end)

    {:ok,
     assign(socket,
       page_title: "Block catalogue",
       blocks: blocks,
       qwen_page_type: :guide,
       qwen_page_key: "blocks",
       qwen_page_title: "Block catalogue"
     )}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <h1>Block catalogue</h1>
    <p style="color:#9cb0d6;max-width:780px;">
      Every block you can drop onto the Builder canvas. Each is backed by a real
      JIDO module (<code class="inline">Jido.Action</code>, <code class="inline">Jido.Skill</code>,
      or <code class="inline">Jido.Agent</code>); params round-trip through server-side
      Zoi validation on every edit.
    </p>

    <%= for {cat, blocks} <- Enum.group_by(@blocks, & &1.category) |> Enum.sort() do %>
      <div class="card">
        <h2><%= category_title(cat) %></h2>
        <table>
          <thead>
            <tr>
              <th>Block</th>
              <th>Description</th>
              <th>Inputs</th>
              <th>Outputs</th>
            </tr>
          </thead>
          <tbody>
            <%= for b <- blocks do %>
              <tr>
                <td><code class="inline"><%= b.id %></code></td>
                <td><%= b.description %></td>
                <td>
                  <%= for {port, type} <- b.inputs do %>
                    <span class="tag general"><%= port %>:<%= type %></span>
                  <% end %>
                </td>
                <td>
                  <%= for {port, type} <- b.outputs do %>
                    <span class="tag verified"><%= port %>:<%= type %></span>
                  <% end %>
                </td>
              </tr>
            <% end %>
          </tbody>
        </table>
      </div>
    <% end %>
    """
  end

  defp category_for(id) do
    cond do
      id in ~w(likelihood_matrix transition_matrix preference_vector prior_vector bundle_assembler bundle) ->
        :generative_model

      id in ~w(perceive plan act sophisticated_planner dirichlet_a_learner dirichlet_b_learner) ->
        :action

      id in ~w(skill workflow epistemic_preference) ->
        :skill

      id in ~w(archetype equation) ->
        :reference

      true ->
        :other
    end
  end

  defp category_title(:generative_model), do: "Generative-model blocks (A, B, C, D, Bundle)"
  defp category_title(:action), do: "Action blocks (Perceive / Plan / Act / Learn)"
  defp category_title(:skill), do: "Skill & workflow blocks"
  defp category_title(:reference), do: "Reference & scaffolding blocks"
  defp category_title(:other), do: "Other"
end
