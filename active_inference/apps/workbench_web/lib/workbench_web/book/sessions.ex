defmodule WorkbenchWeb.Book.Sessions do
  @moduledoc """
  Session catalogue — the atomic units of the workshop curriculum.

  Each chapter owns 3–5 sessions; a session is one 8–15-minute learning
  segment combining:

    * a book excerpt (pointer into the chapter TXT),
    * a podcast segment (file + `{start_s, end_s}`),
    * linked labs (optional: `%{slug, beat}` — opens the lab on that beat),
    * linked Workbench surfaces (optional routes + labels),
    * four path-specific narration blocks (kid / real / equation / derivation),
    * a list of glossary concepts the learner encounters,
    * a quick quiz (`[%{q, choices, a, why}, ...]`),
    * a Qwen system-prompt seed for the uber-help / full-chat integrations.

  The curriculum is 38 sessions total:

    preface (1) + ch1 (3) + ch2 (4) + ch3 (4) + ch4 (5) + ch5 (4)
            + ch6 (3) + ch7 (5) + ch8 (4) + ch9 (3) + ch10 (3)  =  39

  (1 preface + 38 chapter-body sessions.)
  """

  @type lab_link :: %{slug: String.t(), beat: non_neg_integer()}
  @type wb_link :: %{route: String.t(), label: String.t()}
  @type path_block :: %{
          required(:kid) => String.t(),
          required(:real) => String.t(),
          required(:equation) => String.t(),
          required(:derivation) => String.t()
        }
  @type quiz_q :: %{q: String.t(), choices: [String.t()], a: non_neg_integer(), why: String.t()}

  @type t :: %{
          chapter: non_neg_integer(),
          slug: String.t(),
          title: String.t(),
          minutes: non_neg_integer(),
          ordinal: non_neg_integer(),
          txt_lines: {non_neg_integer(), non_neg_integer()},
          podcast: {String.t(), {non_neg_integer(), non_neg_integer() | :end}},
          figures: [String.t()],
          concepts: [String.t()],
          path_text: path_block(),
          labs: [lab_link()],
          workbench: [wb_link()],
          quiz: [quiz_q()],
          qwen_seed: String.t()
        }

  # Path-text authoring guide:
  #   :kid        — 2nd person, grade-5 vocab, 1-2 sentences, one concrete image.
  #   :real       — plain English, grade-8 vocab, 2-3 sentences, one analogy.
  #   :equation   — math in Unicode, 2-4 sentences, ties to the labelled equation.
  #   :derivation — formal voice, proof sketch or citation, may reference texts.

  @sessions [
    # ================= PREFACE =================
    %{
      chapter: 0,
      slug: "s1_orientation",
      title: "Orientation — how to use this suite",
      minutes: 6,
      ordinal: 1,
      txt_lines: {78, 228},
      podcast: {"preface/preface.mp3", {0, :end}},
      figures: [],
      concepts: ~w(active-inference learning-path),
      path_text: %{
        kid:
          "This book is about guessing well and acting well at the same time. We'll play with chips, clocks, towers, and frogs to make the math feel like toys.",
        real:
          "Active Inference is the claim that one variational rule explains both what you believe and what you do. The suite around this book lets you touch every moving part.",
        equation:
          "The suite covers the full book in 10 chapters × 3–5 sessions. Every equation in the text has a live record under /equations with chapter anchors; every figure is viewable from the session page.",
        derivation:
          "The Parr/Pezzulo/Friston (2022) treatise formalises Active Inference as variational inference with preferences and action. This workshop is the MIT Press text + MIT-adjacent teaching simulators + a live Jido-agent IDE."
      },
      labs: [],
      workbench: [
        %{route: "/learn", label: "Curriculum hub"},
        %{route: "/guide", label: "User guide"}
      ],
      quiz: [
        %{
          q: "What single mathematical objective underlies Active Inference?",
          choices: [
            "Cross-entropy",
            "Variational free energy",
            "Mean-squared error",
            "Gradient descent"
          ],
          a: 1,
          why:
            "Active Inference is variational inference with preferences; free energy is the bound on surprise."
        }
      ],
      qwen_seed:
        "You are the onboarding guide for an Active Inference masterclass. Orient the learner to the suite in two sentences, matched to their current path."
    },

    # ================= CHAPTER 1 · OVERVIEW =================
    %{
      chapter: 1,
      slug: "s1_what_is_ai",
      title: "What Active Inference claims",
      minutes: 10,
      ordinal: 1,
      txt_lines: {229, 400},
      podcast: {"ch01_part01.mp3", {0, :end}},
      figures: ~w(1.1),
      concepts: ~w(generative-model generative-process markov-blanket),
      path_text: %{
        kid:
          "An agent guesses what's inside the box, acts to peek inside, and updates the guess. That loop is the whole story.",
        real:
          "A brain (or agent) carries a model of its world, uses it to explain what it sees, and acts to make the world match what it expected. The same rule drives both halves.",
        equation:
          "The generative model p(o, s, π) is the agent's hypothesis over observations, hidden states, and policies. Perception infers p(s | o); action samples o to match p(o).",
        derivation:
          "Separating generative process (environment) from generative model (agent) via a Markov blanket lets the same variational objective drive perception and action under a single partition."
      },
      labs: [%{slug: "bayes-chips", beat: 1}],
      workbench: [%{route: "/models", label: "Model taxonomy"}],
      quiz: [
        %{
          q: "What is the 'generative model' in Active Inference?",
          choices: [
            "The physical environment",
            "The agent's internal hypothesis over world states",
            "The loss function",
            "The neural substrate"
          ],
          a: 1,
          why:
            "The generative model is the agent's probabilistic model; the generative process is the environment."
        }
      ],
      qwen_seed:
        "You are teaching Ch 1 of Active Inference. The learner is on the overview — avoid jargon until the term is introduced. Keep answers under 120 words."
    },
    %{
      chapter: 1,
      slug: "s2_perception_and_action",
      title: "Perception and action — one loop",
      minutes: 10,
      ordinal: 2,
      txt_lines: {401, 560},
      podcast: {"ch01_part02.mp3", {0, :end}},
      figures: [],
      concepts: ~w(perception action policy),
      path_text: %{
        kid:
          "When you hunt for your keys, your eyes move to likely spots. Moving your eyes is action; updating what you believe is perception. They feed each other.",
        real:
          "Perception infers causes of observations; action changes observations to reduce prediction error. Both minimise the same free-energy functional — just in different variables.",
        equation: "Perception: μ̇ = −∂F/∂μ. Action: u̇ = −∂F/∂u. Same F, two gradients.",
        derivation:
          "Active Inference identifies action as inference over a policy posterior q(π), yielding u* = argmin_u F(u) with F evaluated at the current posterior mode."
      },
      labs: [%{slug: "jumping-frog", beat: 1}],
      workbench: [%{route: "/equations", label: "Equations registry"}],
      quiz: [
        %{
          q: "Under Active Inference, action changes __ to reduce free energy.",
          choices: ["Beliefs", "Observations", "The generative model", "Prior preferences"],
          a: 1,
          why:
            "Beliefs are updated by perception; action acts on the sensory channel (observations)."
        }
      ],
      qwen_seed:
        "You are teaching Ch 1 §2. Emphasise the symmetry: perception and action share one objective."
    },
    %{
      chapter: 1,
      slug: "s3_why_one_theory",
      title: "Why one theory — and what this book covers",
      minutes: 6,
      ordinal: 3,
      txt_lines: {561, 704},
      podcast: {"ch01_part03.mp3", {0, :end}},
      figures: [],
      concepts: ~w(variational-free-energy expected-free-energy),
      path_text: %{
        kid: "One idea explains how you learn, plan, and act. You'll meet it chapter by chapter.",
        real:
          "The book has two halves: Part I derives the theory, Part II shows how to ship agents. This session previews the ladder.",
        equation:
          "F (variational free energy) bounds −ln p(o); G (expected free energy) scores policies. The book unfolds in those two quantities.",
        derivation:
          "Part I derives F and G from variational principles; Part II operationalises them in discrete and continuous time with concrete inference schemes."
      },
      labs: [],
      workbench: [
        %{route: "/guide", label: "User guide"},
        %{route: "/guide/examples", label: "Five examples"}
      ],
      quiz: [],
      qwen_seed: "Preview Part I vs Part II. Keep under 100 words."
    },

    # ================= CHAPTER 2 · LOW ROAD =================
    %{
      chapter: 2,
      slug: "s1_inference_as_bayes",
      title: "Inference as Bayes' rule",
      minutes: 12,
      ordinal: 1,
      txt_lines: {705, 960},
      podcast: {"ch02_part01.mp3", {0, 420}},
      figures: ~w(2.1),
      concepts: ~w(bayes-rule prior likelihood posterior),
      path_text: %{
        kid:
          "You have a hunch. Some clue arrives. The rule tells you how much to trust the hunch afterwards.",
        real:
          "Bayes' rule updates what you believe after seeing evidence. P(H|E) = P(E|H) · P(H) / P(E). Prior times likelihood, divided by what was likely anyway.",
        equation:
          "P(s | o) = P(o | s) · P(s) / P(o); in log-odds form, posterior log-odds = prior log-odds + log-likelihood ratio.",
        derivation:
          "The identity follows from the product rule of probability. For a discrete hypothesis space, the normalising constant is Σ_{s'} P(o|s')P(s')."
      },
      labs: [%{slug: "bayes-chips", beat: 3}],
      workbench: [%{route: "/equations", label: "Eq. 2.1 record"}],
      quiz: [
        %{
          q: "Bayes' rule multiplies prior P(H) by the __.",
          choices: ["Posterior", "Likelihood P(E|H)", "Evidence P(E)", "Odds ratio"],
          a: 1,
          why: "The posterior is proportional to prior × likelihood; P(E) normalises."
        }
      ],
      qwen_seed:
        "Teach Bayes' rule at the learner's path level. Stay arithmetical, avoid measure theory unless derivation path."
    },
    %{
      chapter: 2,
      slug: "s2_why_free_energy",
      title: "Why free energy — bounding surprise",
      minutes: 12,
      ordinal: 2,
      txt_lines: {961, 1180},
      podcast: {"ch02_part01.mp3", {420, :end}},
      figures: [],
      concepts: ~w(variational-free-energy kl-divergence surprise),
      path_text: %{
        kid:
          "Surprise is hard to compute exactly. Free energy is a stand-in you can always measure. Make F small, surprise shrinks.",
        real:
          "Exact Bayesian inference is intractable in most worlds. Free energy is an upper bound on surprise that we can minimise in closed form by choosing a tractable q(s).",
        equation:
          "F[q] = E_q[ln q(s) − ln p(o, s)] = KL(q ‖ p(·|o)) − ln p(o). Minimising F in q tightens the bound on −ln p(o).",
        derivation:
          "F is the evidence lower bound (ELBO) with sign flipped. From Jensen's inequality, KL ≥ 0 ⟹ F ≥ −ln p(o). Equality when q = posterior."
      },
      labs: [],
      workbench: [%{route: "/equations", label: "Eq. 2.5 record"}],
      quiz: [
        %{
          q: "Variational free energy is an upper bound on what quantity?",
          choices: ["Prior probability", "Surprise −ln p(o)", "Posterior entropy", "Likelihood"],
          a: 1,
          why: "F ≥ −ln p(o); minimising F tightens the bound."
        }
      ],
      qwen_seed:
        "Explain ELBO / free energy at the learner's path. Be careful with the sign conventions."
    },
    %{
      chapter: 2,
      slug: "s3_cost_of_being_wrong",
      title: "Variational free energy, decomposed",
      minutes: 10,
      ordinal: 3,
      txt_lines: {1181, 1500},
      podcast: {"ch02_part02.mp3", {0, :end}},
      figures: ~w(2.2),
      concepts: ~w(accuracy complexity precision),
      path_text: %{
        kid:
          "F has two parts: how wrong your explanation is, and how fancy it is. Keep it simple and honest.",
        real:
          "F = complexity − accuracy. Complexity penalises priors you twisted to fit the data; accuracy rewards explanations consistent with what you saw.",
        equation: "F = KL(q(s) ‖ p(s)) − E_q[ln p(o | s)] = complexity − accuracy.",
        derivation:
          "Expanding the joint p(o,s) = p(o|s)p(s) gives F = KL(q‖prior) − E_q[log-likelihood]. Complexity alone is Occam's razor; accuracy is goodness of fit."
      },
      labs: [%{slug: "free-energy-forge", beat: 1}],
      workbench: [%{route: "/equations", label: "Eq. 2.6 record"}],
      quiz: [
        %{
          q: "The complexity term of F is a KL divergence between which two distributions?",
          choices: [
            "Posterior and likelihood",
            "Variational q(s) and prior p(s)",
            "Prior and evidence",
            "Observations and predictions"
          ],
          a: 1,
          why: "Complexity = KL(q‖prior); punishes departures from the prior for fitting data."
        }
      ],
      qwen_seed: "Teach the complexity/accuracy decomposition. Mention Occam's razor."
    },
    %{
      chapter: 2,
      slug: "s4_action_as_inference",
      title: "Action as sampling from a prior",
      minutes: 12,
      ordinal: 4,
      txt_lines: {1501, 1940},
      podcast: {"ch02_part03.mp3", {0, :end}},
      figures: [],
      concepts: ~w(action-as-inference prior-preferences policy),
      path_text: %{
        kid: "You can make the world match your hopes. Acting is how you steer what you see.",
        real:
          "Treat your preferences as priors over what you expect to see. Acting to make observations look like your priors is mathematically identical to inference.",
        equation:
          "a* = argmin_a F(a), where F(a) is evaluated on predicted observations under action a.",
        derivation:
          "Embedding preferences as a prior p(o) lets F subsume both perception (update q(s)) and action (sample p(o) via u). Bogacz (2017), Friston (2010) formalise this in detail."
      },
      labs: [%{slug: "jumping-frog", beat: 4}],
      workbench: [%{route: "/equations", label: "Eq. 2.12 record"}],
      quiz: [],
      qwen_seed: "Explain action-as-inference. Link to Ch. 3's expected free energy."
    },

    # ================= CHAPTER 3 · HIGH ROAD =================
    %{
      chapter: 3,
      slug: "s1_expected_free_energy",
      title: "Expected Free Energy — scoring a plan",
      minutes: 12,
      ordinal: 1,
      txt_lines: {1941, 2200},
      podcast: {"ch03_part01.mp3", {0, :end}},
      figures: ~w(3.1),
      concepts: ~w(expected-free-energy policy risk ambiguity),
      path_text: %{
        kid:
          "Plans are rated by how surprising they're likely to be. Lower surprise = better plan.",
        real:
          "Before acting, the agent imagines each plan's future observations and scores the plan by the expected free energy of those predictions.",
        equation: "G_π = E_{Q(o,s|π)}[ ln Q(s|π) − ln P(o,s) ] = risk + ambiguity.",
        derivation:
          "EFE is the expectation of F under the policy-predicted joint. Decompose into KL(Q(o|π)‖C) + E_Q[H[P(o|s)]]. Risk = expected KL from preferences; ambiguity = expected sensory entropy."
      },
      labs: [%{slug: "jumping-frog", beat: 6}, %{slug: "pomdp-machine", beat: 5}],
      workbench: [%{route: "/equations", label: "Eq. 3.1 record"}],
      quiz: [
        %{
          q: "Expected Free Energy decomposes into...",
          choices: [
            "Complexity + accuracy",
            "Risk + ambiguity",
            "Entropy + KL",
            "Prior + likelihood"
          ],
          a: 1,
          why: "G_π = KL(Q(o|π)‖C) + E[H[P(o|s)]] = risk + ambiguity."
        }
      ],
      qwen_seed:
        "Teach EFE. Contrast with VFE (F) carefully — F scores the past, G scores the future."
    },
    %{
      chapter: 3,
      slug: "s2_epistemic_pragmatic",
      title: "Epistemic vs pragmatic value",
      minutes: 12,
      ordinal: 2,
      txt_lines: {2201, 2480},
      podcast: {"ch03_part02.mp3", {0, 360}},
      figures: [],
      concepts: ~w(epistemic-value pragmatic-value information-gain),
      path_text: %{
        kid:
          "Good plans balance two things: learning about the world (poking around) and getting what you want (chasing goals).",
        real:
          "EFE splits into information-gain (how much you expect to learn) and preference-matching (how much you expect to enjoy the outcome).",
        equation: "G_π = −E_{Q(o|π)}[D_KL(Q(s|o,π) ‖ Q(s|π))] − E_Q[ln P(o)].",
        derivation:
          "Rewriting risk+ambiguity yields epistemic (−expected information gain) + pragmatic (−expected log-preference). Minimising G maximises information gain + preference-matching."
      },
      labs: [%{slug: "anatomy-studio", beat: 5}],
      workbench: [%{route: "/guide/examples", label: "L3 epistemic explorer"}],
      quiz: [
        %{
          q: "Epistemic value rewards plans that...",
          choices: [
            "Match preferences",
            "Maximise expected information gain",
            "Minimise cost",
            "Shorten horizons"
          ],
          a: 1,
          why:
            "Epistemic value is negative expected KL from posterior to prior — it rewards curiosity."
        }
      ],
      qwen_seed: "Explain epistemic vs pragmatic as two incentives inside one score."
    },
    %{
      chapter: 3,
      slug: "s3_softmax_policy",
      title: "The softmax policy",
      minutes: 8,
      ordinal: 3,
      txt_lines: {2481, 2680},
      podcast: {"ch03_part02.mp3", {360, :end}},
      figures: [],
      concepts: ~w(softmax policy-precision gamma),
      path_text: %{
        kid:
          "With many plans to choose from, pick the best with some wiggle — decisive but not stubborn.",
        real:
          "Policy posterior = softmax(−γG). Higher γ (decisiveness) sharpens on the argmin; lower γ spreads across plans.",
        equation: "π(a) = softmax(−γ G_π) = exp(−γ G_a) / Σ_b exp(−γ G_b).",
        derivation:
          "γ is the inverse-temperature of the policy posterior; under active inference it is itself inferred from a Gamma prior (cf. precision of prior)."
      },
      labs: [%{slug: "pomdp-machine", beat: 5}],
      workbench: [%{route: "/equations", label: "Eq. 3.7 record"}],
      quiz: [],
      qwen_seed: "Teach the softmax policy. Mention inverse temperature γ."
    },
    %{
      chapter: 3,
      slug: "s4_what_makes_an_agent_active",
      title: "What makes an agent 'active'",
      minutes: 10,
      ordinal: 4,
      txt_lines: {2681, 2927},
      podcast: {"ch03_part03.mp3", {0, :end}},
      figures: [],
      concepts: ~w(active-inference curiosity preferences),
      path_text: %{
        kid:
          "An active agent doesn't just sit there — it poke-pokes the world to learn and to get things it wants.",
        real:
          "Active Inference unifies perception, learning, and control under one objective. Curiosity and goal-seeking fall out — they're not bolted on.",
        equation: "Full loop: q(s) ← min_q F ; π ← softmax(−γ G) ; a ~ π ; o ← world(a, s).",
        derivation:
          "Each step corresponds to a different gradient of the same variational objective; see Friston, Schwartenbeck, FitzGerald (2015)."
      },
      labs: [%{slug: "pomdp-machine", beat: 1}, %{slug: "bayes-chips", beat: 7}],
      workbench: [%{route: "/guide/build-your-first", label: "Tutorial: your first agent"}],
      quiz: [],
      qwen_seed: "Summarise the active-inference loop end-to-end."
    },

    # ================= CHAPTER 4 · GENERATIVE MODELS =================
    %{
      chapter: 4,
      slug: "s1_setup",
      title: "Why generative models — the engine of AIF",
      minutes: 10,
      ordinal: 1,
      txt_lines: {2928, 3200},
      podcast: {"ch04_part01.mp3", {0, 300}},
      figures: ~w(4.1),
      concepts: ~w(generative-model hidden-state observation),
      path_text: %{
        kid: "The agent's brain has a toy world inside. Everything it does uses that toy world.",
        real:
          "A generative model is the agent's joint hypothesis over hidden causes and observations. Every AIF quantity is built from it.",
        equation: "p(o_{1:T}, s_{1:T}, π) = p(π) Π_t p(o_t | s_t) p(s_t | s_{t-1}, π).",
        derivation:
          "The factorisation encodes a POMDP: likelihood A, transitions B, preferences C, initial belief D."
      },
      labs: [%{slug: "pomdp-machine", beat: 1}],
      workbench: [%{route: "/models", label: "Model taxonomy"}],
      quiz: [
        %{
          q: "The factorisation p(o_t | s_t) corresponds to which AIF matrix?",
          choices: ["A (likelihood)", "B (transition)", "C (preference)", "D (initial)"],
          a: 0,
          why:
            "A is the observation likelihood; B is state transitions; C is outcome preferences; D is the prior over initial state."
        }
      ],
      qwen_seed: "Teach POMDP factorisation. Tie each factor to A/B/C/D."
    },
    %{
      chapter: 4,
      slug: "s2_a_matrix",
      title: "A as emission — observation model",
      minutes: 8,
      ordinal: 2,
      txt_lines: {3201, 3500},
      podcast: {"ch04_part01.mp3", {300, :end}},
      figures: ~w(4.2),
      concepts: ~w(A-matrix likelihood categorical),
      path_text: %{
        kid:
          "A says how the hidden thing shows up in your senses. Rattly state gives loud sounds; calm state gives quiet ones.",
        real:
          "A is the emission likelihood: A[o, s] = P(o | s). It's how the agent predicts observations from hidden states.",
        equation:
          "P(o_t = i | s_t = j) = A[i, j]; columns are normalised categorical distributions.",
        derivation:
          "For categorical A, inference uses ln(A · o) as a likelihood message; differentiable learning under Dirichlet priors (Ch. 7)."
      },
      labs: [%{slug: "pomdp-machine", beat: 2}],
      workbench: [%{route: "/equations", label: "Eq. 4.1 record"}],
      quiz: [
        %{
          q: "A[o, s] represents...",
          choices: [
            "Transition from state s to state o",
            "P(observing o | state s)",
            "Policy prior",
            "Preference weight"
          ],
          a: 1,
          why: "A is the likelihood; rows indexed by observation, columns by state."
        }
      ],
      qwen_seed: "Teach A. Emphasise columns-as-distributions, and the structure of its log."
    },
    %{
      chapter: 4,
      slug: "s3_efe_intro",
      title: "Expected Free Energy — your first look",
      minutes: 12,
      ordinal: 3,
      txt_lines: {3501, 3900},
      podcast: {"ch04_part02.mp3", {180, 540}},
      figures: ~w(4.5),
      concepts: ~w(expected-free-energy risk ambiguity softmax),
      path_text: %{
        kid:
          "Guess which plan would surprise you least. Score plans, then pick the best-scoring one with a little randomness.",
        real:
          "EFE scores a plan: how far its outcomes stray from preferences (risk) plus how ambiguous its sensor readings will be (ambiguity).",
        equation: "G_π = E_Q[ln Q(s|π) − ln P(o,s)] ≈ KL(Q(o|π) ‖ C) + E_Q[H[P(o|s)]].",
        derivation:
          "Starting from F, replace observations by expectations under the policy; expand via KL + entropy decomposition (Parr et al. 2022, §4.4)."
      },
      labs: [%{slug: "pomdp-machine", beat: 5}, %{slug: "anatomy-studio", beat: 2}],
      workbench: [%{route: "/equations", label: "Eq. 4.14 record"}],
      quiz: [
        %{
          q: "Which of these is NOT a term in the standard EFE decomposition?",
          choices: ["Risk", "Ambiguity", "Novelty", "Accuracy"],
          a: 3,
          why:
            "Accuracy is a VFE term; EFE decomposes into risk + ambiguity (± novelty in parameter-learning variants)."
        }
      ],
      qwen_seed: "Teach EFE with the POMDP-machine lab in mind. Mention both risk and ambiguity."
    },
    %{
      chapter: 4,
      slug: "s4_mdp_world",
      title: "A full discrete MDP",
      minutes: 12,
      ordinal: 4,
      txt_lines: {3901, 4150},
      podcast: {"ch04_part02.mp3", {540, :end}},
      figures: [],
      concepts: ~w(mdp pomdp transition-matrix preference),
      path_text: %{
        kid:
          "Pick actions that change what happens. You can't see the hidden state — guess from what you can see.",
        real:
          "A POMDP has A, B(u), C, D. The agent infers hidden states, scores plans via EFE, and acts. Each matrix is editable in the lab.",
        equation: "B(u)[s',s] = P(s_{t+1}=s' | s_t=s, a=u); C[o] ∝ ln P_pref(o); D = P(s_1).",
        derivation:
          "Eq. 4.13 gives the message-passing update for v_τ under the variational factorisation; see §4.5.2."
      },
      labs: [%{slug: "pomdp-machine", beat: 3}],
      workbench: [%{route: "/builder/new", label: "Builder canvas"}],
      quiz: [],
      qwen_seed:
        "Walk the POMDP end to end. Show how the lab's A/B/C/D sliders correspond to book notation."
    },
    %{
      chapter: 4,
      slug: "s5_practice",
      title: "Build your first agent",
      minutes: 15,
      ordinal: 5,
      txt_lines: {4151, 4333},
      podcast: {"ch04_part03.mp3", {0, :end}},
      figures: [],
      concepts: ~w(active-inference discrete-time),
      path_text: %{
        kid:
          "Time to build! Open the Builder, drag the A, B, C, D blocks, wire them up, and run.",
        real:
          "Use /builder/new to assemble a spec, then /world to run it against a maze. Glass shows every signal with its source equation.",
        equation:
          "Full loop: q(s_τ) = softmax(v_τ); v_τ updates via Eq. 4.13; π = softmax(−γ(G+F)); a ~ π.",
        derivation:
          "The reference implementation is in active_inference/apps/agent_plane; compare your builder spec to the L2 example."
      },
      labs: [%{slug: "pomdp-machine", beat: 7}],
      workbench: [
        %{route: "/builder/new", label: "Builder"},
        %{route: "/world", label: "World (run it)"},
        %{route: "/glass", label: "Glass (trace)"}
      ],
      quiz: [],
      qwen_seed:
        "Coach the learner through builder → world → glass. Suggest the L2 preset if stuck."
    },

    # ================= CHAPTER 5 · MESSAGE PASSING =================
    %{
      chapter: 5,
      slug: "s1_factor_graphs",
      title: "Factor graphs and message passing",
      minutes: 12,
      ordinal: 1,
      txt_lines: {4334, 4600},
      podcast: {"ch05_part01.mp3", {0, :end}},
      figures: ~w(5.1),
      concepts: ~w(factor-graph message-passing belief-propagation),
      path_text: %{
        kid:
          "Imagine each variable whispering to its neighbours. Round after round, they agree on a story.",
        real:
          "A factor graph shows how variables and factors connect. Message passing iterates until each node's belief reflects all evidence.",
        equation:
          "μ_{a→i} = Σ_{x_a \\ x_i} f_a(x_a) Π_{j ≠ i} μ_{j→a}(x_j); q(x_i) ∝ Π_a μ_{a→i}.",
        derivation:
          "Belief propagation is exact on trees, approximate on loops; variational message passing with mean-field q = Π q_i recovers the AIF update (Winn & Bishop 2005)."
      },
      labs: [%{slug: "laplace-tower", beat: 1}],
      workbench: [%{route: "/equations", label: "Eq. 5.1 record"}],
      quiz: [],
      qwen_seed: "Teach factor graphs. Contrast exact vs variational message passing."
    },
    %{
      chapter: 5,
      slug: "s2_predictive_coding",
      title: "Predictive coding in hierarchy",
      minutes: 12,
      ordinal: 2,
      txt_lines: {4601, 4900},
      podcast: {"ch05_part02.mp3", {0, :end}},
      figures: ~w(5.5),
      concepts: ~w(predictive-coding prediction-error precision-weighting),
      path_text: %{
        kid:
          "Higher layers predict what lower layers see. Lower layers complain when the prediction is wrong.",
        real:
          "In a hierarchy, each level predicts the one below; prediction errors flow upward, predictions flow downward. Precisions weight how strict each level is.",
        equation: "εy = y − g(μ); εx = D μx − f(μ); F = Σ ½ ε_i^T Π_i ε_i.",
        derivation:
          "Predictive coding emerges as gradient descent on F for a linear-Gaussian hierarchical model under Laplace approximation (Friston 2008)."
      },
      labs: [%{slug: "laplace-tower", beat: 4}],
      workbench: [%{route: "/equations", label: "Eq. 5.7 record"}],
      quiz: [
        %{
          q: "In predictive coding, precision (Π) controls...",
          choices: [
            "The sign of the error",
            "How strongly that error updates beliefs",
            "The number of hierarchical levels",
            "The preference vector"
          ],
          a: 1,
          why: "Precision scales the error's contribution to F; higher Π → larger gradient."
        }
      ],
      qwen_seed: "Teach predictive coding as a gradient of F."
    },
    %{
      chapter: 5,
      slug: "s3_neuromodulation",
      title: "Precision, neuromodulation, and ACh/NA/DA/5-HT",
      minutes: 12,
      ordinal: 3,
      txt_lines: {4901, 5100},
      podcast: {"ch05_part03.mp3", {0, 500}},
      figures: [],
      concepts: ~w(neuromodulation ACh NA DA serotonin),
      path_text: %{
        kid:
          "Chemicals in the brain turn precision knobs up and down. Each chemical tunes a different part of the system.",
        real:
          "Precisions map (partially) to neuromodulators: ACh → sensory precision, NA → state precision, DA → policy precision, 5-HT → preference weight.",
        equation: "Πy ↔ ACh ; Πx ↔ NA ; γ (policy) ↔ DA ; χ (risk) ↔ 5-HT.",
        derivation:
          "The mapping is best understood as computational role, not localisation. DA↔γ is the most empirically robust; the others are theoretical commitments with growing support (Friston et al. 2012, 2013)."
      },
      labs: [%{slug: "atlas", beat: 5}],
      workbench: [%{route: "/equations", label: "Equations registry"}],
      quiz: [],
      qwen_seed:
        "Teach the precision-to-neuromodulator mapping; flag which claims are speculative."
    },
    %{
      chapter: 5,
      slug: "s4_brain_map",
      title: "Anatomy of belief updating",
      minutes: 12,
      ordinal: 4,
      txt_lines: {5101, 5278},
      podcast: {"ch05_part03.mp3", {500, :end}},
      figures: [],
      concepts: ~w(cortical-hierarchy basal-ganglia policy-selection),
      path_text: %{
        kid:
          "Different parts of the brain play different roles: cortex predicts, basal ganglia pick the plan.",
        real:
          "Cortical hierarchies implement predictive coding; basal ganglia implement policy selection via EFE; thalamus gates precision.",
        equation:
          "Predictive-coding messages run on cortical laminae; EFE arbitration happens in striatum (Schwartenbeck et al. 2015).",
        derivation:
          "Mapping anatomical structure to the AIF graph is an active research programme; the Atlas lab shows one coherent commitment."
      },
      labs: [%{slug: "atlas", beat: 2}],
      workbench: [%{route: "/glass", label: "Glass — signal provenance"}],
      quiz: [],
      qwen_seed:
        "Map AIF's mathematical roles onto neuroanatomy. Remain honest about speculation."
    },

    # ================= CHAPTER 6 · RECIPE =================
    %{
      chapter: 6,
      slug: "s1_states_obs_actions",
      title: "What's hidden, what's seen, what costs what",
      minutes: 10,
      ordinal: 1,
      txt_lines: {5279, 5540},
      podcast: {"ch06_part01.mp3", {0, :end}},
      figures: ~w(6.1),
      concepts: ~w(hidden-state observation action preference),
      path_text: %{
        kid:
          "To build an agent, pick what's hidden, pick what it sees, pick what it can do, pick what it wants.",
        real:
          "Step 1 of the recipe: choose state space, observation space, action space, and preferences. Everything else flows from these four choices.",
        equation: "Define S (states), O (obs), U (actions), C (preference over O).",
        derivation:
          "The choices determine the support of p(o,s,π) and fix the factorisation shape. Inference over this model is parameter-free once the choices are made."
      },
      labs: [],
      workbench: [%{route: "/builder/new", label: "Builder canvas"}],
      quiz: [],
      qwen_seed: "Teach the recipe start: state/obs/action/preference selection."
    },
    %{
      chapter: 6,
      slug: "s2_ab_c_d",
      title: "Fill in A, B, C, D",
      minutes: 12,
      ordinal: 2,
      txt_lines: {5541, 5800},
      podcast: {"ch06_part02.mp3", {0, :end}},
      figures: ~w(6.2),
      concepts: ~w(A-matrix B-matrix C-vector D-vector),
      path_text: %{
        kid:
          "Now fill the knobs. A says how senses depend on hidden things. B says how things change. C says what you want. D says where you start.",
        real:
          "A = emission, B = transitions, C = preferences (log-prior), D = initial belief. Fill each with numbers that reflect your problem.",
        equation:
          "A ∈ R^{|O|×|S|}, B(u) ∈ R^{|S|×|S|}, C ∈ R^{|O|}, D ∈ R^{|S|}; each column/row normalised as appropriate.",
        derivation:
          "For learning, replace point values with Dirichlet counts (Ch. 7). For hierarchy, stack A/B/C/D per level."
      },
      labs: [%{slug: "pomdp-machine", beat: 2}],
      workbench: [%{route: "/builder/new", label: "Builder: wire blocks"}],
      quiz: [
        %{
          q: "Which matrix encodes 'what the agent wants to observe'?",
          choices: ["A", "B", "C", "D"],
          a: 2,
          why: "C is the preference over observations — it's a log-prior driving risk."
        }
      ],
      qwen_seed: "Coach the learner through filling A/B/C/D for a simple maze."
    },
    %{
      chapter: 6,
      slug: "s3_run_and_inspect",
      title: "Ship your agent — run, glass, iterate",
      minutes: 10,
      ordinal: 3,
      txt_lines: {5801, 6054},
      podcast: {"ch06_part03.mp3", {0, :end}},
      figures: [],
      concepts: ~w(episode trace signal-provenance),
      path_text: %{
        kid:
          "Run your agent. Watch it stumble or succeed. The Glass page shows every step with the equation that caused it.",
        real:
          "Run your spec in /world; inspect every belief update in /glass. Glass traces each signal back to the book equation that produced it.",
        equation:
          "Each signal carries {agent_id, tick, equation_ref} — follow it from world.observation ↦ agent.perceived ↦ agent.planned ↦ agent.action_emitted.",
        derivation:
          "The reference implementation publishes events to WorldModels.Bus; Glass consumes them and reconstructs the provenance DAG."
      },
      labs: [%{slug: "pomdp-machine", beat: 7}],
      workbench: [%{route: "/world", label: "Run it"}, %{route: "/glass", label: "Trace it"}],
      quiz: [],
      qwen_seed: "Teach the run/inspect loop. Highlight Glass as the debugger."
    },

    # ================= CHAPTER 7 · DISCRETE TIME =================
    %{
      chapter: 7,
      slug: "s1_discrete_refresher",
      title: "Discrete time — a refresher",
      minutes: 8,
      ordinal: 1,
      txt_lines: {6055, 6300},
      podcast: {"ch07_part01.mp3", {0, 400}},
      figures: ~w(7.1),
      concepts: ~w(discrete-time time-slice horizon),
      path_text: %{
        kid: "Time ticks in clicks. At each click, the agent sees something, guesses, then acts.",
        real:
          "Discrete AIF runs on a grid of time slices τ = 1, 2, …, T. Each tick does one full perceive-plan-act loop.",
        equation: "τ ∈ {1,…,T}; per-tick: o_τ, s_τ, a_τ ~ π.",
        derivation:
          "The sum-product message passing on the temporal chain is tractable in O(T|S|²); horizon T typically 3–5 in practice."
      },
      labs: [%{slug: "pomdp-machine", beat: 1}],
      workbench: [%{route: "/equations", label: "Eq. 7.1 record"}],
      quiz: [],
      qwen_seed: "Refresh discrete time-slicing."
    },
    %{
      chapter: 7,
      slug: "s2_message_passing_4_13",
      title: "Eq. 4.13 message passing, unpacked",
      minutes: 14,
      ordinal: 2,
      txt_lines: {6301, 6700},
      podcast: {"ch07_part01.mp3", {400, :end}},
      figures: ~w(7.2),
      concepts: ~w(message-passing variational-update),
      path_text: %{
        kid:
          "At each tick, every guess gets four little nudges: likelihood, past, future, and don't-be-too-sure.",
        real:
          "v_τ accumulates: likelihood message ln(A·o), forward B·s_{τ-1}, backward B^T·s_{τ+1}, and the entropy correction −ln s_τ. Then s_τ = softmax(v_τ).",
        equation: "v_τ ← ln A·o_τ + ln B·s_{τ-1} + ln B^T·s_{τ+1} − ln s_τ; s_τ ← softmax(v_τ).",
        derivation:
          "Eq. 4.13 is the gradient of F wrt v under the mean-field assumption; see §4.5.2 and Da Costa et al. 2020."
      },
      labs: [%{slug: "pomdp-machine", beat: 3}],
      workbench: [%{route: "/equations", label: "Eq. 7.3 record"}],
      quiz: [
        %{
          q: "The backward message ln B^T·s_{τ+1} lets the future...",
          choices: [
            "Change the past's posterior",
            "Modify actions",
            "Pick policies",
            "Define the likelihood"
          ],
          a: 0,
          why:
            "Backward messages let later slices constrain earlier beliefs — the whole point of smoothing."
        }
      ],
      qwen_seed: "Teach Eq. 4.13 step by step, matching the POMDP-machine ledger."
    },
    %{
      chapter: 7,
      slug: "s3_learning_a_b",
      title: "Dirichlet learning of A and B",
      minutes: 12,
      ordinal: 3,
      txt_lines: {6701, 7100},
      podcast: {"ch07_part02.mp3", {0, :end}},
      figures: [],
      concepts: ~w(dirichlet-learning parameter-inference),
      path_text: %{
        kid:
          "You don't know A and B at first. You count what you see, and the agent learns them.",
        real:
          "Give A and B Dirichlet priors. Observations update the counts; posterior expectations give point estimates that sharpen over time.",
        equation: "a ← a + o_t ⊗ s_t^T ; A_ij = a_ij / Σ_k a_kj.",
        derivation:
          "Dirichlet is conjugate to categorical; the update is exact given (o, s) samples. In AIF, s is inferred, so update uses expected sufficient statistics."
      },
      labs: [],
      workbench: [%{route: "/guide/examples", label: "L4 Dirichlet learner"}],
      quiz: [],
      qwen_seed: "Teach Dirichlet posteriors and expected-sufficient-statistics learning."
    },
    %{
      chapter: 7,
      slug: "s4_hierarchical",
      title: "Hierarchical discrete AIF",
      minutes: 12,
      ordinal: 4,
      txt_lines: {7101, 7500},
      podcast: {"ch07_part03.mp3", {0, 400}},
      figures: ~w(7.5),
      concepts: ~w(hierarchy temporal-abstraction policy-hierarchy),
      path_text: %{
        kid:
          "Put one agent above another. The top agent plans slowly, the bottom agent plans fast.",
        real:
          "Hierarchical AIF runs multiple POMDPs at different temporal scales. Higher levels set context (goals, contingencies) for lower ones.",
        equation:
          "Upper level's belief over context serves as the D (or C) of the lower level at each tick.",
        derivation:
          "Temporal abstraction reduces planning complexity from exponential to linear in the product of per-level horizons (Friston et al. 2018)."
      },
      labs: [%{slug: "pomdp-machine", beat: 8}],
      workbench: [%{route: "/labs/run", label: "Labs — run any spec"}],
      quiz: [],
      qwen_seed: "Teach hierarchical AIF."
    },
    %{
      chapter: 7,
      slug: "s5_worked_example",
      title: "A worked discrete example",
      minutes: 15,
      ordinal: 5,
      txt_lines: {7501, 7867},
      podcast: {"ch07_part03.mp3", {400, :end}},
      figures: [],
      concepts: ~w(t-maze active-inference),
      path_text: %{
        kid:
          "The famous 'T-maze' puzzle: go left, go right, look around. The agent learns to pick the reward arm.",
        real:
          "A classic T-maze with a cue, a reward arm, and a safe arm. Walk it through with the book's numbers.",
        equation: "A ∈ R^{3×3}; B(·) ∈ R^{3×3×3}; C = [0, 2, −2]; D = [1, 0, 0].",
        derivation:
          "The T-maze reproduces the canonical AIF benchmark (Friston et al. 2015); its solution demonstrates epistemic behaviour (cue-seeking) before pragmatic behaviour (reward-taking)."
      },
      labs: [%{slug: "pomdp-machine", beat: 6}],
      workbench: [
        %{route: "/world", label: "Run the T-maze"},
        %{route: "/glass", label: "Trace it"}
      ],
      quiz: [],
      qwen_seed: "Walk the T-maze end to end."
    },

    # ================= CHAPTER 8 · CONTINUOUS TIME =================
    %{
      chapter: 8,
      slug: "s1_generalized_coords",
      title: "Generalised coordinates — motion of the mode",
      minutes: 12,
      ordinal: 1,
      txt_lines: {7868, 8200},
      podcast: {"ch08_part01.mp3", {0, :end}},
      figures: ~w(8.1),
      concepts: ~w(generalized-coordinates derivative-operator),
      path_text: %{
        kid:
          "Track a thing, its speed, its acceleration — all at once. That's 'generalized coordinates'.",
        real:
          "Each quantity is represented as a stack: value, velocity, acceleration, ... The derivative operator D shifts the stack upward.",
        equation: "μ̃ = (μ, μ', μ'', ...); D·μ̃ = (μ', μ'', 0).",
        derivation:
          "Generalised coordinates implement exact continuous-time dynamics on discrete data; the order N controls expressiveness (Friston 2008)."
      },
      labs: [%{slug: "laplace-tower", beat: 2}],
      workbench: [%{route: "/equations", label: "Eq. 8.1 record"}],
      quiz: [],
      qwen_seed: "Teach generalised coordinates. The Laplace Tower lab is the visual."
    },
    %{
      chapter: 8,
      slug: "s2_eq_4_19",
      title: "Eq. 4.19 — the quadratic free energy",
      minutes: 14,
      ordinal: 2,
      txt_lines: {8201, 8600},
      podcast: {"ch08_part02.mp3", {0, :end}},
      figures: [],
      concepts: ~w(free-energy-4.19 prediction-error precision),
      path_text: %{
        kid:
          "Three pulls: sensor pull, flow pull, expectation pull. Each is a rope with a stiffness. Add them up — that's F.",
        real:
          "F = ½(ε̃y^T Πy ε̃y + ε̃x^T Πx ε̃x + ε̃v^T Πv ε̃v). Sensor error, dynamics error, cause error — each weighted by its precision.",
        equation:
          "F = ½ Σ_i ε̃_i^T Π_i ε̃_i; ε̃y = ỹ − g(μ̃x, μ̃v); ε̃x = D μ̃x − f(μ̃x, μ̃v); ε̃v = μ̃v − η̃.",
        derivation:
          "Under Laplace approximation with Gaussian noise, F collapses to this quadratic. Precisions are the negative inverse Hessian of ln p(o,s) at the mode."
      },
      labs: [%{slug: "free-energy-forge", beat: 7}],
      workbench: [%{route: "/equations", label: "Eq. 4.19 record"}],
      quiz: [
        %{
          q: "Eq. 4.19's three error families are sensor, dynamics, and...",
          choices: ["Observation", "Cause (prior)", "Policy", "Action"],
          a: 1,
          why: "The third error ε̃v is mismatch with the cause prior η̃."
        }
      ],
      qwen_seed: "Teach Eq. 4.19 term by term. Use the Forge lab's colour coding."
    },
    %{
      chapter: 8,
      slug: "s3_action_on_sensors",
      title: "Action on sensors — u̇ = −∂F/∂u",
      minutes: 10,
      ordinal: 3,
      txt_lines: {8601, 9000},
      podcast: {"ch08_part03.mp3", {0, 400}},
      figures: ~w(8.3),
      concepts: ~w(action-on-sensors reflex-arc),
      path_text: %{
        kid: "When you can't explain what you see by thinking harder, move.",
        real:
          "In continuous time, action is a gradient descent on F with respect to u. It only affects sensors — not beliefs directly.",
        equation: "u̇ = −∂F/∂u = −∂εy/∂u · Πy · εy.",
        derivation:
          "The chain rule gives the reflex-arc form: only paths through y(u) contribute, so action is purely sensory (Friston 2010)."
      },
      labs: [%{slug: "laplace-tower", beat: 7}],
      workbench: [%{route: "/equations", label: "Eq. 8.14 record"}],
      quiz: [],
      qwen_seed: "Teach action gradient. Emphasise that beliefs don't move under action."
    },
    %{
      chapter: 8,
      slug: "s4_continuous_play",
      title: "Open sandbox — play with the forge and tower",
      minutes: 15,
      ordinal: 4,
      txt_lines: {9001, 9246},
      podcast: {"ch08_part03.mp3", {400, :end}},
      figures: [],
      concepts: ~w(free-energy-4.19 laplace predictive-coding),
      path_text: %{
        kid: "Play! Adjust knobs. Watch F drop. That's it.",
        real:
          "Open both the Forge and the Tower. Load a preset. Step through. Tweak precisions. Watch F minimise.",
        equation: "All updates are gradients of F; you're doing calculus without the pain.",
        derivation:
          "Compare your hand-gradient for one iteration against the sim's live F change — they agree to 3 decimal places."
      },
      labs: [%{slug: "free-energy-forge", beat: 1}, %{slug: "laplace-tower", beat: 1}],
      workbench: [],
      quiz: [],
      qwen_seed:
        "Offer ideas: raise Πy and see F rise for the same ε̃y; take a descent step; repeat."
    },

    # ================= CHAPTER 9 · MODEL-BASED ANALYSIS =================
    %{
      chapter: 9,
      slug: "s1_fit_to_data",
      title: "Fitting AIF models to data",
      minutes: 12,
      ordinal: 1,
      txt_lines: {9247, 9550},
      podcast: {"ch09_part01.mp3", {0, :end}},
      figures: ~w(9.1),
      concepts: ~w(log-evidence model-fitting),
      path_text: %{
        kid: "Once you have an agent, see which version of it explains data best.",
        real:
          "Negative free energy is an upper bound on log-evidence. Fit by minimising F over parameters given observed trajectories.",
        equation:
          "ln p(o) ≥ −F(q, θ); minimise F over θ ∈ Θ via gradient descent or variational EM.",
        derivation:
          "Under conjugate priors, parameter posteriors are analytical; otherwise use expectation-maximisation (Friston et al. 2007)."
      },
      labs: [],
      workbench: [%{route: "/equations", label: "Appendix B equations"}],
      quiz: [],
      qwen_seed: "Teach model fitting via free-energy maximisation."
    },
    %{
      chapter: 9,
      slug: "s2_comparing_models",
      title: "Bayesian model comparison",
      minutes: 12,
      ordinal: 2,
      txt_lines: {9551, 9850},
      podcast: {"ch09_part02.mp3", {0, :end}},
      figures: ~w(9.2),
      concepts: ~w(model-comparison bayes-factor),
      path_text: %{
        kid: "Two models of the same data — which fits better? The free energy tells you.",
        real:
          "Log-Bayes-factor ≈ F_1 − F_2. The model with lower F has higher evidence, penalised for complexity automatically.",
        equation:
          "log-BF ≈ F_A − F_B = (accuracy_B − accuracy_A) + (complexity_A − complexity_B).",
        derivation:
          "Free energy does model selection with Occam's razor built in; higher-complexity models pay a KL penalty."
      },
      labs: [%{slug: "anatomy-studio", beat: 5}],
      workbench: [%{route: "/equations", label: "Appendix B"}],
      quiz: [],
      qwen_seed: "Explain Bayesian model comparison via free energy."
    },
    %{
      chapter: 9,
      slug: "s3_case_study",
      title: "A worked case study",
      minutes: 12,
      ordinal: 3,
      txt_lines: {9851, 10251},
      podcast: {"ch09_part03.mp3", {0, :end}},
      figures: [],
      concepts: ~w(neuropsychology model-fitting),
      path_text: %{
        kid: "Let's look at a real story where the theory helped doctors and scientists.",
        real:
          "A published AIF analysis of reaction-time data under uncertainty. Walk through fitting, inspecting, and interpreting.",
        equation: "See book §9.4 for the full fitting trajectory of A, B, C parameters.",
        derivation:
          "The case reproduces a clinical neuropsychology study; precisions were the best-identified parameters (see Schwartenbeck & Friston 2016)."
      },
      labs: [%{slug: "anatomy-studio", beat: 1}],
      workbench: [%{route: "/glass", label: "Inspect a trace"}],
      quiz: [],
      qwen_seed: "Walk the case study. Be specific about precisions vs preferences."
    },

    # ================= CHAPTER 10 · UNIFIED THEORY =================
    %{
      chapter: 10,
      slug: "s1_perception_action_learning",
      title: "One machine — perception, action, learning",
      minutes: 12,
      ordinal: 1,
      txt_lines: {10252, 10600},
      podcast: {"ch10_part01.mp3", {0, :end}},
      figures: [],
      concepts: ~w(unified-theory sentient-behaviour),
      path_text: %{
        kid: "One rule, many jobs: see, act, learn, grow. That's the book's big claim.",
        real:
          "Under Active Inference, perception, action, and learning are all gradients of the same free-energy functional.",
        equation:
          "Variables: s (perception), u (action), θ (learning), m (meta-model). All update by −∂F/∂(·).",
        derivation:
          "The partition is time-scale: s fast, u a bit slower, θ slow, m slowest (Friston 2013)."
      },
      labs: [%{slug: "atlas", beat: 1}],
      workbench: [%{route: "/guide", label: "Guide"}],
      quiz: [],
      qwen_seed: "Teach the unified view. Mention the time-scale partition."
    },
    %{
      chapter: 10,
      slug: "s2_limitations",
      title: "Where the theory bends",
      minutes: 10,
      ordinal: 2,
      txt_lines: {10601, 11000},
      podcast: {"ch10_part02.mp3", {0, :end}},
      figures: [],
      concepts: ~w(limitations open-problems),
      path_text: %{
        kid: "The theory is powerful but not magic. Some puzzles still need new ideas.",
        real:
          "Open problems: scaling to high-dimensional worlds, learning generative model structure, connecting to deep learning, formalising consciousness claims.",
        equation:
          "Complexity of exact inference is #P-hard; approximations (amortised, neural) are active research.",
        derivation: "See recent reviews: Sajid et al. 2021, Parr et al. 2022 §10."
      },
      labs: [],
      workbench: [],
      quiz: [],
      qwen_seed: "Be candid about limitations and open questions."
    },
    %{
      chapter: 10,
      slug: "s3_where_next",
      title: "Where to go next",
      minutes: 8,
      ordinal: 3,
      txt_lines: {11001, 11587},
      podcast: {"ch10_part03.mp3", {0, :end}},
      figures: [],
      concepts: ~w(further-reading research-community),
      path_text: %{
        kid: "Now you know the book. Keep exploring with the labs and the builder.",
        real:
          "Read the reference section, follow the arXiv channels (Karl Friston's, the Verses team's), play with the Builder, join the community.",
        equation: "Useful tools: pymdp (Python), SPM (MATLAB), our Workbench + Jido (Elixir).",
        derivation:
          "See §10.5 for a curated reading list; also Da Costa 2020, Millidge 2020, and the Free Energy Principle working group."
      },
      labs: [],
      workbench: [%{route: "/guide/technical", label: "Technical reference"}],
      quiz: [],
      qwen_seed: "Recommend further reading and tools; encourage experimentation."
    }
  ]

  @doc "All sessions in curriculum order."
  @spec all() :: [t()]
  def all, do: @sessions

  @doc "Sessions for a given chapter number."
  @spec for_chapter(integer()) :: [t()]
  def for_chapter(num),
    do: @sessions |> Enum.filter(fn s -> s.chapter == num end) |> Enum.sort_by(& &1.ordinal)

  @doc "Find a session by chapter + slug."
  @spec find(integer(), String.t()) :: t() | nil
  def find(chapter, slug),
    do: Enum.find(@sessions, fn s -> s.chapter == chapter and s.slug == slug end)

  @doc "Get the next session (for 'Next ▸' navigation)."
  @spec next(t()) :: t() | nil
  def next(%{chapter: ch, ordinal: ord}) do
    sibling = Enum.find(@sessions, fn s -> s.chapter == ch and s.ordinal == ord + 1 end)

    sibling ||
      @sessions
      |> Enum.filter(fn s -> s.chapter > ch end)
      |> Enum.sort_by(&{&1.chapter, &1.ordinal})
      |> List.first()
  end

  @doc "Get the previous session."
  @spec prev(t()) :: t() | nil
  def prev(%{chapter: ch, ordinal: ord}) do
    sibling = Enum.find(@sessions, fn s -> s.chapter == ch and s.ordinal == ord - 1 end)

    sibling ||
      @sessions
      |> Enum.filter(fn s -> s.chapter < ch end)
      |> Enum.sort_by(&{&1.chapter, &1.ordinal}, :desc)
      |> List.first()
  end

  @doc "Total session count."
  def count, do: length(@sessions)
end
