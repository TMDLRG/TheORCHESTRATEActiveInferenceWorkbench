defmodule AgentPlane.JidoInstance do
  @moduledoc """
  A JIDO runtime instance scoped to the agent plane.

  This is the `use Jido, otp_app: :agent_plane` instance module described in
  the JIDO README. It is the *actual* JIDO runtime — `start_agent/2`,
  `whereis/1`, `list_agents/0` all route through the JIDO-provided functions,
  not a local reimplementation.
  """

  use Jido, otp_app: :agent_plane
end
