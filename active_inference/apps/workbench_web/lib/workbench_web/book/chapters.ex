defmodule WorkbenchWeb.Book.Chapters do
  @moduledoc """
  Chapter catalogue for Parr / Pezzulo / Friston (2022) — _Active Inference_
  (MIT Press, ISBN 978-0-262-04535-3; text ISBN 978-0-262-36997-8).

  Each entry anchors a module of the workshop curriculum to:

    * line range in the root `book_9780262369978 (1).txt` (for chunking
      into RAG and narration),
    * podcast MP3s under `audio book/ch{NN}_part{PP}.mp3`,
    * PDF page range (best-effort; figure extraction uses these),
    * equation IDs from `ActiveInferenceCore.Equations`,
    * session list (see `WorkbenchWeb.Book.Sessions`),
    * prerequisite chapter numbers.

  Chapter ranges were derived from the TXT export by locating the first
  repeated `^Chapter N$` running-header per chapter; see the line-range
  comments in the struct literals below.
  """

  @type t :: %{
          num: non_neg_integer(),
          slug: String.t(),
          title: String.t(),
          part: :preface | :theory | :practice,
          page_range: {non_neg_integer(), non_neg_integer()},
          txt_lines: {non_neg_integer(), non_neg_integer()},
          podcasts: [String.t()],
          equations: [String.t()],
          figures: [String.t()],
          hero: String.t(),
          blurb: String.t(),
          icon: String.t(),
          prereq: [non_neg_integer()]
        }

  @chapters [
    %{
      num: 0,
      slug: "preface",
      title: "Preface",
      part: :preface,
      page_range: {1, 12},
      txt_lines: {78, 228},
      podcasts: ["preface/preface.mp3"],
      equations: [],
      figures: [],
      hero: "Why this book exists — and how to read it.",
      blurb:
        "The authors' orientation. Skip if you want to dive straight in; come back when a passage feels unmotivated.",
      icon: "📖",
      prereq: []
    },
    %{
      num: 1,
      slug: "overview",
      title: "Overview",
      part: :theory,
      page_range: {3, 14},
      txt_lines: {229, 704},
      podcasts: ~w(ch01_part01.mp3 ch01_part02.mp3 ch01_part03.mp3),
      equations: [],
      figures: ~w(1.1),
      hero: "Perception, action, learning — one loop, one theory.",
      blurb:
        "What Active Inference claims in one picture: the same variational objective explains both what you believe and what you do.",
      icon: "🌍",
      prereq: []
    },
    %{
      num: 2,
      slug: "low-road",
      title: "The Low Road to Active Inference",
      part: :theory,
      page_range: {15, 40},
      txt_lines: {705, 1940},
      podcasts: ~w(ch02_part01.mp3 ch02_part02.mp3 ch02_part03.mp3),
      equations: ~w(2.1 2.5 2.6 2.12),
      figures: ~w(2.1 2.2),
      hero: "From Bayes' rule to variational free energy — the minimal machinery.",
      blurb:
        "Build Active Inference from the ground up: conditioning on evidence, the free-energy bound on surprise, action as sampling from a prior.",
      icon: "🧩",
      prereq: [1]
    },
    %{
      num: 3,
      slug: "high-road",
      title: "The High Road to Active Inference",
      part: :theory,
      page_range: {41, 62},
      txt_lines: {1941, 2927},
      podcasts: ~w(ch03_part01.mp3 ch03_part02.mp3 ch03_part03.mp3),
      equations: ~w(3.1 3.7),
      figures: ~w(3.1),
      hero: "Expected Free Energy: the value of a plan, as a bill with two lines.",
      blurb:
        "Why an agent that minimises expected surprise is simultaneously curious and goal-seeking — risk plus ambiguity, one softmax.",
      icon: "🗺",
      prereq: [2]
    },
    %{
      num: 4,
      slug: "generative-models",
      title: "The Generative Models of Active Inference",
      part: :theory,
      page_range: {63, 84},
      txt_lines: {2928, 4333},
      podcasts: ~w(ch04_part01.mp3 ch04_part02.mp3 ch04_part03.mp3),
      equations: ~w(4.1 4.2 4.7 4.13 4.14 4.19),
      figures: ~w(4.1 4.2 4.5),
      hero: "Every belief, every action, every thought — inside one generative model.",
      blurb:
        "A, B, C, D matrices for discrete-time agents; Eq. 4.13 message passing; Eq. 4.14 EFE; Eq. 4.19 quadratic free energy in generalised coordinates.",
      icon: "⚙",
      prereq: [3]
    },
    %{
      num: 5,
      slug: "message-passing",
      title: "Message Passing and Neurobiology",
      part: :theory,
      page_range: {85, 124},
      txt_lines: {4334, 5278},
      podcasts: ~w(ch05_part01.mp3 ch05_part02.mp3 ch05_part03.mp3),
      equations: ~w(5.1 5.7),
      figures: ~w(5.1 5.5),
      hero: "The cortex as a factor graph — and the neuromodulators as precision knobs.",
      blurb:
        "Predictive coding in hierarchy, motion of the mode in generalised coords, and the mapping from ACh/NA/DA/5-HT to precisions.",
      icon: "🧠",
      prereq: [4]
    },
    %{
      num: 6,
      slug: "recipe",
      title: "A Recipe for Designing Active Inference Models",
      part: :practice,
      page_range: {125, 152},
      txt_lines: {5279, 6054},
      podcasts: ~w(ch06_part01.mp3 ch06_part02.mp3 ch06_part03.mp3),
      equations: [],
      figures: ~w(6.1 6.2),
      hero: "Ship your first agent — what's hidden, what's seen, what costs what.",
      blurb:
        "The practical pipeline: pick states, pick observations, pick actions, fill A/B/C/D, run, inspect.",
      icon: "📐",
      prereq: [4]
    },
    %{
      num: 7,
      slug: "discrete-time",
      title: "Active Inference in Discrete Time",
      part: :practice,
      page_range: {125, 152},
      txt_lines: {6055, 7867},
      podcasts: ~w(ch07_part01.mp3 ch07_part02.mp3 ch07_part03.mp3),
      equations: ~w(7.1 7.3),
      figures: ~w(7.1 7.2 7.5),
      hero: "POMDPs in full colour — message passing, Dirichlet learning, hierarchy.",
      blurb: "The workhorse of applied Active Inference. Build, learn, and chain agents.",
      icon: "⏱",
      prereq: [4, 6]
    },
    %{
      num: 8,
      slug: "continuous-time",
      title: "Active Inference in Continuous Time",
      part: :practice,
      page_range: {153, 172},
      txt_lines: {7868, 9246},
      podcasts: ~w(ch08_part01.mp3 ch08_part02.mp3 ch08_part03.mp3),
      equations: ~w(4.19 8.14),
      figures: ~w(8.1 8.3),
      hero: "Motion of the mode is the mode of the motion.",
      blurb:
        "Generalised coordinates, Laplace approximation, action-as-inference on the sensory channel. Eq. 4.19 fully unpacked.",
      icon: "🌊",
      prereq: [5, 6]
    },
    %{
      num: 9,
      slug: "model-based-analysis",
      title: "Model-Based Data Analysis",
      part: :practice,
      page_range: {173, 200},
      txt_lines: {9247, 10251},
      podcasts: ~w(ch09_part01.mp3 ch09_part02.mp3 ch09_part03.mp3),
      equations: [],
      figures: ~w(9.1 9.2),
      hero: "Fit an Active Inference model to real data — and know when to trust it.",
      blurb:
        "Free energy as log evidence, Bayesian model comparison, and a worked case study from the literature.",
      icon: "📊",
      prereq: [7]
    },
    %{
      num: 10,
      slug: "unified-theory",
      title: "Active Inference as a Unified Theory of Sentient Behavior",
      part: :practice,
      page_range: {201, 240},
      txt_lines: {10252, 11587},
      podcasts: ~w(ch10_part01.mp3 ch10_part02.mp3 ch10_part03.mp3),
      equations: [],
      figures: [],
      hero: "Where the theory goes — and where it bends.",
      blurb:
        "Perception, action, learning, and development under one variational objective; open problems; paths forward.",
      icon: "🌌",
      prereq: [5, 9]
    }
  ]

  @doc "Every chapter in book order (preface first, then 1..10)."
  @spec all() :: [t()]
  def all, do: @chapters

  @doc "Theory chapters only — preface, 1..5."
  def theory, do: Enum.filter(@chapters, fn c -> c.part in [:preface, :theory] end)

  @doc "Practice chapters only — 6..10."
  def practice, do: Enum.filter(@chapters, fn c -> c.part == :practice end)

  @doc "Look up by slug."
  @spec find(String.t()) :: t() | nil
  def find(slug), do: Enum.find(@chapters, fn c -> c.slug == slug end)

  @doc "Look up by chapter number (0 = preface)."
  @spec get(integer()) :: t() | nil
  def get(num) when is_integer(num), do: Enum.find(@chapters, fn c -> c.num == num end)

  def get(num) when is_binary(num) do
    case Integer.parse(num) do
      {n, ""} -> get(n)
      _ -> nil
    end
  end

  @doc "Human part label."
  def part_label(:preface), do: "Preface"
  def part_label(:theory), do: "Part I · Theory"
  def part_label(:practice), do: "Part II · Practice"
end
