# ADR-002: Bird-Song Call-and-Response Lab

**Date:** 2026-05-13
**Phase:** Initial implementation, navigation integration, and TDD plan
**Status:** Scaffolded and quality-gated

## 1. Executive Summary

[PROPOSED ADDITION] Add a new, separate `BirdsongCallResponse` lab under
`/labs/birdsong-call-response`. This must not replace or extend the existing
Bird Meadow lab at `/labs/meadow`.

[VERIFIED REPO FACT] Initial scaffolding for this plan now exists in the repo:
`SharedContracts.Blanket.birdsong_default/0`,
`WorldPlane.Worlds.BirdsongCallResponse`,
`AgentPlane.BundleBuilder.Birdsong`, `AgentPlane.BirdsongObsAdapter`,
`AgentPlane.BirdsongSongbook`, `WorkbenchWeb.Episode.BirdsongEpisode`, and
`WorkbenchWeb.BirdsongCallResponseLive.Index`.

[VERIFIED REPO FACT] The current implementation includes Dirichlet-categorical
songbook learning over `P(response_motif | heard_motif)`. The learned table is
converted into observation preferences `C`; action selection still goes through
native Jido `Perceive -> Plan -> Act` and the existing
`ActiveInferenceCore.DiscreteTime` VFE/EFE/policy-posterior path.

[VERIFIED REPO FACT] Browser QA on 2026-05-13 trained the symbolic sequence
`a,b,c,d -> d,c,b,a`, ran the Active Inference response, and produced
`[:d, :c, :b, :a]` as a real 16 kHz 16-bit WAV response.

[VERIFIED REPO FACT] Navigation and guide discoverability now expose the new
Birdsong lab and the existing Bird Meadow lab from the global nav, `/labs`,
`/guide/labs`, `/guide`, `/guide/workbench`, and `/guide/features`.

[VERIFIED REPO FACT] The workbench is an Elixir umbrella whose plane split is:
`active_inference_core` for math, `agent_plane` for the native Jido generative
model, `world_plane` for generative processes, `shared_contracts` for Markov
blanket packets, and `workbench_web` for orchestration/UI. Evidence:
`active_inference/README.md`, `active_inference/ReadmeAI.MD`,
`active_inference/apps/*/mix.exs`, and plane-separation tests.

[VERIFIED REPO FACT] The existing Bird Meadow already has tokenized song events,
hearing observations, self-sang proprioception, multi-agent stepping, a
`MeadowObsAdapter`, `BundleBuilder.Meadow`, `MeadowEpisode`, and a LiveView at
`/labs/meadow`. Evidence: `world_plane/lib/world_plane/worlds/bird_meadow.ex`,
`worlds/bird_meadow/hearing_model.ex`, `agent_plane/lib/agent_plane/bundle_builder/meadow.ex`,
`workbench_web/lib/workbench_web/episode/meadow_episode.ex`, and
`workbench_web/lib/workbench_web/live/meadow_live/index.ex`.

[PROPOSED ADDITION] The smallest scientifically honest demo should be a
motif-level, discrete-time Active Inference call-and-response agent with a pure
Elixir audio bridge:

- Accept a short WAV or a built-in demo chirp sequence.
- Extract categorical motif observations from signal features.
- Infer hidden call cause, turn phase, interaction mode, and previous self song.
- Evaluate candidate response policies using the existing VFE/EFE/policy
  posterior path in `ActiveInferenceCore.DiscreteTime`.
- Emit a response action through native Jido.
- Render the selected symbolic response policy to a WAV using a deterministic
  parametric chirp synthesizer.
- Expose beliefs, per-policy F, G, posterior over policies, selected action, and
  generated audio in the new lab UI.

[ASSUMPTION] The MVP bird-song domain is synthetic/motif-based, not
species-recognition and not waveform-level Active Inference. Arbitrary real bird
clips can be accepted as input, but the MVP must label low-confidence/OOD
feature extraction instead of pretending to understand species-specific song.

## 2. Repo Reconnaissance Report

[VERIFIED REPO FACT] Top-level structure includes documentation, an
`active_inference` umbrella, `jido`, standalone `learninglabs`, and support
folders. The feature belongs in `active_inference`, not standalone
`learninglabs`, because the requested Workbench feature must use native Jido and
the existing Active Inference runtime.

[VERIFIED REPO FACT] Languages/tooling: Elixir umbrella with Mix. Phoenix
LiveView is used in `workbench_web`; no Node build is required for the current
UI baseline. Evidence: `active_inference/mix.exs`,
`apps/workbench_web/mix.exs`, `active_inference/README.md`.

[VERIFIED REPO FACT] Build/test commands:

