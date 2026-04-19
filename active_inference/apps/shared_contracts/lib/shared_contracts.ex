defmodule SharedContracts do
  @moduledoc """
  Explicit Markov-blanket crossing contracts.

  This app is intentionally tiny. It contains only the two packet types that
  may cross between the world plane (`WorldPlane`) and the agent plane
  (`AgentPlane`), plus a blanket-configuration record describing which signals
  are exposed.

  ## Why its own app?

  Keeping the blanket contracts in a separate OTP application is an
  *architectural* guarantee: because neither `:world_plane` nor `:agent_plane`
  depend on one another, the only symbols they can share are those exported by
  this application. If someone adds a cross-plane dependency later, the
  umbrella compilation will refuse it.

  > See the ADR in `docs/ADR.md` (Architecture Decision Record) and the
  > architecture audit in `test/shared_contracts/plane_separation_test.exs`.
  """
end
