defmodule ActiveInferenceCore.Equations do
  @moduledoc """
  Registry of equations extracted from the source material:

    "Active Inference: The Free Energy Principle in Mind, Brain, and Behavior"
    Thomas Parr, Giovanni Pezzulo, Karl J. Friston.  MIT Press, 2022.
    Creative Commons CC BY-NC-ND. ISBN 9780262045353.

  ## Extraction policy

  Each record preserves the equation **verbatim** from the source text (modulo
  Unicode rendering of combining marks and ligatures). A second `normalized_latex`
  form is provided for display, but the verbatim string is never overwritten.

  ## Verification status

  Every entry carries a verification tag. The common cases are:

    * `:verified_against_source_and_appendix` — the chapter form and the
      Appendix-B form were both inspected and reconcile cleanly.
    * `:verified_against_source` — only the chapter form was inspected.
    * `:extracted_uncertain` — the text extraction left ambiguity
      (e.g., unicode glyph loss) and the record is flagged.

  ## Coverage

  This registry is not exhaustive for every enumerated equation in the book.
  It targets those relevant to Active Inference agents, generative models,
  model types, inference, free energy, expected free energy, state estimation,
  policy inference, message passing, planning, discrete-time models,
  continuous-time models, and hybrid models — per the build brief.
  """

  alias ActiveInferenceCore.Equation

  @source_title "Parr, Pezzulo, Friston (2022), Active Inference, MIT Press"

  @doc "Return every equation record in stable order."
  @spec all() :: [Equation.t()]
  def all, do: records()

  @doc "Return a single record by id, or `nil` if missing."
  @spec fetch(String.t()) :: Equation.t() | nil
  def fetch(id), do: Enum.find(all(), &(&1.id == id))

  @doc "Filter by model_type: :general | :discrete | :continuous | :hybrid"
  @spec by_type(Equation.model_type()) :: [Equation.t()]
  def by_type(type), do: Enum.filter(all(), &(&1.model_type == type))

  @doc "Filter by family tag (string) — e.g. \"Variational Free Energy\"."
  @spec by_family(String.t()) :: [Equation.t()]
  def by_family(family), do: Enum.filter(all(), &(&1.model_family == family))

  # ---------------------------------------------------------------------------
  # Registry
  # ---------------------------------------------------------------------------

  defp records do
    [
      # ---- Chapter 2: The Low Road to Active Inference ----
      %Equation{
        id: "eq_2_1_bayes_rule",
        source_title: @source_title,
        chapter: "2 The Low Road to Active Inference",
        section: "2.2 Bayesian Inference",
        equation_number: "2.1",
        source_text_equation: "P(x | y) = P(x)P(y | x) / P(y)",
        normalized_latex: "P(x \\mid y) \\;=\\; \\frac{P(x)\\,P(y \\mid x)}{P(y)}",
        symbols: [
          %{name: "x", meaning: "hidden state"},
          %{name: "y", meaning: "observation / outcome"},
          %{name: "P(x)", meaning: "prior over hidden states"},
          %{name: "P(y|x)", meaning: "likelihood of outcomes given states"},
          %{name: "P(y)", meaning: "marginal likelihood / evidence"},
          %{name: "P(x|y)", meaning: "posterior over states"}
        ],
        model_family: "Bayesian Inference (foundational)",
        model_type: :general,
        conceptual_role:
          "Core identity defining the posterior in terms of prior, likelihood, and marginal.",
        implementation_role:
          "Basis for the exact posterior computation used as ground truth in tests.",
        dependencies: [],
        verification_status: :verified_against_source,
        verification_notes:
          "Appears verbatim at book line 775–780. Marginal form appears in equation 2.2."
      },
      %Equation{
        id: "eq_2_2_marginal_likelihood",
        source_title: @source_title,
        chapter: "2 The Low Road to Active Inference",
        section: "2.2 Bayesian Inference",
        equation_number: "2.2",
        source_text_equation: "P(y = jumps) = Σ_x P(x, y = jumps) = Σ_x P(x) P(y = jumps | x)",
        normalized_latex: "P(y) \\;=\\; \\sum_x P(x, y) \\;=\\; \\sum_x P(x)\\,P(y \\mid x)",
        symbols: [
          %{name: "Σ_x", meaning: "sum over all hidden-state values"}
        ],
        model_family: "Bayesian Inference (foundational)",
        model_type: :general,
        conceptual_role: "Marginal over hidden states, yielding the evidence.",
        implementation_role:
          "Target quantity that variational free energy upper-bounds in -log form.",
        dependencies: ["eq_2_1_bayes_rule"],
        verification_status: :verified_against_source,
        verification_notes: "Book line 862–876."
      },
      %Equation{
        id: "eq_2_3_kl_divergence",
        source_title: @source_title,
        chapter: "2 The Low Road to Active Inference",
        section: "2.3 Bayesian Surprise",
        equation_number: "2.3",
        source_text_equation: "D_KL[Q(x) || P(x)] ≜ E_{Q(x)}[ ln Q(x) − ln P(x) ]",
        normalized_latex:
          "D_{KL}[Q(x)\\,\\|\\,P(x)] \\;\\triangleq\\; \\mathbb{E}_{Q(x)}\\!\\left[\\ln Q(x) - \\ln P(x)\\right]",
        symbols: [
          %{name: "Q(x)", meaning: "approximate / variational distribution"},
          %{name: "P(x)", meaning: "reference distribution"},
          %{name: "E_Q", meaning: "expectation under Q"}
        ],
        model_family: "Information Theory",
        model_type: :general,
        conceptual_role: "Quantifies dissimilarity between Q and P; nonnegative; asymmetric.",
        implementation_role:
          "Used throughout: complexity term of F, risk term of G, message-passing fidelity.",
        dependencies: [],
        verification_status: :verified_against_source,
        verification_notes: "Book line 952–956."
      },
      %Equation{
        id: "eq_2_5_variational_free_energy",
        source_title: @source_title,
        chapter: "2 The Low Road to Active Inference",
        section: "2.6 Variational Free Energy",
        equation_number: "2.5",
        source_text_equation: """
        F[Q, y]  =  −E_{Q(x)}[ln P(y, x)]  −  H[Q(x)]           (Energy − Entropy)
                 =  D_KL[Q(x) || P(x)]  −  E_{Q(x)}[ln P(y|x)]  (Complexity − Accuracy)
                 =  D_KL[Q(x) || P(x|y)]  −  ln P(y)             (Divergence − Evidence)
        """,
        normalized_latex: """
        F[Q,y] = \\underbrace{-\\mathbb{E}_{Q(x)}[\\ln P(y,x)]}_{\\text{energy}} - \\underbrace{H[Q(x)]}_{\\text{entropy}}
              = \\underbrace{D_{KL}[Q(x)\\|P(x)]}_{\\text{complexity}} - \\underbrace{\\mathbb{E}_{Q(x)}[\\ln P(y\\mid x)]}_{\\text{accuracy}}
              = \\underbrace{D_{KL}[Q(x)\\|P(x\\mid y)]}_{\\text{divergence}} - \\underbrace{\\ln P(y)}_{\\text{evidence}}
        """,
        symbols: [
          %{name: "F", meaning: "variational free energy functional"},
          %{name: "H[Q]", meaning: "Shannon entropy of Q"}
        ],
        model_family: "Variational Free Energy",
        model_type: :general,
        conceptual_role:
          "Upper bound on surprise; minimised by perception (Q updates) and action (y changes).",
        implementation_role:
          "The objective agents minimise. Discrete-time implementation uses the linear-algebraic form in eq. 4.11 / B.4.",
        dependencies: ["eq_2_3_kl_divergence", "eq_2_2_marginal_likelihood"],
        verification_status: :verified_against_source_and_appendix,
        verification_notes:
          "Book lines 1299–1327. Reconciled with Appendix B eq. B.2 and B.4 for the POMDP form."
      },
      %Equation{
        id: "eq_2_6_expected_free_energy",
        source_title: @source_title,
        chapter: "2 The Low Road to Active Inference",
        section: "2.8 What Is Expected Free Energy?",
        equation_number: "2.6",
        source_text_equation: """
        G(π) = −E_{Q(x̃,ỹ|π)}[ D_KL[Q(x̃|ỹ,π) || Q(x̃|π)] ] − E_{Q(ỹ|π)}[ln P(ỹ|C)]
                            (information gain)                  (pragmatic value)
             = E_{Q(x̃|π)}[ H[P(ỹ|x̃)] ] + D_KL[Q(ỹ|π) || P(ỹ|C)]
                  (expected ambiguity)        (risk over outcomes)
             ≤ E_{Q(x̃|π)}[ H[P(ỹ|x̃)] ] + D_KL[Q(x̃|π) || P(x̃|C)]
                  (expected ambiguity)        (risk over states)
             = −E_{Q(x̃,ỹ|π)}[ln P(x̃,ỹ|C)] − H[Q(x̃|π)]
                          (expected energy)     (entropy)

        Q(x̃, ỹ | π)  ≜  Q(x̃|π) P(ỹ|x̃)
        """,
        normalized_latex: """
        G(\\pi) = \\underbrace{-\\mathbb{E}_{Q(\\tilde x,\\tilde y\\mid\\pi)}[D_{KL}[Q(\\tilde x\\mid\\tilde y,\\pi)\\|Q(\\tilde x\\mid\\pi)]]}_{\\text{info gain}} - \\underbrace{\\mathbb{E}_{Q(\\tilde y\\mid\\pi)}[\\ln P(\\tilde y\\mid C)]}_{\\text{pragmatic value}}
             = \\underbrace{\\mathbb{E}_{Q(\\tilde x\\mid\\pi)}[H[P(\\tilde y\\mid\\tilde x)]]}_{\\text{expected ambiguity}} + \\underbrace{D_{KL}[Q(\\tilde y\\mid\\pi)\\|P(\\tilde y\\mid C)]}_{\\text{risk (outcomes)}}
        """,
        symbols: [
          %{name: "G(π)", meaning: "expected free energy of a policy π"},
          %{name: "x̃ / ỹ", meaning: "trajectories of states / outcomes"},
          %{name: "C", meaning: "parameters encoding preferences over outcomes"}
        ],
        model_family: "Expected Free Energy",
        model_type: :general,
        conceptual_role:
          "Scoring functional for policies; decomposes into epistemic and pragmatic drives.",
        implementation_role:
          "Linear-algebraic form in eq. 4.10 and B.30 is what the agent plane actually evaluates.",
        dependencies: ["eq_2_5_variational_free_energy"],
        verification_status: :verified_against_source_and_appendix,
        verification_notes: "Book lines 1545–1584. Reconciled with Appendix B eq. B.26–B.30."
      },

      # ---- Chapter 3: The High Road ----
      %Equation{
        id: "eq_3_1_entropy_surprise",
        source_title: @source_title,
        chapter: "3 The High Road to Active Inference",
        section: "3.3 Self-organization and surprise",
        equation_number: "3.1",
        source_text_equation: "H[P(y)] = E_{P(y)}[ℑ(y)] = −E_{P(y)}[ln P(y)]",
        normalized_latex:
          "H[P(y)] \\;=\\; \\mathbb{E}_{P(y)}[\\mathfrak{I}(y)] \\;=\\; -\\mathbb{E}_{P(y)}[\\ln P(y)]",
        symbols: [
          %{name: "H[P]", meaning: "Shannon entropy of P"},
          %{name: "ℑ(y)", meaning: "surprise (−log evidence) of outcome y"}
        ],
        model_family: "Self-organization / Markov blankets",
        model_type: :general,
        conceptual_role: "Entropy as the long-run average of surprise.",
        implementation_role:
          "Motivates why agents must minimise surprise on average; framed differently in discrete-time code.",
        dependencies: [],
        verification_status: :verified_against_source,
        verification_notes: "Book line 2270–2272."
      },
      %Equation{
        id: "eq_3_2_fe_surprise_evidence",
        source_title: @source_title,
        chapter: "3 The High Road to Active Inference",
        section: "3.4.1 Variational Free Energy, Model Evidence, and Surprise",
        equation_number: "3.2",
        source_text_equation: "ℑ(y|m) = −ln P(y|m) ≤ D_KL[Q(x) || P(x|y,m)] − ln P(y|m)",
        normalized_latex:
          "\\underbrace{\\mathfrak{I}(y\\mid m)}_{\\text{surprise}} \\;=\\; \\underbrace{-\\ln P(y\\mid m)}_{\\text{model evidence}} \\;\\le\\; \\underbrace{D_{KL}[Q(x)\\|P(x\\mid y,m)] - \\ln P(y\\mid m)}_{\\text{variational free energy}}",
        symbols: [%{name: "m", meaning: "generative model index"}],
        model_family: "Variational Free Energy",
        model_type: :general,
        conceptual_role: "Formal equivalence of surprise minimisation and evidence maximisation.",
        implementation_role: "Justifies F as the agent's training objective at every step.",
        dependencies: ["eq_2_5_variational_free_energy"],
        verification_status: :verified_against_source,
        verification_notes: "Book lines 2404–2417."
      },

      # ---- Chapter 4: Generative Models ----
      %Equation{
        id: "eq_4_5_pomdp_likelihood",
        source_title: @source_title,
        chapter: "4 The Generative Models of Active Inference",
        section: "4.4.1 Partially Observable Markov Decision Processes",
        equation_number: "4.5",
        source_text_equation: "P(o_τ | s_τ) = Cat(A);   A_{ij} = P(o_τ = i | s_τ = j)",
        normalized_latex:
          "P(o_\\tau \\mid s_\\tau) = \\mathrm{Cat}(A),\\qquad A_{ij} = P(o_\\tau = i \\mid s_\\tau = j)",
        symbols: [
          %{name: "o_τ", meaning: "observation at time τ"},
          %{name: "s_τ", meaning: "hidden state at time τ"},
          %{name: "A", meaning: "likelihood matrix"}
        ],
        model_family: "POMDP generative model",
        model_type: :discrete,
        conceptual_role: "Maps hidden states to outcomes (perception channel).",
        implementation_role: "Implemented as `ActiveInferenceCore.DiscreteTime.likelihood/2`.",
        dependencies: [],
        verification_status: :verified_against_source,
        verification_notes: "Book lines 3294–3299."
      },
      %Equation{
        id: "eq_4_6_pomdp_prior_over_states",
        source_title: @source_title,
        chapter: "4 The Generative Models of Active Inference",
        section: "4.4.1 Partially Observable Markov Decision Processes",
        equation_number: "4.6",
        source_text_equation: """
        P(s̃|π) = P(s_1) Π_{τ=1}^{T-1} P(s_{τ+1} | s_τ, π)
        P(s_1) = Cat(D)
        P(s_{τ+1} | s_τ, π) = Cat(B^π_τ)
        """,
        normalized_latex: """
        P(\\tilde s\\mid\\pi) = P(s_1)\\prod_{\\tau=1}^{T-1} P(s_{\\tau+1}\\mid s_\\tau,\\pi),\\quad
        P(s_1)=\\mathrm{Cat}(D),\\quad P(s_{\\tau+1}\\mid s_\\tau,\\pi)=\\mathrm{Cat}(B^\\pi_\\tau)
        """,
        symbols: [
          %{name: "D", meaning: "initial-state prior"},
          %{name: "B^π_τ", meaning: "policy-conditioned transition matrix at time τ"}
        ],
        model_family: "POMDP generative model",
        model_type: :discrete,
        conceptual_role: "Prior trajectory under a policy.",
        implementation_role: "Used to roll out state beliefs under each candidate policy.",
        dependencies: ["eq_4_5_pomdp_likelihood"],
        verification_status: :verified_against_source,
        verification_notes: "Book lines 3304–3318."
      },
      %Equation{
        id: "eq_4_7_policy_prior_and_efe",
        source_title: @source_title,
        chapter: "4 The Generative Models of Active Inference",
        section: "4.4.1 Partially Observable Markov Decision Processes",
        equation_number: "4.7",
        source_text_equation: """
        P(π) = Cat(π_0)
        π_0 = σ(−G)
        G_π = G(π) = −E_{Q̃}[D_KL[Q(s̃|õ,π) || Q(s̃|π)]] − E_{Q̃}[ln P(õ|C)]
        Q(o_τ, s_τ | π) ≜ P(o_τ|s_τ) Q(s_τ|π)
        """,
        normalized_latex: """
        P(\\pi)=\\mathrm{Cat}(\\pi_0),\\quad \\pi_0=\\sigma(-G),\\quad
        G(\\pi) = -\\mathbb{E}_{\\tilde Q}[D_{KL}[Q(\\tilde s\\mid\\tilde o,\\pi)\\|Q(\\tilde s\\mid\\pi)]] - \\mathbb{E}_{\\tilde Q}[\\ln P(\\tilde o\\mid C)]
        """,
        symbols: [
          %{name: "π", meaning: "policy index"},
          %{name: "σ", meaning: "softmax (normalised exponential)"}
        ],
        model_family: "Expected Free Energy",
        model_type: :discrete,
        conceptual_role: "EFE supplies the prior over policies.",
        implementation_role:
          "Provides the prior term in eq. 4.14 for the policy posterior update.",
        dependencies: ["eq_2_6_expected_free_energy"],
        verification_status: :verified_against_source_and_appendix,
        verification_notes:
          "Book lines 3332–3343. Appendix B eq. B.7–B.9 gives the numerically-equivalent update."
      },
      %Equation{
        id: "eq_4_10_efe_linear_algebra",
        source_title: @source_title,
        chapter: "4 The Generative Models of Active Inference",
        section: "4.4.1 Partially Observable Markov Decision Processes",
        equation_number: "4.10",
        source_text_equation: """
        π_0 = σ(−G)
        G_π = H · s^π_τ + o^π_τ · ς^π_τ
        ς^π_τ = ln o^π_τ − ln C_τ
        H = −diag(A · ln A)
        P(o_τ|C) = Cat(C_τ)
        Q(o_τ|π) = Cat(o^π_τ),  o^π_τ = A s^π_τ
        Q(s_τ|π) = Cat(s^π_τ)
        Q(s_τ) = Cat(s_τ),   s_τ = Σ_π π_π s^π_τ
        """,
        normalized_latex: """
        \\begin{aligned}
        \\pi_0 &= \\sigma(-G),\\quad G_\\pi = H\\cdot s^\\pi_\\tau + o^\\pi_\\tau\\cdot\\varsigma^\\pi_\\tau,\\\\
        \\varsigma^\\pi_\\tau &= \\ln o^\\pi_\\tau - \\ln C_\\tau,\\quad H = -\\mathrm{diag}(A\\cdot\\ln A),\\\\
        o^\\pi_\\tau &= A\\,s^\\pi_\\tau
        \\end{aligned}
        """,
        symbols: [
          %{name: "H", meaning: "per-state ambiguity vector"},
          %{name: "ς^π_τ", meaning: "risk vector over outcomes"}
        ],
        model_family: "Expected Free Energy",
        model_type: :discrete,
        conceptual_role: "Operational form of G for numerical evaluation.",
        implementation_role:
          "Implemented as `ActiveInferenceCore.DiscreteTime.expected_free_energy/4` in the agent plane.",
        dependencies: ["eq_4_7_policy_prior_and_efe"],
        verification_status: :verified_against_source_and_appendix,
        verification_notes:
          "Book lines 3450–3466. Appendix B eq. B.28–B.30 gives the same form per time-step."
      },
      %Equation{
        id: "eq_4_11_vfe_linear_algebra",
        source_title: @source_title,
        chapter: "4 The Generative Models of Active Inference",
        section: "4.4.1 Partially Observable Markov Decision Processes",
        equation_number: "4.11",
        source_text_equation: """
        F = π · F
        F_π = Σ_τ F_{πτ}
        F_{πτ} = s^π_τ · ( ln s^π_τ − ln A · o_τ − ln B^π_τ s^π_{τ−1} )
        """,
        normalized_latex: """
        F = \\pi\\cdot F,\\quad F_\\pi = \\sum_\\tau F_{\\pi\\tau},\\quad
        F_{\\pi\\tau} = s^\\pi_\\tau\\cdot(\\ln s^\\pi_\\tau - \\ln A\\cdot o_\\tau - \\ln B^\\pi_\\tau s^\\pi_{\\tau-1})
        """,
        symbols: [
          %{name: "F", meaning: "variational free energy over policies"},
          %{name: "F_π", meaning: "per-policy VFE"},
          %{name: "F_πτ", meaning: "per-(policy,time) VFE contribution"}
        ],
        model_family: "Variational Free Energy",
        model_type: :discrete,
        conceptual_role: "Operational form of F for discrete-time POMDPs.",
        implementation_role:
          "Implemented as `ActiveInferenceCore.DiscreteTime.variational_free_energy/5`.",
        dependencies: ["eq_4_6_pomdp_prior_over_states", "eq_4_5_pomdp_likelihood"],
        verification_status: :verified_against_source_and_appendix,
        verification_notes: "Book lines 3473–3480. Reconciled with Appendix B eq. B.4."
      },
      %Equation{
        id: "eq_4_12_mean_field",
        source_title: @source_title,
        chapter: "4 The Generative Models of Active Inference",
        section: "4.4.1 Partially Observable Markov Decision Processes",
        equation_number: "4.12",
        source_text_equation: "Q(s̃|π) = Π_τ Q(s_τ|π)",
        normalized_latex: "Q(\\tilde s\\mid\\pi) \\;=\\; \\prod_\\tau Q(s_\\tau\\mid\\pi)",
        symbols: [],
        model_family: "Variational Inference",
        model_type: :discrete,
        conceptual_role: "Mean-field assumption: factorise posterior over time-points.",
        implementation_role:
          "Permits per-time-step updates in eq. 4.13 instead of full joint optimisation.",
        dependencies: ["eq_4_11_vfe_linear_algebra"],
        verification_status: :verified_against_source,
        verification_notes: "Book lines 3484–3487."
      },
      %Equation{
        id: "eq_4_13_state_belief_update",
        source_title: @source_title,
        chapter: "4 The Generative Models of Active Inference",
        section: "4.4.2 Active Inference in a POMDP",
        equation_number: "4.13",
        source_text_equation: """
        s^π_τ = σ(v^π_τ)
        v̇^π_τ = ε^π_τ ≜ −∇_s F_{πτ}
              = ln A·o_τ + ln B^π_τ s^π_{τ−1} + ln B^π_{τ+1} · s^π_{τ+1} − ln s^π_τ
        """,
        normalized_latex: """
        \\begin{aligned}
        s^\\pi_\\tau &= \\sigma(v^\\pi_\\tau),\\\\
        \\dot v^\\pi_\\tau &= \\varepsilon^\\pi_\\tau \\triangleq -\\nabla_s F_{\\pi\\tau} \\\\
                           &= \\ln A\\cdot o_\\tau + \\ln B^\\pi_\\tau s^\\pi_{\\tau-1} + \\ln B^\\pi_{\\tau+1}\\cdot s^\\pi_{\\tau+1} - \\ln s^\\pi_\\tau
        \\end{aligned}
        """,
        symbols: [
          %{name: "v^π_τ", meaning: "log-posterior auxiliary (depolarisation)"},
          %{name: "ε^π_τ", meaning: "state prediction error"}
        ],
        model_family: "Variational Message Passing",
        model_type: :discrete,
        conceptual_role: "Gradient-descent message passing for state beliefs.",
        implementation_role:
          "Implemented as `ActiveInferenceCore.DiscreteTime.update_state_beliefs/6`.",
        dependencies: ["eq_4_11_vfe_linear_algebra", "eq_4_12_mean_field"],
        verification_status: :verified_against_source_and_appendix,
        verification_notes:
          "Book lines 3509–3515. Appendix B eq. B.5 gives the equivalent gradient formula."
      },
      %Equation{
        id: "eq_4_14_policy_posterior",
        source_title: @source_title,
        chapter: "4 The Generative Models of Active Inference",
        section: "4.4.2 Active Inference in a POMDP",
        equation_number: "4.14",
        source_text_equation: "∇_π F = 0 ⇔ π = σ(−G − F)",
        normalized_latex: "\\nabla_\\pi F = 0 \\;\\Leftrightarrow\\; \\pi = \\sigma(-G - F)",
        symbols: [
          %{name: "π (vec)", meaning: "posterior over policies"},
          %{name: "F (vec)", meaning: "per-policy VFE vector"},
          %{name: "G (vec)", meaning: "per-policy EFE vector"}
        ],
        model_family: "Policy Inference",
        model_type: :discrete,
        conceptual_role: "Posterior over policies combines present VFE with prospective EFE.",
        implementation_role:
          "Implemented as `ActiveInferenceCore.DiscreteTime.policy_posterior/2`.",
        dependencies: ["eq_4_11_vfe_linear_algebra", "eq_4_10_efe_linear_algebra"],
        verification_status: :verified_against_source_and_appendix,
        verification_notes:
          "Book lines 3519–3521. Appendix B eq. B.9 agrees (the E habit vector is optional)."
      },

      # ---- Chapter 7: Discrete-time Active Inference ----
      %Equation{
        id: "eq_7_4_efe_epistemic_pragmatic",
        source_title: @source_title,
        chapter: "7 Active Inference in Discrete Time",
        section: "7.3 Decision-Making and Planning as Inference",
        equation_number: "7.4",
        source_text_equation: """
        G(π) = E_{Q(s̃|π)}[ H[P(õ|s̃)] ] − H[Q(õ|π)] − E_{Q(õ|π)}[ln P(õ|C)]
              \\_____________________/          \\_______________________/
               negative epistemic value (-I(π))          pragmatic value
        """,
        normalized_latex: """
        G(\\pi) = \\underbrace{\\mathbb{E}_{Q(\\tilde s\\mid\\pi)}[H[P(\\tilde o\\mid\\tilde s)]] - H[Q(\\tilde o\\mid\\pi)]}_{-I(\\pi)}
                 - \\underbrace{\\mathbb{E}_{Q(\\tilde o\\mid\\pi)}[\\ln P(\\tilde o\\mid C)]}_{\\text{pragmatic value}}
        """,
        symbols: [%{name: "I(π)", meaning: "epistemic value (mutual info over predicted obs)"}],
        model_family: "Expected Free Energy",
        model_type: :discrete,
        conceptual_role:
          "EFE decomposition that dissolves the explore/exploit dilemma in one scalar.",
        implementation_role:
          "The -I(π) term corresponds to H·s^π_τ − o^π_τ·ln o^π_τ in eq. 4.10 / B.29.",
        dependencies: ["eq_4_10_efe_linear_algebra"],
        verification_status: :verified_against_source_and_appendix,
        verification_notes: "Book lines 6226–6233."
      },
      %Equation{
        id: "eq_7_8_info_gain",
        source_title: @source_title,
        chapter: "7 Active Inference in Discrete Time",
        section: "7.4 Information Seeking",
        equation_number: "7.8",
        source_text_equation: """
        I(π) = H[Q(õ|π)] − E_{Q(s̃|π)}[ H[P(õ|s̃)] ]
             = D_KL[ P(õ|s̃) Q(s̃|π) || Q(õ|π) Q(s̃|π) ]
             = E_{Q(õ|π)}[ D_KL[ Q(s̃|π,õ) || Q(s̃|π) ] ]
        """,
        normalized_latex: """
        I(\\pi) = H[Q(\\tilde o\\mid\\pi)] - \\mathbb{E}_{Q(\\tilde s\\mid\\pi)}[H[P(\\tilde o\\mid\\tilde s)]]
              = \\mathbb{E}_{Q(\\tilde o\\mid\\pi)}[D_{KL}[Q(\\tilde s\\mid\\pi,\\tilde o)\\|Q(\\tilde s\\mid\\pi)]]
        """,
        symbols: [],
        model_family: "Epistemic Value / Salience",
        model_type: :discrete,
        conceptual_role:
          "Three equivalent forms: posterior predictive entropy − expected ambiguity, mutual information, Bayesian surprise.",
        implementation_role:
          "Used by the UI telemetry to label the epistemic contribution of each policy.",
        dependencies: ["eq_4_10_efe_linear_algebra"],
        verification_status: :verified_against_source,
        verification_notes: "Book lines 6701–6729."
      },
      %Equation{
        id: "eq_7_10_dirichlet_update",
        source_title: @source_title,
        chapter: "7 Active Inference in Discrete Time",
        section: "7.5 Learning and Novelty",
        equation_number: "7.10",
        source_text_equation: """
        a = a + Σ_τ s_τ ⊗ o_τ
        E_Q[A_{ij}] ≈ a_{ij} / a_{0j}
        E_Q[ln A_{ij}] = ψ(a_{ij}) − ψ(a_{0j})
        a_{0j} ≜ Σ_k a_{kj}
        """,
        normalized_latex: """
        a = a + \\sum_\\tau s_\\tau \\otimes o_\\tau,\\quad
        \\mathbb{E}_Q[A_{ij}] \\approx a_{ij}/a_{0j},\\quad
        \\mathbb{E}_Q[\\ln A_{ij}] = \\psi(a_{ij}) - \\psi(a_{0j})
        """,
        symbols: [
          %{name: "a", meaning: "Dirichlet pseudo-counts for the A matrix"},
          %{name: "ψ", meaning: "digamma function"}
        ],
        model_family: "Dirichlet Learning",
        model_type: :discrete,
        conceptual_role: "Activity-dependent plasticity for the likelihood parameters.",
        implementation_role:
          "Out of scope for the MVP maze (A is fixed); scaffolded in the registry only.",
        dependencies: ["eq_4_5_pomdp_likelihood"],
        verification_status: :verified_against_source_and_appendix,
        verification_notes: "Book lines 7086–7104; Appendix B eq. B.10–B.12."
      },

      # ---- Chapter 8: Continuous-time Active Inference ----
      %Equation{
        id: "eq_8_1_continuous_generative_model",
        source_title: @source_title,
        chapter: "8 Active Inference in Continuous Time",
        section: "8.2 Movement Control",
        equation_number: "8.1",
        source_text_equation: """
        y  =  g(x) + ω_y
        ẋ  =  f(x, v) + ω_x
        """,
        normalized_latex: """
        y = g(x) + \\omega_y,\\qquad \\dot x = f(x, v) + \\omega_x
        """,
        symbols: [
          %{name: "x", meaning: "continuous hidden state"},
          %{name: "v", meaning: "slow causes (play role of π in discrete case)"},
          %{name: "ω_{y,x}", meaning: "Gaussian fluctuations"}
        ],
        model_family: "Continuous-time Generative Model",
        model_type: :continuous,
        conceptual_role:
          "Defines the agent's generative model as stochastic differential equations.",
        implementation_role:
          "Surfaced in the UI registry; not executed in the maze MVP (see completion report).",
        dependencies: [],
        verification_status: :verified_against_source,
        verification_notes: "Book lines 7669–7673."
      },
      %Equation{
        id: "eq_8_2_continuous_generative_process",
        source_title: @source_title,
        chapter: "8 Active Inference in Continuous Time",
        section: "8.2 Movement Control",
        equation_number: "8.2",
        source_text_equation: """
        y  =  g(x) + ω_y
        ẋ  =  f(x, u) + ω_x
        """,
        normalized_latex: """
        y = \\mathbf{g}(x) + \\omega_y,\\qquad \\dot x = \\mathbf{f}(x, u) + \\omega_x
        """,
        symbols: [%{name: "u", meaning: "action — only appears in the generative process"}],
        model_family: "Generative Process (world)",
        model_type: :continuous,
        conceptual_role:
          "Critical distinction from eq. 8.1: actions live in the process, not the model.",
        implementation_role:
          "Motivates the world-plane / agent-plane split used architecturally.",
        dependencies: ["eq_8_1_continuous_generative_model"],
        verification_status: :verified_against_source,
        verification_notes: "Book lines 7689–7693."
      },
      %Equation{
        id: "eq_8_5_newtonian_attractor",
        source_title: @source_title,
        chapter: "8 Active Inference in Continuous Time",
        section: "8.2 Movement Control",
        equation_number: "8.5",
        source_text_equation: "f(x, v) = [ x_2 ;  (κ/m)(v − x_1) ]",
        normalized_latex:
          "f(x, v) = \\begin{bmatrix} x_2 \\\\ (\\kappa/m)(v - x_1) \\end{bmatrix}",
        symbols: [
          %{name: "κ", meaning: "spring constant"},
          %{name: "m", meaning: "mass"}
        ],
        model_family: "Continuous-time Generative Model",
        model_type: :continuous,
        conceptual_role: "Hooke's law attractor used to model proprioceptive control.",
        implementation_role: "Registry-only for the MVP.",
        dependencies: ["eq_8_1_continuous_generative_model"],
        verification_status: :verified_against_source,
        verification_notes: "Book lines 7742–7748."
      },
      %Equation{
        id: "eq_8_6_lotka_volterra",
        source_title: @source_title,
        chapter: "8 Active Inference in Continuous Time",
        section: "8.3 Dynamical Systems",
        equation_number: "8.6",
        source_text_equation: "f(x, v) = x ° (v + A x)",
        normalized_latex: "f(x, v) = x \\circ (v + A x)",
        symbols: [%{name: "°", meaning: "Hadamard (element-wise) product"}],
        model_family: "Continuous-time Generative Model (chaotic / oscillatory)",
        model_type: :continuous,
        conceptual_role: "Sequential/oscillatory dynamics used to model itinerant behaviour.",
        implementation_role: "Registry-only.",
        dependencies: [],
        verification_status: :verified_against_source,
        verification_notes: "Book lines 7893–7895."
      },

      # ---- Appendix B: the canonical equations reference ----
      %Equation{
        id: "eq_B_2_free_energy_per_policy",
        source_title: @source_title,
        chapter: "Appendix B: The Equations of Active Inference",
        section: "B.2.1 State Inference",
        equation_number: "B.2",
        source_text_equation: """
        F(π) = E_{Q(s̃|π)}[ ln Q(s̃|π) − ln P(õ, s̃|π) ]  ≥  −ln P(õ|π)
        Q*(s̃|π) = argmin_Q F(π)  ⇒  F(π) ≈ −ln P(õ|π)
        """,
        normalized_latex: """
        F(\\pi) = \\mathbb{E}_{Q(\\tilde s\\mid\\pi)}[\\ln Q(\\tilde s\\mid\\pi) - \\ln P(\\tilde o, \\tilde s\\mid\\pi)] \\ge -\\ln P(\\tilde o\\mid\\pi)
        """,
        symbols: [],
        model_family: "Variational Free Energy",
        model_type: :discrete,
        conceptual_role:
          "Per-policy free energy as upper bound on negative log marginal likelihood.",
        implementation_role:
          "Mirrors eq. 4.11; the registry keeps both entries so appendix-vs-chapter reconciliation is auditable.",
        dependencies: ["eq_4_11_vfe_linear_algebra"],
        verification_status: :verified_against_source_and_appendix,
        verification_notes: "Book lines 12567–12573."
      },
      %Equation{
        id: "eq_B_5_gradient_descent_states",
        source_title: @source_title,
        chapter: "Appendix B: The Equations of Active Inference",
        section: "B.2.1 State Inference",
        equation_number: "B.5",
        source_text_equation: """
        s^π_τ = σ(v^π_τ)
        v̇^π_τ = −∇_{s^π_τ} F_π
        ∇_{s^π_τ} F_π = ln s^π_τ − ln A · o_τ − ln B^π_τ s^π_{τ−1} − ln B^π_{τ+1} · s^π_{τ+1}
        """,
        normalized_latex: """
        s^\\pi_\\tau = \\sigma(v^\\pi_\\tau),\\quad
        \\dot v^\\pi_\\tau = -\\nabla_{s^\\pi_\\tau}F_\\pi,\\quad
        \\nabla F_\\pi = \\ln s^\\pi_\\tau - \\ln A\\cdot o_\\tau - \\ln B^\\pi_\\tau s^\\pi_{\\tau-1} - \\ln B^\\pi_{\\tau+1}\\cdot s^\\pi_{\\tau+1}
        """,
        symbols: [],
        model_family: "Variational Message Passing",
        model_type: :discrete,
        conceptual_role:
          "Biologically-plausible gradient descent form of the state-belief update.",
        implementation_role:
          "Implemented numerically in `ActiveInferenceCore.DiscreteTime.update_state_beliefs/6`.",
        dependencies: ["eq_4_13_state_belief_update"],
        verification_status: :verified_against_source_and_appendix,
        verification_notes: "Book lines 12652–12659. Solves the same fixed-point as eq. 4.13."
      },
      %Equation{
        id: "eq_B_7_policy_prior_with_habit",
        source_title: @source_title,
        chapter: "Appendix B: The Equations of Active Inference",
        section: "B.2.2 Planning as Inference",
        equation_number: "B.7",
        source_text_equation: """
        F = E_{Q(π)}[ ln Q(π) − ln P(π, õ) ]
          ≈ E_{Q(π)}[ ln Q(π) + F(π) − ln P(π) ]
        P(π) = Cat(π_0);   Q(π) = Cat(π)
        π_0 = σ( ln E − G )
        """,
        normalized_latex: """
        F \\approx \\mathbb{E}_{Q(\\pi)}[\\ln Q(\\pi) + F(\\pi) - \\ln P(\\pi)],\\quad
        \\pi_0 = \\sigma(\\ln E - G)
        """,
        symbols: [
          %{name: "E", meaning: "habit prior over policies"},
          %{name: "G", meaning: "EFE vector (one entry per policy)"}
        ],
        model_family: "Policy Inference",
        model_type: :discrete,
        conceptual_role: "Full form of the policy prior including a habitual bias term (E).",
        implementation_role:
          "Implementation defaults `E = uniform`; the UI lets the user toggle habits on.",
        dependencies: ["eq_4_7_policy_prior_and_efe"],
        verification_status: :verified_against_source_and_appendix,
        verification_notes: "Book lines 12700–12708."
      },
      %Equation{
        id: "eq_B_9_policy_posterior_update",
        source_title: @source_title,
        chapter: "Appendix B: The Equations of Active Inference",
        section: "B.2.2 Planning as Inference",
        equation_number: "B.9",
        source_text_equation: "∇_π F = 0  ⇔  π = σ(ln E − F − G)",
        normalized_latex:
          "\\nabla_\\pi F = 0 \\;\\Leftrightarrow\\; \\pi = \\sigma(\\ln E - F - G)",
        symbols: [],
        model_family: "Policy Inference",
        model_type: :discrete,
        conceptual_role: "Closed-form posterior over policies with habit term.",
        implementation_role:
          "Canonical action-selection formula used by the agent. Equivalent to eq. 4.14 with E = 1.",
        dependencies: ["eq_4_14_policy_posterior", "eq_B_7_policy_prior_with_habit"],
        verification_status: :verified_against_source_and_appendix,
        verification_notes: "Book lines 12725–12729."
      },
      %Equation{
        id: "eq_B_29_info_gain_linear_algebra",
        source_title: @source_title,
        chapter: "Appendix B: The Equations of Active Inference",
        section: "B.2.5 Expected Free Energy",
        equation_number: "B.29",
        source_text_equation: """
        H[Q(o_τ|π)] − E_{Q(s_τ|π)}[ H[P(o_τ|s_τ)] ]
          = −o^π · ln o^π − H · s^π_τ
        H ≜ −diag(A · ln A)
        """,
        normalized_latex: """
        H[Q(o_\\tau\\mid\\pi)] - \\mathbb{E}_{Q(s_\\tau\\mid\\pi)}[H[P(o_\\tau\\mid s_\\tau)]]
          = -o^\\pi\\cdot\\ln o^\\pi - H\\cdot s^\\pi_\\tau,\\quad H = -\\mathrm{diag}(A\\cdot\\ln A)
        """,
        symbols: [],
        model_family: "Expected Free Energy",
        model_type: :discrete,
        conceptual_role: "Operational expression for the epistemic component of G.",
        implementation_role:
          "Used inside `ActiveInferenceCore.DiscreteTime.expected_free_energy/4`.",
        dependencies: ["eq_4_10_efe_linear_algebra", "eq_7_8_info_gain"],
        verification_status: :verified_against_source_and_appendix,
        verification_notes: "Book lines 13104–13110."
      },
      %Equation{
        id: "eq_B_30_efe_per_time",
        source_title: @source_title,
        chapter: "Appendix B: The Equations of Active Inference",
        section: "B.2.5 Expected Free Energy",
        equation_number: "B.30",
        source_text_equation: """
        G_π = Σ_τ G_{πτ}
        G_{πτ} = H · s^π_τ + o^π_τ · ( ln o^π_τ − ln C_τ )
        """,
        normalized_latex: """
        G_\\pi = \\sum_\\tau G_{\\pi\\tau},\\quad
        G_{\\pi\\tau} = H\\cdot s^\\pi_\\tau + o^\\pi_\\tau\\cdot(\\ln o^\\pi_\\tau - \\ln C_\\tau)
        """,
        symbols: [],
        model_family: "Expected Free Energy",
        model_type: :discrete,
        conceptual_role: "Summed per-time-step EFE used in planning.",
        implementation_role: "Exact shape of the numerical evaluator in the discrete-time core.",
        dependencies: ["eq_4_10_efe_linear_algebra", "eq_B_29_info_gain_linear_algebra"],
        verification_status: :verified_against_source_and_appendix,
        verification_notes: "Book lines 13112–13118."
      },
      %Equation{
        id: "eq_B_42_laplace_free_energy_continuous",
        source_title: @source_title,
        chapter: "Appendix B: The Equations of Active Inference",
        section: "B.3 (Active) Generalized Filtering",
        equation_number: "B.42",
        source_text_equation: """
        F[q, ỹ] ≈ −½ ln (2π)^k |Σ̃|  −  ln p(ỹ, μ̃)
        q(x̃) = N(μ̃, Σ̃^{-1})
        Σ̃^{-1} = −∇̃_x ( ∇̃_x ln p(ỹ, x̃) )^T |_{x̃=μ̃}
        """,
        normalized_latex: """
        F[q, \\tilde y] \\approx -\\tfrac{1}{2}\\ln(2\\pi)^k|\\tilde\\Sigma| - \\ln p(\\tilde y, \\tilde\\mu),\\quad
        q(\\tilde x) = \\mathcal{N}(\\tilde\\mu, \\tilde\\Sigma^{-1})
        """,
        symbols: [%{name: "Σ̃^{-1}", meaning: "precision in generalized coordinates"}],
        model_family: "Continuous-time Inference (Laplace approximation)",
        model_type: :continuous,
        conceptual_role: "Free energy under the Laplace assumption, in generalized coordinates.",
        implementation_role:
          "Registry-only for the MVP. Architecture exposes hooks for a future solver.",
        dependencies: ["eq_8_1_continuous_generative_model"],
        verification_status: :verified_against_source,
        verification_notes: "Book lines 13368–13386."
      },
      %Equation{
        id: "eq_B_47_predictive_coding_hierarchy",
        source_title: @source_title,
        chapter: "Appendix B: The Equations of Active Inference",
        section: "B.3 (Active) Generalized Filtering",
        equation_number: "B.47",
        source_text_equation: """
        μ̇_x^{(i)} − D μ̃_x^{(i)} = ∇_{μ̃_x} g̃ · Π̃^{(i-1)} ε̃^{(i-1)} − D · Π̃^{(i)} ε̃^{(i)} + ∇_{μ̃_x} f̃ · Π̃^{(i)} ε̃^{(i)}
        μ̇_v^{(i)} − D μ̃_v^{(i)} = ∇_{μ̃_v} g̃ · Π̃^{(i-1)} ε̃^{(i-1)} + ∇_{μ̃_v} f̃ · Π̃^{(i)} ε̃^{(i)} + Π̃^{(i)} ε̃^{(i)}
        """,
        normalized_latex: """
        \\dot{\\tilde\\mu}^{(i)}_x - D\\tilde\\mu^{(i)}_x = \\nabla g\\,\\tilde\\Pi^{(i-1)}\\tilde\\varepsilon^{(i-1)} - D\\tilde\\Pi^{(i)}\\tilde\\varepsilon^{(i)} + \\nabla f\\,\\tilde\\Pi^{(i)}\\tilde\\varepsilon^{(i)}
        """,
        symbols: [],
        model_family: "Hierarchical Predictive Coding",
        model_type: :continuous,
        conceptual_role:
          "Multi-level generalised filtering equations — the continuous-time perceptual dynamics.",
        implementation_role: "Registry-only.",
        dependencies: ["eq_B_42_laplace_free_energy_continuous"],
        verification_status: :verified_against_source,
        verification_notes: "Book lines 13548–13579."
      },
      %Equation{
        id: "eq_B_48_continuous_action",
        source_title: @source_title,
        chapter: "Appendix B: The Equations of Active Inference",
        section: "B.3 (Active) Generalized Filtering",
        equation_number: "B.48",
        source_text_equation: "u̇ = −∇_u ỹ(u) · Π̃_y ε̃_y",
        normalized_latex:
          "\\dot u = -\\nabla_u \\tilde y(u) \\cdot \\tilde\\Pi_y \\tilde\\varepsilon_y",
        symbols: [%{name: "u", meaning: "motor action"}],
        model_family: "Active Inference — Continuous Control",
        model_type: :continuous,
        conceptual_role: "Action minimises prediction error via spinal-reflex dynamics.",
        implementation_role: "Registry-only.",
        dependencies: ["eq_8_2_continuous_generative_process"],
        verification_status: :verified_against_source,
        verification_notes: "Book lines 13586–13592."
      }
    ]
  end
end