- `cd active_inference && mix test`
- `cd active_inference && mix phx.server`
- `cd active_inference && mix q` / `mix quality` runs `format --check-formatted`
  and `test --warnings-as-errors`.

Evidence: `active_inference/README.md`, `active_inference/mix.exs`,
`.github/workflows/ci.yml`.

[VERIFIED REPO FACT] CI runs compile with warnings as errors, the fast suite,
and an audit-anchor subset including meadow VFE/ELBO/naming/blanket/Dirichlet
tests. Evidence: `.github/workflows/ci.yml`.

[VERIFIED REPO FACT] Documentation convention: project-level ADRs live under
`active_inference/docs/decisions/`; docs use `:verified`, `:scaffolded`, and
`:uncertain` vocabulary. Evidence: `active_inference/docs/ReadmeAI.MD`,
`active_inference/docs/decisions/ReadmeAI.MD`, `docs/INDEX.md`.

[VERIFIED REPO FACT] Jido constraints: agent logic is pure through `cmd/2`,
directives represent external effects, cross-agent communication uses
`Jido.Signal`, and tests should start with pure `cmd/2` cases. Evidence:
`CLAUDE.md`, `knowledgebase/jido/00-philosophy.md`,
`knowledgebase/jido/02-actions.md`, `jido/usage-rules.md`.

[VERIFIED REPO FACT] Active Inference math exists in
`ActiveInferenceCore.DiscreteTime`, including state-belief sweeps,
variational free energy, expected free energy, policy posterior, action
selection, and fresh belief rollouts. Evidence:
`apps/active_inference_core/lib/active_inference_core/discrete_time.ex`.

[VERIFIED REPO FACT] `AgentPlane.ActiveInferenceAgent` is a real
`use Jido.Agent` module with `Perceive`, `Plan`, `Act`, and `Step` routes.
Evidence: `apps/agent_plane/lib/agent_plane/active_inference_agent.ex` and
`apps/agent_plane/lib/agent_plane/actions/*.ex`.

[VERIFIED REPO FACT] Existing audio surfaces are narration/speech playback and
book podcast sync/proxy paths, not bird-song ingestion or bird-song synthesis.
Evidence: `WorkbenchWeb.SpeechController`, `Mix.Tasks.WorkbenchWeb.SyncAudio`,
`LearningLive.Chapter`, and `LearningLive.Session`.

[NOT FOUND] I did not find a repo implementation of bird-song WAV ingestion,
bird-song feature extraction, bird-song response synthesis, or a waveform-level
Active Inference controller.

## 3. Evidence Table

| Claim | Evidence path(s) | Status | Notes |
|---|---|---|---|
| Workbench is an Elixir umbrella. | `active_inference/mix.exs`, `active_inference/README.md` | [VERIFIED REPO FACT] | `apps_path: "apps"`. |
| Core math is pure list-based POMDP math. | `apps/active_inference_core/lib/active_inference_core/discrete_time.ex`, `math.ex` | [VERIFIED REPO FACT] | VFE, EFE, policy posterior, sweeps. |
| Agents are native Jido. | `apps/agent_plane/lib/agent_plane/active_inference_agent.ex`, `jido_instance.ex`, `agent_plane/mix.exs` | [VERIFIED REPO FACT] | Uses path dependency `../../../jido`. |
| World plane is the generative process and must not depend on agent/core. | `apps/world_plane/mix.exs`, `test/plane_separation_test.exs` | [VERIFIED REPO FACT] | Important constraint for audio world placement. |
| Shared contracts enforce blanket packets. | `shared_contracts/lib/shared_contracts/*.ex` | [VERIFIED REPO FACT] | Observation/action validation is in constructors. |
| Existing bird lab exists. | `router.ex`, `meadow_live/index.ex`, `bird_meadow.ex` | [VERIFIED REPO FACT] | Must be protected and not replaced. |
| Existing bird lab is tokenized meadow hearing/singing, not user audio upload. | `bird_meadow/hearing_model.ex`, `MeadowObsAdapter`, `MeadowLive` | [VERIFIED REPO FACT] | Uses tokens `:t1..:t4`, no WAV ingestion. |
| There is existing speech/audio proxy. | `speech_controller.ex`, `sync_audio.ex` | [VERIFIED REPO FACT] | Narration only; not an inference/synthesis path for birds. |
| Continuous/hybrid models are registered but not runtime-complete. | `ActiveInferenceCore.Models`, `Docs.VerificationManifest` | [VERIFIED REPO FACT] | Use discrete POMDP for MVP. |
| A new lab route exists beside `/labs/meadow`. | `workbench_web/router.ex` | [VERIFIED REPO FACT] | Route is `/labs/birdsong-call-response`. |
| Red tests are clear but not added in this ADR. | Existing ExUnit test layout | [PROPOSED ADDITION] | Adding executable failing tests now would intentionally break CI. |

