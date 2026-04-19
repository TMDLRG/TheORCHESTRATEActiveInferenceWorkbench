defmodule ActiveInferenceCore.Equation do
  @moduledoc """
  A single extracted equation with strict source traceability.

  The schema follows the extraction ledger specified in the build brief.
  Every field is mandatory. `source_text_equation` is preserved verbatim
  (as best as Unicode text allows) from the book; `normalized_latex` is
  a rewritten form for rendering, but the original is kept so the reader
  can audit fidelity.
  """

  @enforce_keys [
    :id,
    :source_title,
    :chapter,
    :section,
    :equation_number,
    :source_text_equation,
    :normalized_latex,
    :symbols,
    :model_family,
    :model_type,
    :conceptual_role,
    :implementation_role,
    :dependencies,
    :verification_status,
    :verification_notes
  ]

  defstruct @enforce_keys

  @type model_type :: :general | :discrete | :continuous | :hybrid
  @type verification ::
          :verified_against_source
          | :verified_against_source_and_appendix
          | :extracted_uncertain
          | :unavailable

  @type t :: %__MODULE__{
          id: String.t(),
          source_title: String.t(),
          chapter: String.t(),
          section: String.t(),
          equation_number: String.t() | nil,
          source_text_equation: String.t(),
          normalized_latex: String.t(),
          symbols: [%{name: String.t(), meaning: String.t()}],
          model_family: String.t(),
          model_type: model_type,
          conceptual_role: String.t(),
          implementation_role: String.t(),
          dependencies: [String.t()],
          verification_status: verification,
          verification_notes: String.t()
        }
end
