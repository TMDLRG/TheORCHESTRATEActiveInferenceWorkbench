defmodule WorkbenchWeb.Book.Glossary do
  @moduledoc """
  Book-wide glossary.  Every `data-term` attribute that shows up in a session's
  `path_text`, a lab's Shell tooltip, or the equation registry resolves here
  at three tiers: kid / adult / phd.

  This is the single source of truth for tooltip copy across the suite; the
  Learning Shell inside each of the 7 labs uses a slimmed inline subset, but
  when the lab is served through Phoenix we can inject this richer glossary.
  """

  @entries %{
    "active-inference" => %{
      name: "active inference",
      kid: "Guessing well and acting well at the same time — one rule for both.",
      adult:
        "A unified theory in which perception, learning, and action all minimise variational free energy.",
      phd:
        "Variational inference with preferences expressed as priors over observations; action is inference over a policy posterior."
    },
    "generative-model" => %{
      name: "generative model",
      kid: "The imaginary world the agent carries in its head.",
      adult:
        "The agent's joint hypothesis p(o, s, π) over observations, hidden states, and policies.",
      phd:
        "A factorised probabilistic model serving as the agent's prior; its negative log is the quantity the agent minimises expectations of."
    },
    "generative-process" => %{
      name: "generative process",
      kid: "The real world outside the agent.",
      adult: "The true data-generating mechanism the agent can only observe through sensors.",
      phd:
        "The veridical joint distribution that produces observations; may differ from the agent's generative model."
    },
    "markov-blanket" => %{
      name: "Markov blanket",
      kid: "A wall that separates the agent from the world — only sensors and muscles cross it.",
      adult:
        "A statistical partition that renders internal states conditionally independent of external states given sensory and active states.",
      phd:
        "For a variable x with blanket b(x), p(external | x, b) = p(external | b); the minimal sufficient boundary (Pearl 1988)."
    },
    "bayes-rule" => %{
      name: "Bayes' rule",
      kid: "A recipe for updating your guess after a clue.",
      adult: "P(H|E) = P(E|H) P(H) / P(E). Prior times likelihood divided by evidence.",
      phd: "Conditioning identity from the Kolmogorov axioms; foundational to Bayesian inference."
    },
    "prior" => %{
      name: "prior",
      kid: "What you believed before the clue.",
      adult: "P(H) — the agent's belief about a variable in the absence of data.",
      phd: "Marginal distribution over latent variables in the generative model."
    },
    "likelihood" => %{
      name: "likelihood",
      kid: "How well a story fits the clue.",
      adult: "P(E | H) — a function of H given fixed E; not a probability over H.",
      phd: "L(H; E) ∝ P(E | H). In AIF, the emission A[o, s] plays this role for observations."
    },
    "posterior" => %{
      name: "posterior",
      kid: "Your updated guess after seeing the clue.",
      adult: "P(H | E) — belief after conditioning on evidence.",
      phd: "Conditional distribution produced by normalising prior × likelihood."
    },
    "variational-free-energy" => %{
      name: "variational free energy (F)",
      kid: "How surprised you'd be, but easier to compute.",
      adult:
        "F[q] = E_q[ln q(s) − ln p(o,s)] — an upper bound on the negative log-evidence −ln p(o).",
      phd:
        "Negative ELBO; minimised in q to tighten the bound, minimised in parameters θ to maximise marginal likelihood."
    },
    "expected-free-energy" => %{
      name: "expected free energy (G)",
      kid: "Score a plan: add up how surprising you think it'll feel.",
      adult:
        "G_π = E_{Q(o,s|π)}[ln Q(s|π) − ln P(o,s)] — scores a policy by its expected future free energy.",
      phd:
        "Decomposes into risk (KL to preferences) + ambiguity (expected sensory entropy) ± epistemic value."
    },
    "kl-divergence" => %{
      name: "KL divergence",
      kid: "How different two bell-shapes are.",
      adult:
        "KL(p‖q) = Σ p(x) ln(p(x)/q(x)) — a non-symmetric 'distance' between distributions, always ≥ 0.",
      phd:
        "Relative entropy; central to variational bounds. Not a metric (asymmetric, no triangle inequality)."
    },
    "surprise" => %{
      name: "surprise",
      kid: "How unexpected the sensor reading is.",
      adult: "−ln p(o). High when o is improbable under your model.",
      phd: "Self-information; the negative log-evidence that F bounds from above."
    },
    "policy" => %{
      name: "policy",
      kid: "A plan — a sequence of actions the agent might take.",
      adult: "π = (a_1, a_2, …, a_T). The agent maintains a posterior Q(π) over plans.",
      phd: "An element of action space raised to horizon; can be deterministic or stochastic."
    },
    "risk" => %{
      name: "risk",
      kid: "How far you expect the plan's outcomes to be from what you want.",
      adult: "KL(Q(o|π) ‖ C) — the cost of predicted observations departing from preferences.",
      phd:
        "The 'pragmatic' term in EFE; equals negative expected log-preference minus outcome entropy."
    },
    "ambiguity" => %{
      name: "ambiguity",
      kid: "How fuzzy your future sensors will be under this plan.",
      adult:
        "E_Q(s|π)[H[P(o | s)]] — expected entropy of the likelihood given the policy's predicted state distribution.",
      phd: "Part of EFE; low when observations unambiguously reveal state, high when they don't."
    },
    "epistemic-value" => %{
      name: "epistemic value",
      kid: "How much you'd learn by following the plan.",
      adult:
        "Negative expected KL from posterior to prior over hidden states — high when the plan gathers useful info.",
      phd:
        "Bayesian surprise under the policy; drives exploration without any separate exploration bonus."
    },
    "pragmatic-value" => %{
      name: "pragmatic value",
      kid: "How much you'd enjoy the plan's outcomes.",
      adult: "Expected log-preference under the policy's predicted outcomes.",
      phd: "E_Q(o|π)[ln P(o)]; the 'goal-seeking' term that C drives."
    },
    "information-gain" => %{
      name: "information gain",
      kid: "The clue that would change your mind most.",
      adult: "Expected Bayesian surprise: E_o[KL(P(H|o) ‖ P(H))].",
      phd:
        "Mutual information between H and the outcome under the action; the epistemic-value driver."
    },
    "softmax" => %{
      name: "softmax",
      kid: "Turn scores into probabilities that sum to 1.",
      adult: "σ(x)_i = exp(x_i) / Σ_j exp(x_j).",
      phd: "Boltzmann transform; inverse-temperature γ controls concentration."
    },
    "policy-precision" => %{
      name: "policy precision (γ)",
      kid: "How decisive you are about picking the best plan.",
      adult: "Inverse-temperature of the softmax over policies.",
      phd: "Gamma-precision hyperparameter; linked to dopaminergic gain in AIF neurobiology."
    },
    "gamma" => %{
      name: "γ (gamma)",
      kid: "Policy decisiveness knob.",
      adult: "Inverse temperature of the policy posterior softmax.",
      phd: "Precision on the prior over policies; inferred jointly under AIF."
    },
    "action-as-inference" => %{
      name: "action as inference",
      kid: "Acting to make the world match your hopes is also inference.",
      adult:
        "Treating preferences as priors over observations; action becomes gradient descent on F wrt u.",
      phd:
        "Dualises perception: perception minimises F in q(s), action minimises F in u(o); same objective."
    },
    "prior-preferences" => %{
      name: "prior preferences (C)",
      kid: "What outcomes you want. Written down as a wishlist.",
      adult: "A log-prior over observations; drives risk in EFE.",
      phd: "ln P(o); softmax-normalised; rows of C are per-time-step preferences in POMDPs."
    },
    "hidden-state" => %{
      name: "hidden state (s)",
      kid: "What's inside the box you can't see.",
      adult: "The latent variable the agent must infer from observations.",
      phd: "s ∈ S; carries no tilde; evolves under B(u)."
    },
    "observation" => %{
      name: "observation (o)",
      kid: "What your senses tell you.",
      adult: "The sensor reading at time t.",
      phd: "o_t ~ A·s_t in discrete AIF."
    },
    "action" => %{
      name: "action",
      kid: "What you do.",
      adult: "A control variable u that shapes observations via the sensory channel.",
      phd: "In continuous AIF: u̇ = −∂F/∂u. Only y depends on u; beliefs never do directly."
    },
    "perception" => %{
      name: "perception",
      kid: "Updating your guess from what you see.",
      adult: "Gradient descent on F in the belief variable q(s).",
      phd: "μ̇ = −∂F/∂μ under the Laplace approximation."
    },
    "categorical" => %{
      name: "categorical distribution",
      kid: "A bag of options with probabilities that sum to 1.",
      adult: "Cat(p) with p a probability vector — the discrete one-hot world.",
      phd: "Exponential-family distribution; conjugate prior is Dirichlet."
    },
    "A-matrix" => %{
      name: "A matrix",
      kid: "How hidden things show up as senses.",
      adult: "Emission likelihood A[o, s] = P(o | s).",
      phd: "Row-stochastic (in observation index); columns are categorical distributions over O."
    },
    "B-matrix" => %{
      name: "B matrix",
      kid: "How the hidden state changes with each action.",
      adult: "Transition matrix B(u)[s', s] = P(s_{t+1} = s' | s_t = s, a = u).",
      phd: "One matrix per action; column-stochastic in s."
    },
    "C-vector" => %{
      name: "C vector",
      kid: "Your wishlist over outcomes.",
      adult: "Preference (log-prior) over observations; higher entries = more preferred.",
      phd: "C ∈ R^{|O|}; softmaxed for probabilistic interpretation."
    },
    "D-vector" => %{
      name: "D vector",
      kid: "Where you start guessing from.",
      adult: "Prior over the initial hidden state.",
      phd: "D = P(s_1); a categorical over S."
    },
    "mdp" => %{
      name: "MDP",
      kid: "A world with rules, steps, and actions.",
      adult: "Markov Decision Process: states, actions, transitions, rewards.",
      phd: "Fully observed; POMDP is the partially-observed generalisation used by AIF."
    },
    "pomdp" => %{
      name: "POMDP",
      kid: "An MDP where you can't see the state directly.",
      adult: "Partially Observable Markov Decision Process; AIF's workhorse.",
      phd:
        "(S, A, O, T, Z, R); T transitions, Z observation model, R reward (replaced by preferences C in AIF)."
    },
    "transition-matrix" => %{
      name: "transition matrix",
      kid: "Rule for how the hidden thing changes.",
      adult: "The B(u) matrix.",
      phd: "Column-stochastic matrix encoding P(s' | s, u)."
    },
    "message-passing" => %{
      name: "message passing",
      kid: "Variables whispering to each other until everyone agrees.",
      adult:
        "Iterative scheme on a factor graph where each node sums incoming messages to update its belief.",
      phd:
        "Sum-product (exact on trees) or variational (approximate on loops); AIF uses mean-field VMP."
    },
    "factor-graph" => %{
      name: "factor graph",
      kid: "A picture showing which variables depend on which.",
      adult: "A bipartite graph of variables and factors; edges show dependency.",
      phd: "Representation admitting sum-product or variational message passing algorithms."
    },
    "belief-propagation" => %{
      name: "belief propagation",
      kid: "Message passing on a factor graph — when the graph is a tree, it's exact.",
      adult: "Sum-product algorithm for marginal inference.",
      phd: "Exact on trees; loopy BP is a variational approximation on graphs."
    },
    "predictive-coding" => %{
      name: "predictive coding",
      kid: "Higher levels predict lower levels; errors climb up.",
      adult:
        "A hierarchical generative architecture where top-down predictions meet bottom-up errors.",
      phd:
        "Gradient descent on F for a linear-Gaussian hierarchy under Laplace approximation (Friston 2008)."
    },
    "prediction-error" => %{
      name: "prediction error (ε)",
      kid: "The gap between what you expected and what happened.",
      adult: "Discrepancy between predicted and observed; weighted by precision.",
      phd: "εy = y − g(μ); εx = Dμx − f(μ); εv = μv − η."
    },
    "precision-weighting" => %{
      name: "precision weighting",
      kid: "Some errors count more than others. Precision says which.",
      adult: "Errors are weighted by Π (inverse variance) before contributing to F.",
      phd: "F = ½ Σ ε^T Π ε; Π encodes attentional gain."
    },
    "precision" => %{
      name: "precision (Π)",
      kid: "Strictness about a particular error. High = very strict.",
      adult: "Inverse of variance; scales how much an error matters.",
      phd: "Π = Σ^{-1}; diagonal in most AIF tutorials for tractability."
    },
    "free-energy-4.19" => %{
      name: "Eq. 4.19 — quadratic F",
      kid: "Add three error-bills, each with its own weight.",
      adult: "F = ½(ε̃y^T Πy ε̃y + ε̃x^T Πx ε̃x + ε̃v^T Πv ε̃v).",
      phd:
        "Laplace approximation in generalised coords; precisions are negative inverse Hessians at the mode."
    },
    "generalized-coordinates" => %{
      name: "generalised coordinates",
      kid: "Value, speed, acceleration — stacked.",
      adult:
        "A vector containing a variable and its temporal derivatives; the derivative operator D shifts the stack.",
      phd: "μ̃ = (μ, Dμ, D²μ, …); D implements d/dt on noisy discretely-sampled data."
    },
    "derivative-operator" => %{
      name: "derivative operator (D)",
      kid: "A gadget that turns value → speed → acceleration one step at a time.",
      adult: "D shifts a generalised-coordinate stack upward by one temporal order.",
      phd: "Block-Jordan matrix; nilpotent at the order we truncate."
    },
    "laplace" => %{
      name: "Laplace approximation",
      kid: "Replace a bumpy curve with a bell around its peak.",
      adult:
        "Approximate a posterior by a Gaussian centred at the mode, with covariance from the Hessian.",
      phd: "q(x) ≈ N(μ, Σ), Σ = (−∂² ln p(x)/∂x²)^{-1} at x=μ."
    },
    "variational-update" => %{
      name: "variational update",
      kid: "Take a step in the direction that makes the error smaller.",
      adult: "Gradient descent on F in the variational parameters.",
      phd: "μ ← μ − η ∂F/∂μ (Laplace); Bethe / mean-field for categorical q."
    },
    "dirichlet-learning" => %{
      name: "Dirichlet learning",
      kid: "Count what you see; the counts become your new belief.",
      adult:
        "Online updates to Dirichlet pseudo-counts for A and B; expectation gives a point estimate.",
      phd: "Conjugate update under categorical likelihood; expected A_ij = a_ij / Σ_k a_kj."
    },
    "parameter-inference" => %{
      name: "parameter inference",
      kid: "Learn the rules, not just the hidden thing.",
      adult: "Extending inference from states to model parameters.",
      phd: "Joint inference over (s, θ) with conjugate priors on θ; AIF's Dirichlet learning."
    },
    "bayes-factor" => %{
      name: "Bayes factor",
      kid: "How much better one story explains the data than another.",
      adult: "Ratio of model evidences; log-BF ≈ F_A − F_B under AIF.",
      phd: "log p(o | m_A) − log p(o | m_B); positive ⇒ model A wins."
    },
    "log-evidence" => %{
      name: "log-evidence",
      kid: "How well a model explains what you saw.",
      adult: "ln p(o); AIF bounds it from above by −F.",
      phd: "Marginal likelihood; free energy is its ELBO."
    },
    "model-fitting" => %{
      name: "model fitting",
      kid: "Tune the knobs until the model matches the data.",
      adult: "Minimise F over parameters θ given observations.",
      phd: "Variational EM: alternate q and θ updates; AIF uses conjugate priors where possible."
    },
    "model-comparison" => %{
      name: "model comparison",
      kid: "Two theories, same data — which fits better?",
      adult: "Use −F (≈ log-evidence) to rank models; automatic Occam penalty.",
      phd:
        "Relative log-evidence penalises complexity via KL(q‖prior); no free parameters to tune."
    },
    "neuromodulation" => %{
      name: "neuromodulation",
      kid: "Chemicals in the brain tune precision knobs.",
      adult: "ACh, NA, DA, 5-HT each adjust a different precision.",
      phd: "Theoretical mapping; empirical strength varies by neuromodulator."
    },
    "ACh" => %{
      name: "acetylcholine (ACh)",
      kid: "Trust your senses more.",
      adult: "Modulates sensory precision Πy.",
      phd: "Well-supported: ACh upregulation enhances sensory weighting in predictive coding."
    },
    "NA" => %{
      name: "noradrenaline (NA)",
      kid: "Trust how things move more.",
      adult: "Modulates state (dynamics) precision Πx.",
      phd: "Less empirically tested than ACh/DA; growing support."
    },
    "DA" => %{
      name: "dopamine (DA)",
      kid: "Be more decisive about plans.",
      adult: "Modulates policy precision γ.",
      phd: "Most robustly supported AIF-to-neuromodulator mapping; dopaminergic gain sharpens π."
    },
    "serotonin" => %{
      name: "serotonin (5-HT)",
      kid: "Care more or less about the wishlist.",
      adult: "Modulates χ, the preference-weight on risk.",
      phd: "More speculative; linked to affective weighting in AIF-clinical work."
    },
    "t-maze" => %{
      name: "T-maze",
      kid: "The classic left-or-right puzzle with a hint in the middle.",
      adult: "A canonical AIF benchmark demonstrating epistemic then pragmatic behaviour.",
      phd:
        "Friston et al. 2015; 3 states, 3 observations, 3 actions; epistemic value guides cue-seeking."
    },
    "horizon" => %{
      name: "horizon",
      kid: "How many steps ahead you plan.",
      adult: "The number of time slices the agent plans over.",
      phd: "T in POMDP; planning cost scales with horizon × policy count."
    },
    "epoch" => %{
      name: "epoch / time-slice",
      kid: "One click of the clock.",
      adult: "A single discrete time step τ.",
      phd: "Indexed by τ ∈ {1..T}; the unit of AIF inference in discrete time."
    },
    "hierarchy" => %{
      name: "hierarchy",
      kid: "One agent above another, planning slower than its kid.",
      adult: "Multiple AIF levels with different temporal scales.",
      phd: "Composed POMDPs with the higher level's belief serving as the lower's context."
    },
    "basal-ganglia" => %{
      name: "basal ganglia",
      kid: "A brain part that helps pick plans.",
      adult: "Subcortical circuit hypothesised to arbitrate policy selection via EFE.",
      phd: "Direct/indirect pathway dichotomy mapped to softmax(−γ G); see Schwartenbeck 2015."
    },
    "policy-selection" => %{
      name: "policy selection",
      kid: "Picking one plan out of the list.",
      adult: "Sampling from Q(π) = softmax(−γ G).",
      phd: "Action-selection step of AIF; can be MAP or sampled."
    },
    "sentient-behaviour" => %{
      name: "sentient behaviour",
      kid: "Acting in a way that looks like you know what you're doing.",
      adult: "Integrated perception + action + learning under one objective.",
      phd: "AIF's claim: all sentient behaviour minimises a single variational free energy."
    },
    "cortical-hierarchy" => %{
      name: "cortical hierarchy",
      kid: "The brain's layer cake.",
      adult: "Cortical regions arranged in a predictive-coding hierarchy.",
      phd:
        "V1 → V2 → V4 → IT, etc.; deep layers carry predictions, superficial errors (Bastos 2012)."
    },
    "reflex-arc" => %{
      name: "reflex arc",
      kid: "A quick loop: sense → move, no thinking required.",
      adult:
        "Under continuous AIF: u̇ is driven by the gradient of F through the sensory channel only.",
      phd: "Chain rule gives u̇ = −∂εy/∂u · Πy · εy; beliefs are not in this gradient."
    },
    "action-on-sensors" => %{
      name: "action on sensors",
      kid: "Acting only changes what your senses report, not what you think.",
      adult: "In continuous AIF, action has no direct effect on beliefs — only on y.",
      phd: "Ensures dual roles (perception vs action) remain clean under the same functional."
    },
    "temporal-abstraction" => %{
      name: "temporal abstraction",
      kid: "Big plans and little plans at the same time.",
      adult: "Higher hierarchical levels plan at longer timescales.",
      phd:
        "Reduces planning complexity; upper-level states update once per many lower-level ticks."
    },
    "policy-hierarchy" => %{
      name: "policy hierarchy",
      kid: "A plan made of smaller plans.",
      adult: "Composed policies across levels of a hierarchical generative model.",
      phd: "Enables factorised planning; see Friston et al. 2018."
    },
    "open-problems" => %{
      name: "open problems",
      kid: "Puzzles the theory hasn't solved yet.",
      adult:
        "Unresolved questions in AIF: scalability, structure learning, consciousness claims.",
      phd: "See Parr et al. 2022 §10 for a curated list."
    },
    "further-reading" => %{
      name: "further reading",
      kid: "Where to go next to learn more.",
      adult: "Papers and tools to deepen your AIF practice after this book.",
      phd:
        "Sajid 2021 (review), Da Costa 2020 (AIF math), Millidge 2020 (software), pymdp, SPM, our Workbench."
    },
    "softmax-policy" => %{
      name: "softmax policy",
      kid: "Pick the best plan with a little wiggle room.",
      adult: "π = softmax(−γ G) — stochastic, temperature-controlled action selection.",
      phd: "Policy posterior under AIF; γ inferred jointly under a Gamma hyperprior."
    },
    "learning-path" => %{
      name: "learning path",
      kid: "Your voice: story, real, equation, or derivation.",
      adult:
        "One of four narration styles the suite switches between. Math stays the same; scaffolding changes.",
      phd:
        "A persona selector carried in a suite-wide cookie; used to index path_text in session content."
    },
    "signal-provenance" => %{
      name: "signal provenance",
      kid: "For every thing the agent says or does, you can see which equation caused it.",
      adult: "Tracing each Jido signal back to its source equation in Glass.",
      phd: "A verifiability property of the Workbench; see /guide/technical/signals."
    },
    "episode" => %{
      name: "episode",
      kid: "One run of the agent from start to finish.",
      adult: "A trajectory (s_1, o_1, a_1, …, s_T, o_T, a_T).",
      phd: "A single realisation of the generative process under a policy."
    },
    "trace" => %{
      name: "trace",
      kid: "A replay of everything the agent did.",
      adult: "The ordered sequence of signals emitted by an agent during an episode.",
      phd: "Time-indexed event log; Glass reconstructs the DAG of causes."
    },
    "cue" => %{
      name: "cue",
      kid: "A clue that hints at the hidden state.",
      adult: "An observation whose likelihood varies with s; useful for reducing ambiguity.",
      phd: "An epistemic observation; worth obtaining when G_epistemic > 0."
    },
    "policy-prior" => %{
      name: "policy prior (E)",
      kid: "Your default plan — what you'd do without thinking.",
      adult: "E = ln P(π); habit prior over policies.",
      phd: "Amortised policy shortcut; modulates π via π ∝ exp(-γG - F + E)."
    }
  }

  @type entry :: %{
          name: String.t(),
          kid: String.t(),
          adult: String.t(),
          phd: String.t()
        }

  @spec all() :: %{String.t() => entry()}
  def all, do: @entries

  @spec get(String.t()) :: entry() | nil
  def get(key), do: Map.get(@entries, key)

  @spec size() :: non_neg_integer()
  def size, do: map_size(@entries)

  @doc "Return entries whose name or any tier matches the query (case-insensitive)."
  @spec search(String.t()) :: [{String.t(), entry()}]
  def search(q) when is_binary(q) and byte_size(q) > 0 do
    q = String.downcase(q)

    Enum.filter(@entries, fn {k, e} ->
      hay = String.downcase("#{k} #{e.name} #{e.kid} #{e.adult} #{e.phd}")
      String.contains?(hay, q)
    end)
  end
end