## 4. Constraints Summary

[VERIFIED REPO FACT] Architectural constraints:

- `world_plane` cannot import `agent_plane` or `active_inference_core`.
- `agent_plane` cannot import `world_plane`.
- `workbench_web` is allowed to orchestrate both planes.
- Agent actions must be native `Jido.Action` modules called through
  `ActiveInferenceAgent.cmd/2` or runtime signals.
- World-agent exchange must remain `ObservationPacket` and `ActionPacket`.

[VERIFIED REPO FACT] Dependency constraints:

- Current runtime is Elixir/BEAM-first.
- No evidence supports adding Python DSP or external AI services for this
  feature.
- `Nx` exists as an optional dependency in `active_inference_core`, but pure
  list math remains the default.

[VERIFIED REPO FACT] Runtime constraints:

- Policy enumeration is exponential in action count and horizon.
- Existing meadow comments cap UI depth for responsiveness.
- Therefore MVP should use a small action vocabulary and horizon 1-2.

[VERIFIED REPO FACT] UI constraints:

- Workbench labs are Phoenix LiveViews with inline CSS.
- Existing meadow UI is a separate lab route.
- New lab must be a separate LiveView, not a mutation of MeadowLive.

[VERIFIED REPO FACT] Test constraints:

- ExUnit tests are app-local.
- CI compiles with warnings as errors.
- Audit anchors exist for VFE, ELBO, naming, blanket separation, and Dirichlet.

[PROPOSED ADDITION] Data constraints:

- No hidden data downloads.
- Include only tiny synthetic WAV fixtures or generate fixtures deterministically
  in tests.
- Arbitrary real bird clips are out-of-distribution unless feature confidence is
  high under the documented motif extractor.

## 5. Recommended Feature Scope

### MVP: scientifically honest, fully working demo

[PROPOSED ADDITION] Name: `Birdsong Call-Response`.

[PROPOSED ADDITION] User workflow:

1. User opens `/labs/birdsong-call-response`.
2. User chooses a built-in motif call or uploads a short WAV.
3. UI extracts and displays motif observations.
4. User starts the agent.
5. Agent receives the observation sequence through a new bird-song blanket.
6. `Perceive -> Plan -> Act` runs through native Jido and existing
   `ActiveInferenceCore.DiscreteTime`.
7. UI displays posterior over hidden states, F, G, policy posterior, selected
   response action, and generated response WAV.
8. User can play or inspect the response audio and the internal quantities.

[PROPOSED ADDITION] Minimum scientific claim:

The MVP is a discrete, motif-level Active Inference agent that infers hidden
causes of an incoming call and selects a response policy by minimizing expected
free energy under a categorical generative model. The signal layer is a
deterministic audio encoding/decoding bridge.

[PROPOSED ADDITION] Explicitly not claimed:

- Not species identification.
- Not learned birdsong syntax.
- Not waveform-level continuous Active Inference.
- Not classifier plus canned audio, because policy selection must use VFE/EFE
  and the response WAV is rendered from the selected action sequence.

### Stronger follow-on

[PROPOSED ADDITION] Version 2 should add factorized multi-step syntax:
motif grammar, tempo/rhythm hidden factors, Dirichlet learning of the likelihood
matrix from user-provided motifs, and self-audition as a mixed exteroceptive and
proprioceptive stream.

[PROPOSED ADDITION] Version 3 should add a hybrid model: high-level discrete
motif policies choose continuous chirp parameters, and low-level generalized
filtering controls parametric synthesis trajectories.

## 6. Mathematical Specification

### 6.1 System boundary

[PROPOSED ADDITION] Discrete-time agent/environment boundary:

- External/generative-process state `e_t`: the uploaded or generated incoming
  call token at time `t`, the current turn phase, and the agent's last emitted
  response token as heard through self-audition.
- Sensory state `o_t`: a categorical observation packet crossing the Markov
  blanket.
- Internal state `q_t`: the agent's variational beliefs over hidden states.
- Active state `a_t`: a selected response action emitted as an
  `ActionPacket`.

[PROPOSED ADDITION] The agent never reads waveform samples or world internals.
The world never reads beliefs, F, G, or policy posteriors.

### 6.2 Time model

[PROPOSED ADDITION] MVP is hybrid only at the interface:

- Signal time: WAV samples at `f_s = 16_000 Hz` for extraction/rendering.
- Inference time: discrete motif ticks of `Delta = 150 ms` or one extracted
  syllable per tick.
- Bridge: the extractor maps sample frames to categorical observation ticks;
  the renderer maps response actions back to sample frames.

[ASSUMPTION] Discrete motif ticks are sufficient for MVP because the existing
repo's verified runtime is discrete POMDP Active Inference, and continuous-time
models are only scaffolded.

