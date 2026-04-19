defmodule AgentPlane.Instance do
  @moduledoc """
  Value-object describing a Studio-tracked agent instance.  S2 of the
  Studio plan.

  Persisted by `AgentPlane.Instances` in the `:agent_plane_instances`
  Mnesia table.  See `WorldModels.EventLog.Setup` for the record layout.

  Lifecycle states (see STUDIO_PLAN.md D1):

      :live -> :stopped -> :archived -> :trashed -> GONE

  Each state transition is performed via `AgentPlane.Instances.transition/2`
  and writes an `updated_at_usec` stamp synchronously.
  """

  @enforce_keys [:agent_id, :spec_id, :source, :state]
  defstruct agent_id: nil,
            spec_id: nil,
            source: :studio,
            recipe_slug: nil,
            pid: nil,
            state: :live,
            name: nil,
            started_at_usec: nil,
            updated_at_usec: nil

  @type state :: :live | :stopped | :archived | :trashed
  @type source :: :builder | :studio | :labs | :cookbook | :world | :other

  @type t :: %__MODULE__{
          agent_id: String.t(),
          spec_id: String.t(),
          source: source(),
          recipe_slug: String.t() | nil,
          pid: pid() | nil,
          state: state(),
          name: String.t() | nil,
          started_at_usec: integer() | nil,
          updated_at_usec: integer() | nil
        }

  @valid_states [:live, :stopped, :archived, :trashed]

  @doc "Returns true if `next_state` is a legal transition from `current`."
  @spec valid_transition?(state(), state()) :: boolean()
  def valid_transition?(:live, next), do: next in [:stopped, :archived, :trashed]
  def valid_transition?(:stopped, next), do: next in [:live, :archived, :trashed]
  def valid_transition?(:archived, next), do: next in [:live, :trashed, :stopped]
  def valid_transition?(:trashed, next), do: next in [:stopped, :archived]
  def valid_transition?(_, _), do: false

  @doc "Returns the list of all legal states."
  @spec states() :: [state()]
  def states, do: @valid_states
end
