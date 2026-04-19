defmodule SharedContracts.ActionPacket do
  @moduledoc """
  The only payload the agent is allowed to send to the world.

  ## Fields

    * `:t` — the time-step the agent intends this action for.
    * `:action` — a single atom from the blanket's `action_vocabulary`.
    * `:agent_id` — the agent's JIDO id (opaque to the world).

  No belief state, policy distributions, or free-energy values are ever
  transmitted to the world plane. Those remain inside the agent.
  """

  @enforce_keys [:t, :action, :agent_id]
  defstruct [:t, :action, :agent_id]

  @type t :: %__MODULE__{
          t: non_neg_integer(),
          action: atom(),
          agent_id: String.t()
        }

  @doc """
  Construct an action packet, verifying that the action is in the blanket's
  action vocabulary.
  """
  @spec new(%{
          t: non_neg_integer(),
          action: atom(),
          agent_id: String.t(),
          blanket: SharedContracts.Blanket.t()
        }) :: t()
  def new(%{t: t, action: action, agent_id: agent_id, blanket: blanket}) do
    unless action in blanket.action_vocabulary do
      raise ArgumentError,
            "blanket violation: action #{inspect(action)} is not in the blanket's action vocabulary #{inspect(blanket.action_vocabulary)}"
    end

    %__MODULE__{t: t, action: action, agent_id: agent_id}
  end
end