### 6.3 Observation representation

[PROPOSED ADDITION] Observation is categorical and flattened for the existing
core:

```
o_t = (h_t, u_t, x_t, r_t)
```

where:

- `h_t in H = {silence, a, b, c, d, unknown}` is the heard incoming motif.
- `u_t in U = {call, gap, response_due, refractory}` is the observed turn cue
  derived by the world from the input timeline.
- `x_t in X = {none, a, b, c, d}` is self-audition of the previous action.
- `r_t in R = {none, poor_fit, good_fit}` is a categorical consequence of the
  pair `(heard motif, self song, interaction mode)`.

Thus `|O| = 6 * 4 * 5 * 3 = 360`.

[PROPOSED ADDITION] Encoding:

```
idx(o) =
  (((idx_H(h) * |U| + idx_U(u)) * |X| + idx_X(x)) * |R| + idx_R(r))
```

`BirdsongObsAdapter.to_obs_vector/1` returns one-hot vector `o_t` of length 360.

[PROPOSED ADDITION] What is lost by not modeling raw waveform:

- Fine frequency modulation, timbre, harmonic structure, reverberation, and
  species-specific syntax are discarded.
- The demo tests inference over communicative motifs, not acoustic realism.

### 6.4 Audio extractor

[PROPOSED ADDITION] Deterministic WAV extractor:

- Accept PCM WAV, mono, 16-bit, `f_s = 16_000 Hz`, duration `<= 5 s`.
- Segment into frames of 20 ms with 10 ms hop.
- Frame energy:

```
E_k = sqrt((1/N) * sum_{n=0}^{N-1} x_{k,n}^2)
```

- Active frame if `E_k > theta_E`, where `theta_E` is `max(0.02, 0.15 *
  percentile_95(E))`.
- Merge active runs shorter than 40 ms into neighbors; drop segments shorter
  than 30 ms.
- For each segment, estimate a coarse pitch score by zero-crossing rate or
  autocorrelation peak. MVP should prefer autocorrelation when feasible:

```
R(lag) = sum_n x_n x_{n-lag}
f_hat = f_s / argmax_lag R(lag)
```

with lag range corresponding to 1.5 kHz to 6.0 kHz.

- Map each segment to motif bins:

```
a: 1.5-2.4 kHz
b: 2.4-3.3 kHz
c: 3.3-4.2 kHz
d: 4.2-6.0 kHz
unknown: out of range or confidence below theta_conf
silence: no active segment at the tick
```

[ASSUMPTION] Frequency bins are deliberately synthetic/demo bins, not biological
species labels.

### 6.5 Action and synthesis model

[PROPOSED ADDITION] Action vocabulary:

```
A = {listen, sing_a, sing_b, sing_c, sing_d}
```

`listen` produces `x_{t+1} = none`; `sing_j` produces `x_{t+1} = j`.

[PROPOSED ADDITION] Rendering from selected action sequence:

For a response token `j`, render a chirp:

```
y_j[n] = alpha * w[n] *
         sin(2*pi*(f0_j*n/f_s + (f1_j - f0_j)*n^2/(2*N*f_s)))
```

where:

- `n = 0..N-1`
- `N = duration_j * f_s`
- `w[n] = sin(pi*n/(N-1))^2` is a smooth amplitude envelope.
- `alpha <= 0.7` prevents clipping.
- token frequencies:
  - `a: f0=1800, f1=2400`
  - `b: f0=2600, f1=3200`
  - `c: f0=3400, f1=4000`
  - `d: f0=4500, f1=5200`

Concatenate rendered tokens with 40 ms silence gaps, clamp to `[-1,1]`, encode
as 16-bit PCM WAV.

[PROPOSED ADDITION] The renderer is deterministic and local; it is not an AI
audio model and does not call external services.

### 6.6 Generative process

[PROPOSED ADDITION] The world-side process stores:

```
E = {
  input_tokens: [h_0, ..., h_T],
  phase_tokens: [u_0, ..., u_T],
  last_self: x_t,
  t,
  response_events: [{t, action, token}],
  terminal?: t >= T and response emitted or max_steps reached
}
```

On `step(pid, %ActionPacket{action: a_t})`:

1. Map `a_t` to `x_{t+1}`.
2. Compute `r_{t+1}` from response fit:

```
R_map_echo(h) = h
R_map_complement(a)=b, R_map_complement(b)=a,
R_map_complement(c)=d, R_map_complement(d)=c

fit(h, x, m) =
  good_fit if h in {a,b,c,d} and x = R_m(h)
  none     if x = none
  poor_fit otherwise
```

