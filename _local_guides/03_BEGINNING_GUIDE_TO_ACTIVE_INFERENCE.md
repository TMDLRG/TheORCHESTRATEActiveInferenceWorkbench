# Beginning Guide to Active Inference

*A careful, beginner-friendly tour of one of cognitive science's most ambitious theories — and what it can and can't tell us about minds, bodies, and AI.*

> **Promise.** By the time you finish this guide, you should be able to explain Active Inference to a friend in plain English, tell the difference between a real biological agent and an LLM that *talks like* one, and have a working sense of which claims about all of this are well-established and which are still open questions.

> **Source discipline.** Everything below is cross-referenced to files in this repo, especially the curriculum built around Parr, Pezzulo & Friston (2022) *Active Inference* (MIT Press, CC BY-NC-ND). Where the repo doesn't establish something, this guide says so plainly. See [02_CLAIM_EVIDENCE_MAP.md](02_CLAIM_EVIDENCE_MAP.md) for the per-claim audit.

---

## Table of contents

1. [The big idea in plain English](#1-the-big-idea-in-plain-english)
2. [The one-paragraph version](#2-the-one-paragraph-version)
3. [Why "surprise" doesn't just mean being startled](#3-why-surprise-doesnt-just-mean-being-startled)
4. [The predict–act loop](#4-the-predictact-loop)
5. [Perception and action are partners](#5-perception-and-action-are-partners)
6. [Precision: the brain's calibration problem](#6-precision-the-brains-calibration-problem)
7. [Dopamine, precision, and calibration](#7-dopamine-precision-and-calibration)
8. [Do humans seek reward, or do humans predict?](#8-do-humans-seek-reward-or-do-humans-predict)
9. [Baby's first breath: a careful analogy](#9-babys-first-breath-a-careful-analogy)
10. [Active Inference across disciplines](#10-active-inference-across-disciplines)
11. [Active Inference "all the way down"?](#11-active-inference-all-the-way-down)
12. [Instinct, signals, and alignment with reality](#12-instinct-signals-and-alignment-with-reality)
13. [Resonance: when agent and world fit each other](#13-resonance-when-agent-and-world-fit-each-other)
14. [What Active Inference reveals about LLM limits](#14-what-active-inference-reveals-about-llm-limits)
15. [What this does *not* mean](#15-what-this-does-not-mean)
16. [Glossary](#16-glossary)
17. [Evidence map (compact)](#17-evidence-map-compact)
18. [Reader's next questions](#18-readers-next-questions)

---

## 1. The big idea in plain English

Living things don't passively soak up the world. They **predict** what's about to happen, **compare** their predictions with what their senses actually report, and **act** to keep themselves inside livable bounds.

That's it. That's the loop.

A heart beats faster *before* you start to run, not after. Your eyes flick toward where you expect a face to be, then update if the face isn't there. A bacterium swims up a sugar gradient — moving so its receptors keep saying "more sugar." In each case the agent has a **model** of how things normally go, and it acts to make the next moment look more like what its model predicted.

Active Inference is the proposal that **one mathematical rule** describes both halves of that loop — what an agent comes to believe and what it does. The rule is called *minimising variational free energy*. Don't let the physics name scare you off; we'll unpack it gently.

> **Repo source.** The single-sentence definition the repo uses, kid-tier: *"Guessing well and acting well at the same time — one rule for both."* — [glossary.ex `active-inference`](../active_inference/apps/workbench_web/lib/workbench_web/book/glossary.ex). Strong support.

---

## 2. The one-paragraph version

> An Active Inference agent carries an internal **generative model** of how observations are produced by hidden causes in the world. It is constantly in a tight loop: it **predicts** what its senses should report, **measures the gap** between prediction and incoming signal, and uses that gap to do two things at once — **update its beliefs** about the hidden causes (perception) and **change the world** by acting (action) so that the next observations match what it expected. Both halves minimise the same quantity: a tractable upper bound on **surprise** called variational free energy. When the agent is also choosing among possible plans, it scores each plan by its **expected** free energy — a single number that combines "how much will I learn?" (epistemic value) and "how close will the outcomes be to my preferences?" (pragmatic value). Reward, in the classical sense, never appears as a separate ingredient; preferences are just priors over what the agent expects to observe.

If that paragraph clicked, you have the spine of the theory. Everything below is texture.

---

## 3. Why "surprise" doesn't just mean being startled

In ordinary English, "surprise" is what you feel when somebody jumps out from behind a door. In Active Inference, **surprise has a precise mathematical meaning**: it's *the negative log-probability of an observation under your model.*

In other words: **surprise = how unlikely a sensor reading is, given what you currently believe.**

- See a friend at the coffee shop you both frequent → low surprise.
- See a friend climbing in through the bathroom window of your second-floor apartment → high surprise.

Two things follow, and both matter:

1. **Surprise is relative to a model.** Two agents with different priors will be surprised by different things. The bacterium isn't surprised by a chemical gradient; you would be if you saw it under a microscope for the first time.
2. **Surprise is hard to compute exactly.** You'd need the full marginal probability of every observation your model can generate. So Active Inference works with a substitute called **variational free energy** that is always an *upper bound* on surprise — make the bound smaller and surprise gets squeezed.

> **Repo source.** Glossary, kid/adult/phd: *"How unexpected the sensor reading is. … −ln p(o). High when o is improbable under your model. … Self-information; the negative log-evidence that F bounds from above."* — [glossary.ex `surprise`](../active_inference/apps/workbench_web/lib/workbench_web/book/glossary.ex). Strong support.

> **Caution.** Don't confuse mathematical surprise with the emotion. The emotion is one possible *consequence* of large prediction errors in certain creatures. The math doesn't care whether anyone feels anything.

---

## 4. The predict–act loop

Each "tick" of an Active Inference agent runs a four-step cycle:

1. **Predict.** Given current beliefs about hidden states, predict the next observation.
2. **Sense.** Receive the actual observation.
3. **Compare.** Compute the gap (the *prediction error*, weighted by how much the agent trusts the sensor).
4. **Update + act.** Use the error to (a) update beliefs and (b) pick the action that the agent expects will reduce future free energy.

That cycle is the same whether the agent is a thermostat reasoning about temperature, a rat in a T-maze deciding which arm to enter, or a person reaching for a coffee cup. The variables change; the loop doesn't.

> **Repo source.** The discrete-time form of this loop is implemented as `ActiveInferenceCore.DiscreteTime.update_state_beliefs/6` (state update, eq. 4.13) and `policy_posterior/2` (action selection, eq. 4.14). See [equations.ex](../active_inference/apps/active_inference_core/lib/active_inference_core/equations.ex) entries `eq_4_13_state_belief_update` and `eq_4_14_policy_posterior`. Both flagged `:verified_against_source_and_appendix`.

---

## 5. Perception and action are partners

This is the part that surprises people the most.

In most stories about cognition, perception happens first ("I see the cup"), then thinking ("I want the cup"), then action ("I reach for the cup"). Active Inference flips the relationship. Perception and action become **two ways of solving the same problem**:

- **Perception** changes what you *believe* to make beliefs match the world.
- **Action** changes the *world* to make the world match your beliefs (especially the beliefs you've labelled "preferences").

Both reduce free energy. They differ only in *which variable they wiggle*. Perception wiggles your internal estimate of the hidden state. Action wiggles your sensory inputs by changing the world.

A practical consequence: if you can't reduce free energy by thinking harder, **move**. Move your eyes, turn your head, open the box, ask a question. Action is how you grab better data when your model can't squeeze any more out of what you have.

> **Repo source.** Glossary, "action as inference": *"Treating preferences as priors over observations; action becomes gradient descent on F wrt u. Dualises perception: perception minimises F in q(s), action minimises F in u(o); same objective."* — [glossary.ex `action-as-inference`](../active_inference/apps/workbench_web/lib/workbench_web/book/glossary.ex).

> **Repo source (deep cut).** In continuous time, the math enforces this strictly: action only appears in the *generative process* (the world's equations), not in the *generative model* (the agent's). See [equations.ex](../active_inference/apps/active_inference_core/lib/active_inference_core/equations.ex) entry `eq_8_2_continuous_generative_process` — *"Critical distinction from eq. 8.1: actions live in the process, not the model."*

---

## 6. Precision: the brain's calibration problem

Here's a question that sounds dumb until you think about it: when your eyes and your inner ear disagree about whether the room is spinning, **which signal should you trust?**

That's the precision problem. Every signal carries information; every signal is also noisy. A well-calibrated agent doesn't treat all signals equally — it weights each one by how *reliable* it is in the current context. In Active Inference, that weight is called **precision** (Π), defined as the inverse of the noise variance.

Three things to remember:

- High precision = "this signal is reliable; pay close attention to errors here."
- Low precision = "this signal is noisy; don't be moved by errors here."
- Precision is itself learned and adjusted on the fly.

When Active Inference agents look like they're "paying attention," what they're really doing is *raising precision on the channel that matters right now*. That's why attention, in this framework, isn't a magic spotlight — it's a precision knob.

> **Repo source.** Glossary, kid/adult/phd: *"Strictness about a particular error. High = very strict. … Inverse of variance; scales how much an error matters. … Π = Σ⁻¹; diagonal in most AIF tutorials for tractability."* — [glossary.ex `precision`](../active_inference/apps/workbench_web/lib/workbench_web/book/glossary.ex). Strong support.

---

## 7. Dopamine, precision, and calibration

The careful version of "what dopamine does" in Active Inference goes like this:

> Dopamine is the system's best candidate for the **precision on policies (γ)** — i.e., how decisively the agent commits to one plan over another.

In plain English: dopamine is less about *pleasure* and more about *how much you trust your current scoring of plans*. High γ → "I'm confident plan A is best, let's go." Low γ → "I'm not sure, let's keep options open."

That reframing does several things:

- It explains "reward sensitivity" without making dopamine = reward.
- It naturally accounts for **novelty responses** that classical reinforcement-learning models struggle with.
- It connects dopamine to *commitment* and to the explore/exploit balance, not to a hedonic signal.

> **Repo source.** Glossary, phd-tier: *"DA — Most robustly supported AIF-to-neuromodulator mapping; dopaminergic gain sharpens π."* — [glossary.ex `DA`, `policy-precision`, `gamma`](../active_inference/apps/workbench_web/lib/workbench_web/book/glossary.ex).

> **Repo source (myth-busting short).** *"Dopamine isn't reward. It's how much you trust your reward."* — [shorts/specs/93.json](../shorts/specs/93.json). And from the curriculum's session derivation: *"DA↔γ is the most empirically robust; the others are theoretical commitments with growing support"* — [sessions.ex ch5 s3](../active_inference/apps/workbench_web/lib/workbench_web/book/sessions.ex).

> **Caution.** "Dopamine = precision on policies" is the **theoretical commitment** the framework makes. It is well-supported relative to the alternatives it's compared with in this literature, and weaker than a hard identity claim across all of neuroscience. The slogan "dopamine is *only* precision" goes further than the repo supports. Treat the careful version as your default.

---

## 8. Do humans seek reward, or do humans predict?

This is where Active Inference gets philosophically aggressive — and it's worth getting the framing exactly right.

Classical reinforcement learning (the Sutton & Barto / Bellman tradition) says: behaviour is the optimisation of a *value function* over states. The agent learns which states pay off and how to reach them. **Reward is the central, pre-given quantity.**

Active Inference says: behaviour is **inference**. There's no separate value signal. Instead, the agent has **preferences encoded as a prior over observations** — call it C, the agent's "wishlist of what it expects to see." Acting just means inferring which sequence of actions makes its predicted observations look most like its priors.

This isn't a soft re-description. The repo is explicit:

> *"Active Inference dispenses with the notions of reward, value functions, and Bellman optimality that are key to reinforcement learning approaches. … In Active Inference, a policy is part of the generative model: it denotes a sequence of control states that need to be inferred."*
> — Chapter 10, repo extract: [unified-theory__s2_limitations.txt lines 70–74](../active_inference/apps/workbench_web/priv/book/sessions/unified-theory__s2_limitations.txt). Strong support.

Three things this *does* mean:

1. **The explore/exploit dilemma dissolves into one number.** Expected free energy already contains both an "I'd learn a lot from this plan" term (epistemic) and an "outcomes would match my preferences" term (pragmatic). You don't bolt curiosity onto a reward maximiser; it's there from the start.
2. **Preferences live in *one* place — C, the prior over observations.** Not in a value function. Not in a separate reward channel. — [shorts/specs/34.json](../shorts/specs/34.json).
3. **"Goals" are beliefs.** Specifically, beliefs about what you expect to encounter. The agent acts as if it already trusts that its preferences will be realised — and that optimism is what drives goal-directed behaviour mathematically.

Three things this *does not* mean:

- It does **not** mean humans never seek anything that looks like reward. Treat the claim narrowly: *AIF replaces the reward-as-primitive ontology*, but the things people commonly call rewards (food, warmth, affection) show up in the math as preferred observations.
- It does **not** mean reinforcement learning is wrong about everything. The repo notes formal connections — e.g., *policy gradient* RL methods also dispense with value functions, so they share structure with AIF. — [unified-theory__s2_limitations.txt lines 100–112](../active_inference/apps/workbench_web/priv/book/sessions/unified-theory__s2_limitations.txt).
- It does **not** mean the framing is settled across all cognitive science. It is the framing this framework adopts.

> **Careful summary.** *"Casting behaviour as a functional of beliefs (probability distributions) automatically entails notions such as degree of belief and uncertainty. These notions undergird important facets of adaptive action but are not directly available in the Bellman formulation."* — Chapter 3, repo extract: [high-road__s3_softmax_policy.txt lines 57–60](../active_inference/apps/workbench_web/priv/book/sessions/high-road__s3_softmax_policy.txt).

---

## 9. Baby's first breath: a careful analogy

You asked for the newborn-first-breath example as an illustration of regulation under uncertainty. Here it is, with the evidence labels switched on so you can tell the supported parts from the speculative ones.

**The story.** A newborn emerges. Oxygen levels in the blood drop. The body's predictive systems register a large interoceptive prediction error. There is no learned policy yet for "breathe" — only the inherited machinery that drives the diaphragm. The first cry is a chaotic burst of air movement. Across many cycles, the infant's predictive interoceptive model **learns to act** on its own breath — refining priors about what oxygen-restoration *feels like* and shaping a smoother, more controlled exhale and inhale. Eventually, breathing recedes to the autonomic background, and the baby has acquired a high-precision interoceptive model of its own respiration.

**What the repo establishes.** The repo presents a closely related, broader framing (chapter 10, repo extract):

- **Predictive interoception.** "A creature's generative model is not just about the external world but also — and perhaps even more importantly — about the internal milieu. A generative model of a body's inside (or interoceptive schema) has a dual role: to explain how interoceptive (bodily) sensations are generated and to ensure the correct regulation of physiological parameters."
- **Allostasis (predictive regulation, not just reactive).** "Predictive strategy entails mobilizing resources before expected excursions from physiological setpoints — for example, increasing cardiac output before a long run in anticipation of increased oxygen demands. That requires modifying the priors over interoceptive observations dynamically."
  — [unified-theory__s2_limitations.txt lines 336–384](../active_inference/apps/workbench_web/priv/book/sessions/unified-theory__s2_limitations.txt). Strong support.

**Evidence status of the specific story.** The repo does **not** narrate a "baby's first breath" example. The story above is therefore a **speculative analogy / interpretive synthesis**:

- Supported by repo: ✅ predictive interoception is real Active Inference, ✅ allostatic regulation is real Active Inference, ✅ priors over interoceptive observations get refined over time.
- Not directly supported by repo: ❌ that newborn breathing specifically is the canonical case, ❌ that the first breath is best understood through this framework as opposed to (say) a more standard developmental physiology story.

**How to use the story.** Treat it as an evocative illustration of how an Active Inference agent might bootstrap a high-precision interoceptive policy from a noisy initial state — *not* as a clinical claim about neonatal respiration. If you're ever pressed on it, fall back to the cardiac-output-before-running example, which the repo *does* establish.

---

## 10. Active Inference across disciplines

One reason the framework has spread is that it's expressed in the universal language of probability and gradient flow. A reasonable list of where it has been applied (with repo support) follows. Each domain section says **what AIF changes**, gives **a simple example**, and notes **evidence status**.

### 10.1 Neuroscience
- **What it changes.** Treats cortical hierarchies as a stack of predictive models, with prediction errors flowing up and predictions flowing down. Maps neuromodulators (ACh, NA, DA, 5-HT) to **precision knobs** rather than to "reward chemicals" or "attention chemicals" in the old sense.
- **Example.** A V1 neuron that fires in response to an unexpected edge is interpreted as a precision-weighted prediction-error unit, not a feature detector full stop.
- **Evidence status.** Strong repo support for the framing; the per-neuromodulator mapping varies in robustness (DA strongest, NA / 5-HT more theoretical). [glossary.ex `cortical-hierarchy`, `predictive-coding`, `neuromodulation`](../active_inference/apps/workbench_web/lib/workbench_web/book/glossary.ex), [sessions.ex ch5 s3](../active_inference/apps/workbench_web/lib/workbench_web/book/sessions.ex).

### 10.2 Psychiatry / clinical mental health
- **What it changes.** Reframes conditions as deviations in *precision profiles* rather than chemical imbalances or pure cognitive distortions.
- **Example.** OCD, psychosis, and ADHD have been associated with distinct precision-imbalance signatures (over-trusting priors, under-trusting likelihoods, attention-precision deficits respectively).
- **Evidence status.** Active research programme — repo describes this as "ongoing empirical program." [shorts/specs/95.json](../shorts/specs/95.json), [sessions.ex ch9 s3](../active_inference/apps/workbench_web/lib/workbench_web/book/sessions.ex). Partial repo support; not settled clinical fact.

### 10.3 Psychology / decision science
- **What it changes.** Replaces "the agent maximises expected utility" with "the agent minimises expected free energy." Curiosity stops being a separate motivation and becomes part of the same scalar.
- **Example.** A T-maze rat (the field's canonical benchmark) visits the cue arm *first* (epistemic value: reduce uncertainty about which side has the reward) before going to the reward arm (pragmatic value: match preferences). Both behaviours fall out of one calculation.
- **Evidence status.** Strong repo support. [glossary.ex `t-maze`](../active_inference/apps/workbench_web/lib/workbench_web/book/glossary.ex), [sessions.ex ch7 s5](../active_inference/apps/workbench_web/lib/workbench_web/book/sessions.ex).

### 10.4 Theoretical biology
- **What it changes.** Provides a formal version of *autopoiesis* (Maturana & Varela 1980): living systems are systems that minimise the surprise of their own sensory states, which is mathematically equivalent to staying within their viable range.
- **Example.** A cell that keeps its membrane potential within bounds *is* an Active Inference agent under this framing — its priors are about what a viable cell typically experiences.
- **Evidence status.** Repo supports the reconciliation explicitly: *"Active Inference is in keeping with enactive theories of life and cognition, which emphasize the self-organization of behavior and autopoietic interactions with the environment."* — [high-road__s3_softmax_policy.txt lines 168–171](../active_inference/apps/workbench_web/priv/book/sessions/high-road__s3_softmax_policy.txt). Strong.

### 10.5 Physiology / interoception
- **What it changes.** Body regulation (heart rate, breathing, hormones) is recast as predictive control, not feedback control. Allostasis prepares for change before it happens; homeostasis only corrects after.
- **Example.** Cardiac output rises *before* exercise, not after. (Repo's actual example.)
- **Evidence status.** Strong repo support. [unified-theory__s2_limitations.txt lines 366–384](../active_inference/apps/workbench_web/priv/book/sessions/unified-theory__s2_limitations.txt).

### 10.6 Reinforcement learning / optimal control
- **What it changes.** AIF rejects the reward-as-primitive ontology of Bellman-style RL, replacing value functions with priors over observations. There are formal links to policy-gradient RL.
- **Example.** Where RL would learn "state X has value 7," AIF says "outcomes that look like X are what I expect to see if my preferences hold."
- **Evidence status.** Strong repo support. [unified-theory__s2_limitations.txt lines 60–112](../active_inference/apps/workbench_web/priv/book/sessions/unified-theory__s2_limitations.txt).

### 10.7 Robotics / motor control
- **What it changes.** Removes the need for *inverse models* (mappings from "I want the hand here" to "send these motor commands"). Action becomes the fulfilment of proprioceptive predictions through low-level reflex arcs.
- **Example.** Reaching for a cup: the agent predicts proprioceptive consequences of having its hand on the cup; reflexes drive the muscles to produce those proprioceptive signals.
- **Evidence status.** Strong repo support. *"Movement control results from the fulfillment of (proprioceptive) predictions by action … Note that this scheme does not require specification of 'inverse models'."* — [continuous-time__s3_action_on_sensors.txt lines 229–232](../active_inference/apps/workbench_web/priv/book/sessions/continuous-time__s3_action_on_sensors.txt).

### 10.8 Statistical physics
- **What it changes.** Connects Active Inference to **Hamilton's principle of least Action**: living organisms follow paths of least resistance to a steady state, just as physical systems do.
- **Example.** A water droplet finds its lowest-energy shape; an organism finds its lowest-free-energy trajectory.
- **Evidence status.** Strong repo support, with explicit caveats about what the analogy means and doesn't mean. [high-road__s3_softmax_policy.txt lines 60–117](../active_inference/apps/workbench_web/priv/book/sessions/high-road__s3_softmax_policy.txt).

### 10.9 Philosophy of mind / cognitive science
- **What it changes.** Offers a unified mathematical formalism for predictive processing, embodied cognition, and enactivism. Crucially, it remains **agnostic about consciousness**.
- **Example.** A thermostat could, at a stretch, count as an Active Inference agent. A thermostat is not conscious. So Active Inference cannot, by itself, be a theory of consciousness.
- **Evidence status.** Strong repo support, again with explicit caveats. *"The framework is agnostic about consciousness. It explains perception, action, learning. … A tool consciousness research might USE. Not a theory that SOLVES consciousness."* — [shorts/specs/90.json](../shorts/specs/90.json).

### 10.10 AI literacy
- **What it changes.** Gives a principled vocabulary for distinguishing **embodied biological prediction** (an agent that predicts to keep itself alive) from **disembodied symbolic prediction** (a model that predicts the next token without any body, blanket, or stake in continued existence).
- **Example.** See [section 14](#14-what-active-inference-reveals-about-llm-limits).
- **Evidence status.** Interpretive synthesis. Repo gives the structural vocabulary; the LLM contrast is mine.

### 10.11 Education / learning theory
- **What it changes.** A learner can be modelled as an AIF agent whose precision over different information sources changes with experience. "Confusion" stops being a deficit and becomes a sign that the learner's model is being updated.
- **Example.** This very repo's curriculum has a four-tier (`kid` / `real` / `equation` / `derivation`) narration system precisely because depth and analogy are different precision-priorities for different learners.
- **Evidence status.** Partial repo support — present in the suite's design ([sessions.ex header](../active_inference/apps/workbench_web/lib/workbench_web/book/sessions.ex)), but not a settled application area in the literature.

That's eleven domains — comfortably above the brief's request for at least eight.

---

## 11. Active Inference "all the way down"?

This is one of the most evocative ideas the framework triggers — and one of the easiest to overstate.

**What the repo establishes.** Markov blankets — the statistical boundaries that separate an agent's internal states from its environment — can be **nested**. From the chapter 3 extract:

> *"Different fields use different notations. … One can use a Markov blanket to separate an entire organism from the environment or nest multiple Markov blankets within one another. For example, brains, organisms, dyads, and communities can be conceived in terms of different Markov blankets that are nested within one another."*
> — [high-road__s1_expected_free_energy.txt lines 53–57](../active_inference/apps/workbench_web/priv/book/sessions/high-road__s1_expected_free_energy.txt). Strong support.

**What this licenses (carefully).** The repo licenses claims like:
- A neuron has a Markov blanket. So does a brain. So does a person. So does a dyad. So does a community.
- Each level can be modelled as an Active Inference agent with its own generative model and its own preferred sensory states.

**What this *does not* license.** The repo does **not** establish:
- That DNA or a single gene is "doing Active Inference" in any non-metaphorical sense.
- That metabolism, in detail, is variational free-energy minimisation.
- That the Big Bang is the moment "free-energy minimisation switched on."

The most ambitious version of these ideas appears in [shorts/specs/101.json](../shorts/specs/101.json) — and the repo presents it explicitly as a **bonus thought experiment**, not as core theory:

> *"A thought experiment. Active Inference stem cells. No priors. No hints. Just: minimise surprise. Would agency self-organise? … Or further back: was the Big Bang just the flip of the switch?"*

**Evidence status.** The cells/dyads/communities ladder is repo-supported (5/5). The DNA-/gene-level extension is interpretive (2/5). The "Big Bang as F-minimisation" framing is speculative-bonus (1/5).

**A safe summary you can use.** *Active Inference scales gracefully across nested biological levels because Markov blankets nest. Whether that scaling reaches all the way down to gene expression or all the way back to physics is an open speculation, not a settled theorem.*

---

## 12. Instinct, signals, and alignment with reality

Here is a way to reframe a familiar word that you may find useful.

**The classical story.** "Instinct" is a hardcoded behaviour the organism is born with — a primitive that runs without learning.

**An Active Inference reframing.** Almost everything we'd call "instinct" can be re-described as **a high-precision prior** — a strong, often inherited, expectation about what certain signals mean and how to act on them. It's not that the organism is acting *without* a model; it's that the model has very tight priors that don't need much updating before they're useful.

This reframing has consequences:

- An organism's competence depends less on having the "right instincts" and more on **the quality of the signals the organism is coupled to.** If the signals are clean and informative, even modest priors work. If the signals are noisy or systematically distorted, even strong priors can produce maladaptive action.
- **Calibration is more important than completeness.** A creature that under-trusts its eyes in dim light, or over-trusts its inner narrative when the room is actually quiet, is not helped by stronger priors — it's helped by *better-tuned precision*.
- **"Contact with reality" is what gets compressed by the predict–act loop.** When the loop closes well, the agent's beliefs and the world's actual state are *coupled* through the Markov blanket. When it closes badly, the agent drifts.

**Evidence status.** Interpretive synthesis. The repo supports each piece — precision-weighting, the Markov-blanket coupling, the predictive-coding hierarchy — but the specific reframing of *instinct as alignment with quality signals* is a way of stitching them together, not a verbatim repo claim. Treat as a thinking tool, not a doctrine.

> **Why this matters.** It points at why "trust the data" and "calibrate your expectations" are practical Active-Inference advice, not management slogans. And it explains why a creature with bad signal hygiene — a model that has come to weight unreliable inputs heavily — can drift into maladaptive loops even when its "instincts" are fine.

---

## 13. Resonance: when agent and world fit each other

The repo doesn't use the word *resonance* as a technical AIF term. It does, however, ground a closely related idea using a 350-year-old physics analogy.

> *"On average, the internal and external states acquire a kind of (generalized) synchrony — just as we might anticipate on attaching a pendulum to each end of a wooden beam. Over time, as they synchronize, each pendulum becomes predictive of the other through the vicarious influence of the beam (Huygens 1673)."*
> — [high-road__s1_expected_free_energy.txt lines 76–80](../active_inference/apps/workbench_web/priv/book/sessions/high-road__s1_expected_free_energy.txt). Strong support.

In Huygens's experiment, two clock pendulums hung from a common beam will, over time, fall into anti-phase swing — they synchronise through the vicarious medium of the beam. Active Inference says the same thing happens between an agent's internal states and the world's external states, with the **Markov blanket** playing the role of the beam.

If you want to use the word "resonance" to mean **the well-coupled state in which an agent's beliefs and a world's dynamics become mutually predictive across the blanket**, that's a fine plain-English gloss. Just keep three things in mind:

- The repo's word is **synchrony**, not resonance.
- The mechanism is **statistical coupling through a shared boundary**, not literal physical resonance.
- The "fit" is between a model and a world *as the agent's sensors render it*, not between a model and the world-in-itself.

**Evidence status.** Repo supports the underlying claim (5/5). The word "resonance" is an evocative gloss (2/5) — useful for communication, dangerous if anyone takes it as a separate technical concept.

---

## 14. What Active Inference reveals about LLM limits

This section is interpretive. The repo provides the structural vocabulary; the LLM contrast is the synthesis the user asked for. Read it that way.

### What an LLM is, technically

Modern Large Language Models (GPT-style systems) are next-token predictors trained on very large corpora of human-produced text. Given a context, they output a probability distribution over the next token, sample from it, and repeat. After pre-training on raw text, they typically go through alignment phases — instruction tuning, RLHF (reinforcement learning from human feedback), and various kinds of safety filtering — that **shape what they will output**.

So an LLM is, at runtime:

- A function that maps token sequences to token sequences.
- Hosted inside servers and surfaced through interfaces (chat windows, APIs, products) designed by companies with goals.
- Trained on a corpus that reflects choices about what to include and what not to.
- Aligned with feedback that reflects what particular humans approved of.

### Where Active Inference draws the line

Active Inference is built around an **agent inside a Markov blanket** that predicts in order to **stay alive** (mathematically: stay within its viable steady-state distribution). That description carries several commitments LLMs do not satisfy:

| Active Inference agent | Modern LLM |
|---|---|
| Has a body / boundary that can be lost. | Has no body, no blanket, no continued existence to defend. |
| Predicts to **keep itself in viable bounds**. | Predicts the next token. There are no viable bounds the prediction is for. |
| **Acts** to change observations through a sensorimotor loop. | Emits text. The "actions" change downstream user prompts only insofar as the user reads them — there is no autonomous sensory loop. |
| Has **priors over its own existence** (preferences C). | Has no priors over its own continued existence. The closest analogue is an objective function imposed by training, not a self-maintained preference. |
| **Embodied biological intelligence.** | A **shaped artefact**: the output is a function of training data + alignment process + product design + the specific prompt. |

Each of these structural differences is reflected somewhere in the repo (the agent–world Markov blanket in [ARCHITECTURE.md](../ARCHITECTURE.md), preferences-as-priors in [glossary.ex `prior-preferences`](../active_inference/apps/workbench_web/lib/workbench_web/book/glossary.ex), action-as-inference in [glossary.ex `action-as-inference`](../active_inference/apps/workbench_web/lib/workbench_web/book/glossary.ex)).

### What this does *not* mean

- **LLMs are not useless.** Token prediction over high-quality corpora produces extraordinarily competent text. This guide was drafted with the help of one. Their utility is real.
- **LLMs are not trivially "doing inference."** Some of their dynamics *can* be modelled with variational tools; that's a separate research question.
- **LLMs are not conscious.** And LLMs are not conscious. Both directions of overclaim are common; neither is supported by the repo.

### What this *does* mean

- "Looking smart" and "being a natural intelligence" are different categories. An LLM's outputs have been **selected and filtered** so that they look like the kind of text humans approve of. That selection process is **a feature of the system**, not a bug — but it should make us careful when we read intelligence into the output.
- **The smart-ness on display in an LLM is partly a presentation choice.** It reflects the training corpus (what counts as "good" writing for a particular set of humans), the alignment process (what answers got rewarded by which raters), the product design (what the chat window prompts for), and the user interaction pattern. None of those would make sense for, say, a bacterium.
- **An embodied biological intelligence does *not* generate "what smart looks like" — it generates whatever keeps it alive.** The output that looks smart is a side-effect of the predict–act loop running well in a viable creature.

> **A careful one-liner.** *An LLM predicts text. A living organism predicts in order to keep itself alive. That difference matters more than the surface similarity of "they both predict."*

---

## 15. What this does *not* mean

Pre-empting common overclaims:

- **Active Inference does not prove humans never seek reward.** It replaces the *primitive* of reward with the primitive of preference-as-prior. Things people call rewards still appear in the math.
- **Active Inference does not solve consciousness.** The framework is *agnostic* about it. It explains perception, action, and learning. — [shorts/specs/90.json](../shorts/specs/90.json).
- **Active Inference does not make every prediction-machine alive.** A thermostat fits the math at the trivial end; a thermostat is not alive. The math doesn't care.
- **Dopamine is not "just precision".** The careful repo claim is that *policy precision (γ)* is the most robustly supported AIF mapping for dopaminergic gain, with explicit room for nuance.
- **Surprise is not (just) emotional surprise.** It's a defined mathematical quantity — the negative log-probability of an observation under the model.
- **LLMs are not natural intelligence.** They are also not stupid. Both extremes are wrong.
- **"All the way down" is a research speculation, not a theorem.** The Markov-blanket-nesting argument supports cells / organisms / communities. It does not, by itself, make DNA an Active Inference agent.
- **Active Inference is computationally hard at full scale.** Approximate inference (amortised, neural) is an active research area, not a solved problem. — [sessions.ex ch10 s2](../active_inference/apps/workbench_web/lib/workbench_web/book/sessions.ex).

---

## 16. Glossary

Definitions follow the repo's own usage, with quick plain-English glosses for the beginner. Where a phrase is the repo's verbatim "kid-tier" gloss it's quoted; otherwise it's my paraphrase. Full definitions and "phd" tiers live in [glossary.ex](../active_inference/apps/workbench_web/lib/workbench_web/book/glossary.ex).

| Term | Plain English |
|---|---|
| **Active Inference** | "Guessing well and acting well at the same time — one rule for both." A unified framework where perception, learning, and action all minimise variational free energy. |
| **Free Energy Principle (FEP)** | The broader claim that any system with a Markov blanket persists by appearing to minimise variational free energy. Active Inference is the FEP applied to action. |
| **Predictive processing** | A family of theories saying the brain is fundamentally a prediction engine. Active Inference is one mathematically explicit version. |
| **Generative model** | "The imaginary world the agent carries in its head." |
| **Generative process** | "The real world outside the agent." Different from the model. |
| **Markov blanket** | "A wall that separates the agent from the world — only sensors and muscles cross it." |
| **Surprise** | "How unexpected the sensor reading is." Mathematically: −ln P(o). |
| **Prediction error** | "The gap between what you expected and what happened." |
| **Variational free energy (F)** | "How surprised you'd be, but easier to compute." A tractable upper bound on surprise. |
| **Expected free energy (G)** | "Score a plan: add up how surprising you think it'll feel." Used to choose actions. |
| **Generative model parameters (A, B, C, D)** | A = how hidden states show up as observations; B = how states change with each action; C = preferences over outcomes; D = where you start guessing from. |
| **Prior** | "What you believed before the clue." |
| **Posterior** | "Your updated guess after seeing the clue." |
| **Precision (Π)** | "Strictness about a particular error. High = very strict." Inverse variance; weights how much an error counts. |
| **Policy precision (γ)** | "How decisive you are about picking the best plan." The repo's best candidate for what dopamine modulates. |
| **Attention** | In this framework, "raising precision on the channel that matters right now." |
| **Dopamine** | "Be more decisive about plans." Mapped (in this framework) to policy precision γ. |
| **Policy** | "A plan — a sequence of actions the agent might take." |
| **Action** | "A control variable that shapes observations via the sensory channel." Acts only on the sensors; never directly on beliefs. |
| **Perception** | "Updating your guess from what you see." |
| **Homeostasis** | Reactive correction back to a setpoint after deviation. |
| **Allostasis** | Predictive adjustment *before* deviation, e.g., raising heart rate before exercise. AIF's preferred framing of body regulation. |
| **Embodiment** | The fact that the agent has a body bounded by a Markov blanket — and that the body is what the predictions are *for*. |
| **Alignment** *(AI usage)* | The training and feedback processes by which an LLM's outputs are shaped to match a particular set of human preferences. *(Distinct from "alignment with reality" in [§12](#12-instinct-signals-and-alignment-with-reality).)* |
| **Resonance** *(my gloss)* | The well-coupled state in which an agent's beliefs and a world's dynamics become mutually predictive across the Markov blanket. The repo's word for the same idea is **synchrony**. |
| **LLM** | Large Language Model; a next-token predictor trained on very large text corpora and shaped further by alignment processes. |
| **GPT-style system** | A specific family of LLMs running in a product context (e.g., ChatGPT, Claude). Subject to all the training and alignment caveats above. |

---

## 17. Evidence map (compact)

A condensed version of [02_CLAIM_EVIDENCE_MAP.md](02_CLAIM_EVIDENCE_MAP.md). For details, follow that file.

| Section / Claim | Repo source | Strength | Notes |
|---|---|---|---|
| §1 The big idea / "guessing well and acting well at the same time" | glossary `active-inference` | 5 | Verbatim gloss. |
| §2 One-paragraph summary | glossary + equations.ex `eq_2_5`, `eq_2_6` | 5 | Definition-level. |
| §3 Surprise as −ln P(o) | glossary `surprise`; equations.ex `eq_3_1` | 5 | Verified. |
| §4 Predict–act loop | equations.ex `eq_4_13`, `eq_4_14` | 5 | Verified against source and appendix. |
| §5 Action acts only on sensors | equations.ex `eq_8_2_continuous_generative_process` | 5 | Architectural invariant. |
| §6 Precision = inverse variance | glossary `precision` | 5 | Verbatim. |
| §7 Dopamine ↔ policy precision γ | glossary `DA`; shorts/specs/93.json; sessions.ex ch5 s3 | 5 | Repo flags it as *theoretical commitment with empirical support*, not identity. |
| §8 AIF replaces reward / value functions with preferences-as-priors | book extract: high-road__s3_softmax_policy.txt; unified-theory__s2_limitations.txt | 5 | Direct quote. |
| §9 Baby's first breath as analogy | unified-theory__s2_limitations.txt (predictive interoception) | **1 (speculative analogy)** | Specific story not in repo. Surrounding framework is repo-supported. |
| §10 Active Inference across disciplines | sessions.ex chapters 5–10; book extracts | 5 (most domains), 3 (AI literacy), 4 (psychiatry / education) | 11 domains covered. |
| §11 "All the way down" | high-road__s1 (nested blankets) + shorts/specs/101.json (speculative bonus) | 2 | Cells/organisms/communities supported; DNA / Big Bang flagged speculative. |
| §12 Instinct as alignment with quality signals | glossary `precision`, `precision-weighting`, `predictive-coding`; book extract: high-road__s1 | 2 (interpretive synthesis) | Plausible re-description; not a verbatim repo claim. |
| §13 Resonance as agent–world synchrony | book extract: high-road__s1 (Huygens pendulum) | 2 (gloss) / 5 (underlying claim) | Repo says "synchrony"; "resonance" is my evocative gloss. |
| §14 LLMs vs Active Inference agents | ARCHITECTURE.md (agent vs world plane); glossary `action-as-inference`, `prior-preferences` + general AI background | 4 (structural distinction) / 3 (LLM training/alignment context — general background) | Synthesis labelled accordingly. |
| §15 What this does not mean | shorts/specs/90.json; sessions.ex ch10 s2; shorts/specs/93.json | 5 | All cautions present in repo myth-busting + limitations sections. |

---

## 18. Reader's next questions

A handful of questions that, if you carry them forward, will deepen your understanding faster than another read of this guide:

1. **Is *my* model well-calibrated to the signals I'm coupled to?** What channels do I currently weight too high? Too low?
2. **What would a "reward" be if I had to describe it as a prior over my preferred observations?** Try this on a craving you've had recently.
3. **When I act to get more information instead of acting to get an outcome, am I following epistemic value or pragmatic value?** Most of life is a mix. Notice the mix.
4. **Where in my life am I *acting* as the way to reduce free energy versus *thinking harder*?** When does each strategy work, and when does it fail?
5. **What does it mean to say my body is doing Active Inference *all the time*, below conscious awareness?** Try to feel one autonomic regulation (heart rate during a deep breath, pupil response to a bright light) as a high-precision interoceptive policy doing its job.
6. **When I read fluent text from an LLM, what is the model actually doing, and what assumptions am I making about it?** Run the test in [§14](#14-what-active-inference-reveals-about-llm-limits) on three different outputs.
7. **Where would I draw the line between "an agent that predicts to live" and "a system that just predicts"?** Is the line sharp? Fuzzy? What does Active Inference let me say about the boundary?
8. **What's a domain Active Inference *shouldn't* be applied to?** Try to find one. The exercise will sharpen everything else.

---

> *Built from the repo's [README.md](../README.md), [ARCHITECTURE.md](../ARCHITECTURE.md), [equations.ex](../active_inference/apps/active_inference_core/lib/active_inference_core/equations.ex), [glossary.ex](../active_inference/apps/workbench_web/lib/workbench_web/book/glossary.ex), [chapters.ex](../active_inference/apps/workbench_web/lib/workbench_web/book/chapters.ex), [sessions.ex](../active_inference/apps/workbench_web/lib/workbench_web/book/sessions.ex), the attributed CC BY-NC-ND derivative extracts in [priv/book/sessions/](../active_inference/apps/workbench_web/priv/book/sessions/), and the 100-short curriculum in [shorts/specs/](../shorts/specs/) — all built on Parr, Pezzulo & Friston (2022) Active Inference, MIT Press. The book itself is gitignored per [BOOK_SOURCES.md](../BOOK_SOURCES.md). Apply the frameworks; never reproduce the prose.*