3. Advance the external token index.
4. Return `ObservationPacket` with channels `(heard_motif, turn_phase,
   self_sang_motif, response_fit)`.

[VERIFIED REPO FACT] This process belongs in `world_plane` and must not call
`ActiveInferenceCore` or `AgentPlane`.

### 6.7 Generative model

[PROPOSED ADDITION] Hidden state:

```
s_t = (m_t, p_t, z_t, x_t)
```

where:

- `m_t in M = {silence, a, b, c, d, unknown}` is the inferred current call
  motif.
- `p_t in P = {call, gap, response_due, refractory}` is the inferred turn phase.
- `z_t in Z = {echo, complement, withhold}` is interaction mode.
- `x_t in X = {none, a, b, c, d}` is previous self song.

`|S| = 6 * 4 * 3 * 5 = 360`.

[PROPOSED ADDITION] Observation likelihood:

```
P(o_t | s_t) = A[o_t, s_t]
             = P(h_t | m_t) P(u_t | p_t) P(x^o_t | x_t)
               P(r_t | m_t, z_t, x_t, p_t)
```

Each factor is categorical with an epsilon floor `epsilon = 1.0e-6` and columns
renormalized to 1.

Recommended likelihoods:

```
P(h=m | m) = 0.90 for m != unknown
P(h=unknown | m) = 0.04
remaining mass distributed across other motifs

P(u=p | p) = 0.92
P(x^o=x | x) = 0.97

P(r=good_fit | m,z,x,p=response_due) = 0.90 if x = R_z(m)
P(r=poor_fit | m,z,x,p=response_due) = 0.90 if x != none and x != R_z(m)
P(r=none | x=none) = 0.95
```

[PROPOSED ADDITION] Transition model:

```
P(s_{t+1} | s_t, a_t) = B^{a_t}[s_{t+1}, s_t]
```

Factorized before flattening:

```
P(m' | m, p)       : mostly persistent during call/gap, drift to silence after call
P(p' | p, a)       : call -> gap -> response_due -> refractory -> call
P(z' | z)          : 0.95 persistence, small mode drift
P(x' | a)          : deterministic self-audition consequence of action
```

For `a = sing_j`, `P(x'=j | a)=0.99`; for `a = listen`,
`P(x'=none | a)=0.99`; remaining mass is epsilon leak for numerical stability.

[PROPOSED ADDITION] Preferences:

`C` is a log preference vector over observations:

```
C_o = log P_pref(o)
```

Construct logits:

```
L(o) =
  +lambda_fit     if response_fit(o) = good_fit
  +lambda_listen  if turn_phase(o) in {call,gap} and self_sang(o)=none
  -lambda_bad     if response_fit(o)=poor_fit
  -lambda_intrude if turn_phase(o)=call and self_sang(o)!=none
  0 otherwise
```

Then:

```
P_pref(o) = softmax(L(o))
C_o = log(max(P_pref(o), epsilon))
```

Default values:

```
lambda_fit = 4.0
lambda_listen = 1.0
lambda_bad = 4.0
lambda_intrude = 2.0
```

[PROPOSED ADDITION] Initial prior:

```
D_s = P(s_0)
```

Default: uniform over `m` and `z`, peaked on `p=call`, peaked on `x=none`.
Normalize over flattened states.

[PROPOSED ADDITION] Habit prior:

`E` is `nil` in MVP, so the repo policy posterior uses a uniform habit prior.
A later version may add weak `E` favoring `listen` before response_due.

### 6.8 Objective functions and sign conventions

[VERIFIED REPO FACT] Use `ActiveInferenceCore.DiscreteTime`, not a new
policy-scoring implementation.

[PROPOSED ADDITION] Current-state variational free energy for policy `pi`:

```
F_pi = sum_tau F_{pi,tau}
F_{pi,tau} =
  s^pi_tau dot (
    log s^pi_tau
    - log_likelihood_tau
    - log_prior_tau
  )
```

where:

- `s^pi_tau` is the variational categorical state belief at rollout time
  `tau`.
- `log_likelihood_tau = log(A)^T o_t` for the current observed tick and zero
  for future unobserved ticks under the repo's receding-horizon path.
- `log_prior_0 = log D`; for `tau>0`,
  `log_prior_tau = log(B^{a_{tau-1}} s^pi_{tau-1})`.

This is minimized; lower `F` means better current-observation fit under the
recognition density and prior.

[PROPOSED ADDITION] Expected free energy for policy `pi`:

```
G_pi = sum_{tau > 0} G_{pi,tau}
G_{pi,tau} = H dot s^pi_tau + o^pi_tau dot (log o^pi_tau - C)
o^pi_tau = A s^pi_tau
H_j = - sum_i A_{i,j} log A_{i,j}
```

Interpretation:

- `H dot s` is expected ambiguity.
- `o dot (log o - C)` is risk against preferred outcomes.
- `C` is log preference, not scalar reward.

[VERIFIED REPO FACT] The production policy posterior is:

```
Q(pi) = softmax((log E - F - G) / temperature)
```

with `E=nil` becoming uniform log habit.

[PROPOSED ADDITION] Present vs future separation:

- `F` scores current-observation inference under each policy-conditioned belief
  chain.
- `G` scores future predicted observations, dropping the current tick
  (`tau=0`) in the repo's receding-horizon semantics.

### 6.9 Inference/update scheme

[VERIFIED REPO FACT] Existing state update implements the message:

```
epsilon^pi_tau =
  log(A)^T o_tau
  + log(B^pi_tau) s^pi_{tau-1}
  + log(B^pi_{tau+1})^T s^pi_{tau+1}
  - log s^pi_tau

v^pi_tau <- log s^pi_tau + eta epsilon^pi_tau
s^pi_tau <- softmax(v^pi_tau)
```

[PROPOSED ADDITION] MVP settings:

- `n_iters = 3` to match current default sweep performance.
- policy horizon `H = 2` initially.
- action count `|A| = 5`, so `|Pi| = 25`.
- deterministic test mode sets `action_selection: :argmax` and fixed
  temperature.
- UI mode may use `:sample` only if seeded/reproducibility controls are added.

[PROPOSED ADDITION] Exact vs approximate:

- Online inference uses mean-field variational message passing through the
  existing discrete core.
- Exact inference is only for toy audit tests using `AgentPlane.ExactInference`.

### 6.10 Learning scheme

[PROPOSED ADDITION] MVP fixed:

- Audio feature thresholds.
- Motif alphabet.
- A, B, C, D matrices.
- Chirp synthesis parameters.

[PROPOSED ADDITION] Inferred online:

- Posterior beliefs over `s_t`.
- Policy posterior over candidate response policies.
- Selected response action.

[PROPOSED ADDITION] Later learnable:

- Dirichlet updates for A from labeled/confirmed motifs.
- Dirichlet updates for B over turn transitions.
- User/session-specific preference strengths.

### 6.11 Baselines

[PROPOSED ADDITION] Baseline for scientific contrast:

- Classifier/template baseline: extract dominant motif and render a fixed
  response map `a->b`, `b->a`, `c->d`, `d->c`.
- It must be labeled "non-active-inference baseline" and must not be used as
  the primary feature path.

## 7. TDD Plan

[PROPOSED ADDITION] Do not start by wiring the UI. Write tests in this order:

1. `shared_contracts/test/birdsong_blanket_test.exs`
   - Red: `Blanket.birdsong_default/0` does not exist.
   - Prove observation channels and action vocabulary.

2. `world_plane/test/worlds/birdsong_call_response/audio_features_test.exs`
   - Red: extractor does not exist.
   - Prove generated demo WAV tokenizes to expected motifs.

3. `world_plane/test/worlds/birdsong_call_response/synth_test.exs`
   - Red: renderer does not exist.
   - Prove WAV header, sample rate, duration, and amplitude range.

4. `world_plane/test/worlds/birdsong_call_response_test.exs`
   - Red: world module does not exist.
   - Prove `WorldBehaviour`, step semantics, terminal handling, response fit,
     and blanket packet validity.

5. `agent_plane/test/birdsong_obs_adapter_test.exs`
   - Red: adapter does not exist.
   - Prove encode/decode round trip and one-hot normalization.

6. `agent_plane/test/bundle_builder/birdsong_test.exs`
   - Red: builder does not exist.
   - Prove A/B/C/D shapes, column normalization, log-C normalization, action
     vocabulary, policies, provenance, and no world-plane imports.

7. `agent_plane/test/birdsong_policy_test.exs`
   - Red: policy ranking not implemented.
   - Prove heard `a` under `response_due` ranks `sing_b` above unrelated
     actions under complement mode, with deterministic argmax.

8. `agent_plane/test/birdsong_exact_toy_test.exs`
   - Red: tiny exact comparison not present.
   - Prove approximate posterior agrees with exact posterior on a tiny 2-state
     special case within tolerance.

9. `workbench_web/test/workbench_web/episode/birdsong_episode_test.exs`
   - Red: episode wrapper does not exist.
   - Prove Perceive -> Plan -> Act -> world step -> rendered response summary.

10. `workbench_web/test/live/birdsong_call_response_live_test.exs`
    - Red: route/LiveView does not exist.
    - Prove upload/demo input, run, policy table, generated audio element, and
      graceful invalid-WAV error.

[PROPOSED ADDITION] Property/numerical tests:

- Every probability vector sums to 1 within `1.0e-6`.
- Every A and B column sums to 1 within `1.0e-6`.
- KL divergence tests reuse `ActiveInferenceCore.Math.kl/2` non-negativity.
- F/G vectors finite for silence, unknown, and low-confidence observations.
- Seeded deterministic policy ranking is reproducible.
- Generated samples stay finite and within `[-1,1]` before PCM conversion.

[PROPOSED ADDITION] Fixture strategy:

- Generate WAV fixtures in tests with the same synth module.
- Keep one tiny static WAV only if generation makes tests unclear.
- No external datasets.
- Use `@tag :slow_experiment` only for longer UI/audio browser tests if needed,
  matching the existing CI exclusion style.

## 8. Test Matrix

| Layer | Test file | What it proves |
|---|---|---|
| Shared contracts | `shared_contracts/test/birdsong_blanket_test.exs` | Blanket vocabulary and packet rejection. |
| World process | `world_plane/test/worlds/birdsong_call_response_test.exs` | Generative process step contract, terminal states, response fit. |
| Audio extraction | `world_plane/test/worlds/birdsong_call_response/audio_features_test.exs` | WAV -> motif observations. |
| Audio synthesis | `world_plane/test/worlds/birdsong_call_response/synth_test.exs` | action sequence -> valid WAV. |
| Adapter | `agent_plane/test/birdsong_obs_adapter_test.exs` | observation flattening and one-hot vector. |
| Bundle | `agent_plane/test/bundle_builder/birdsong_test.exs` | A/B/C/D validity and tractable policy set. |
| Math behavior | `agent_plane/test/birdsong_policy_test.exs` | EFE-driven response policy ranking. |
| Exact toy | `agent_plane/test/birdsong_exact_toy_test.exs` | Approximate inference sanity vs exact small model. |
| Episode | `workbench_web/test/workbench_web/episode/birdsong_episode_test.exs` | Native Jido loop integrated with world. |
| LiveView | `workbench_web/test/live/birdsong_call_response_live_test.exs` | User workflow and interpretable outputs. |
| Docs | `workbench_web/test/docs/api_catalog_test.exs` | New public functions need docs or tracked allowlist. |

## 9. Acceptance Criteria

[PROPOSED ADDITION] Black-box acceptance:

- `/labs/birdsong-call-response` loads without touching `/labs/meadow`.
- Built-in demo call produces a visible observation sequence.
- Uploaded valid PCM WAV either tokenizes or returns a clear validation error.
- Running the lab creates a native Jido agent and executes `Perceive -> Plan ->
  Act`.
- UI shows current belief marginal, F vector, G vector, policy posterior, and
  selected response action.
- UI renders a playable response WAV.
- A deterministic fixture produces the same response policy under seeded
  settings.
- Invalid WAV, silence-only clip, too-long clip, and OOD clip fail gracefully.
- No world-plane code imports `AgentPlane` or `ActiveInferenceCore`.
- No agent-plane code imports `WorldPlane`.
- Existing Bird Meadow tests still pass.

[PROPOSED ADDITION] Latency target:

- Built-in demo inference plus synthesis should complete within 1 second on a
  typical dev machine for horizon 2 and 25 policies.
- Uploaded WAV extraction should complete within 2 seconds for <=5 seconds of
  audio.

## 10. Implementation Phases

### Phase A: minimal scaffolding

[PROPOSED ADDITION] Goal: create names, route, docs, and red tests.

Touched files:

- `shared_contracts/lib/shared_contracts/blanket.ex`
- `world_plane/lib/world_plane/worlds/birdsong_call_response.ex`
- `agent_plane/lib/agent_plane/birdsong_obs_adapter.ex`
- `agent_plane/lib/agent_plane/bundle_builder/birdsong.ex`
- `workbench_web/lib/workbench_web/live/birdsong_call_response_live/index.ex`
- `workbench_web/lib/workbench_web/router.ex`

Risk: compile failures from missing docs or bad module names.

Rollback: remove new files and route only.

### Phase B: observation pipeline

[PROPOSED ADDITION] Implement WAV parser, feature extraction, token sequence
building, and invalid-input errors in `world_plane`.

Tests first: audio feature tests and silence/OOD tests.

Rollback: keep built-in symbolic input and disable upload path.

### Phase C: formal inference core

[PROPOSED ADDITION] Implement `BirdsongObsAdapter` and
`BundleBuilder.Birdsong`. Use `ActiveInferenceCore.Math` and
`DiscreteTime` without adding new math core APIs unless needed.

Tests first: adapter and bundle normalisation tests.

Rollback: remove builder, no runtime route enabled.

### Phase D: policy evaluation

[PROPOSED ADDITION] Add pure `cmd/2` tests proving motif observations change
state beliefs and select response policies through existing `Plan`.

Tests first: policy ranking and exact toy tests.

Rollback: lower ambition to symbolic fixture until policy scores are correct.

### Phase E: synthesis/rendering

[PROPOSED ADDITION] Implement deterministic chirp renderer and response WAV
export.

Tests first: WAV shape/range/duration tests.

Rollback: expose symbolic response sequence only, but keep acceptance blocked
until audio render exists.

### Phase F: workbench integration

[PROPOSED ADDITION] Add a separate LiveView and episode module for the new lab,
parallel to `MeadowEpisode`, not inside `MeadowLive`.

Tests first: LiveView user-flow test.

Rollback: keep route hidden until tests pass.

### Phase G: docs/demo polish

[PROPOSED ADDITION] Add user guide, developer guide, limitations note, and
scientific fidelity note.

Tests first: docs/API catalog and route smoke tests.

Rollback: keep ADR and test plan while hiding unfinished guide route.

## 11. Documentation Plan

[PROPOSED ADDITION] Create:

- `active_inference/docs/decisions/birdsong-call-response-lab.md` - this ADR.
- `active_inference/docs/birdsong-call-response-math.md` - final math spec once
  implementation starts.
- `active_inference/docs/birdsong-call-response-test-plan.md` - executable TDD
  sequence and fixture catalog.
- `active_inference/apps/workbench_web/lib/workbench_web/live/birdsong_call_response_live/ReadmeAI.MD`
  - UI surface and route.
- `active_inference/apps/world_plane/lib/world_plane/worlds/birdsong_call_response/ReadmeAI.MD`
  - world/audio bridge.
- `active_inference/apps/agent_plane/lib/agent_plane/birdsong/ReadmeAI.MD`
  - generative-model bundle and adapter.
- A user guide section linked from `/guide/labs`.
- A limitations/scientific-fidelity note in the lab UI.

## 12. Risks / Open Questions / Assumptions Register

[RISK] If arbitrary real bird recordings are expected to work semantically, MVP
will fail scientifically. The repo has no data or learned acoustic model.

[RISK] A dense 360x360 A matrix is manageable, but expanding factors or horizon
can cause BEAM-side latency. Keep action count and horizon small.

[RISK] Using `response_fit` as an observation factor is coherent as an
interoceptive/evaluative outcome, but it must be documented so reviewers do not
mistake it for scalar reward.

[RISK] The existing `AgentPlane.Skills.ExpectedFreeEnergy` diagnostic skill uses
a different decomposition/sign presentation than the production
`DiscreteTime.expected_free_energy/4`. The new lab should use the production
path and cite the repo formula.

[OPEN QUESTION] Should the first implementation support browser upload, or
start with built-in demo chirps plus a server-side fixture path?

[OPEN QUESTION] Should response mode `z` default to complement only, or should
the UI expose echo/complement/withhold priors?

[OPEN QUESTION] Should generated response WAV live only in LiveView assigns, or
be written to `priv/static/generated/` with cleanup? Prefer in-memory response
for MVP unless browser playback requires a URL.

[ASSUMPTION] New Jido schemas should follow current repo style first; if a new
agent/plugin/signal schema is introduced, prefer Zoi per project rules.

## 13. Proposed File Changes

[CREATED FILE] `active_inference/docs/decisions/birdsong-call-response-lab.md`

[PROPOSED ADDITION] First code/test files to add:

- `apps/shared_contracts/test/birdsong_blanket_test.exs`
- `apps/world_plane/lib/world_plane/worlds/birdsong_call_response.ex`
- `apps/world_plane/lib/world_plane/worlds/birdsong_call_response/audio_features.ex`
- `apps/world_plane/lib/world_plane/worlds/birdsong_call_response/synth.ex`
- `apps/world_plane/test/worlds/birdsong_call_response_test.exs`
- `apps/agent_plane/lib/agent_plane/birdsong_obs_adapter.ex`
- `apps/agent_plane/lib/agent_plane/bundle_builder/birdsong.ex`
- `apps/agent_plane/test/bundle_builder/birdsong_test.exs`
- `apps/workbench_web/lib/workbench_web/episode/birdsong_episode.ex`
- `apps/workbench_web/lib/workbench_web/live/birdsong_call_response_live/index.ex`
- `apps/workbench_web/test/live/birdsong_call_response_live_test.exs`

[DECISION REQUIRING HUMAN APPROVAL] Do not add executable failing tests to the
main suite until the implementation branch is ready to go red, because CI
currently treats all `*_test.exs` files as active tests.

## 14. Next Recommended Action

[PROPOSED ADDITION] Start implementation with Phase A red tests in this order:
shared blanket, audio synth, audio extractor, world step, adapter, bundle. Do
not open the LiveView route until the pure world and pure agent tests pass.
