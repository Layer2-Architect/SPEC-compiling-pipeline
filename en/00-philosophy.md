# 00 — The Philosophy of This Process

> English translation. The Japanese edition ([`../ja/00-philosophy.md`](../ja/00-philosophy.md)) is
> the source of truth. Links to chapters not yet translated point to the Japanese edition (`../ja/`).

## 1. The Primary Goal: Quality-Bias Prevention

> **A software-development process that adopts a probabilistic transformer as structural material
> should take quality-bias *prevention*, not quality *maximization*, as its primary goal.**

This is the topmost design principle of this process. Every design decision below is derived from it.

### 1.1 What Is a Probabilistic Transformer?

A traditional compiler (GCC, Clang) is a *deterministic* transformer. For an input `x` it returns an
output `y = f(x)` via a function `f`. The same input always yields the same output.

An AI (an LLM) is a *probabilistic* transformer. For an input `x` it returns a probability
distribution `P(y|x)` and samples one `y` from it. Even for the same input, the output differs each
time you sample. Even at temperature 0 it is not perfectly deterministic, due to numerical jitter in
attention, batching, and tokenizer ambiguity.

This process uses the AI as a compiler responsible for the downstream transformation from SPEC and
UC (the whole pipeline up to SRC generation). That is, it adopts `f: x → P(·|x)`, not `f: x → y`, as
structural material.

### 1.2 The Structural Problem of Demanding "Quality Maximization" from a Probabilistic Transformer

For a deterministic transformer, quality maximization is clearly definable (raise execution speed,
shrink code size, strengthen optimization).

For a probabilistic transformer, quality maximization means one of several quantities over the
distribution:

- maximizing the expected value `E[quality(y)]`
- maximizing the mode `mode[quality(y)]`
- maximizing the lower bound `min[quality(y)]` (i.e., raising the upper bound on the worst case;
  minimax)

Traditional development-process theory implicitly adopts the first two. "Collect best practices and
optimize" is maximization of the expected value or the mode.

But when you use a probabilistic transformer as a compiler, the structurally correct choice is the
third — minimax. There are three reasons.

**Reason 1: a compiler's role is a lower-bound guarantee.**

The implicit demand on a traditional compiler is a lower-bound guarantee: "the generated binary at
least works as specified." "It works well on average" does not function as a compiler. If you use an
AI as a SPEC → SRC compiler, the same lower-bound guarantee is required. You need a structural
guarantee that "no matter the sampling, the worst case does not reach catastrophic failure."

**Reason 2: the left tail of the distribution is effectively never observed.**

What gets used in the implementation is not the whole distribution but a single sample `y` from it.
You do not realistically sample the same SPEC 1000 times to observe the distribution. At a
100-crate scale with 50–200 UCs, that many samplings occur, and probabilistically a left-tail sample
(a sample from the bad region of the distribution) will inevitably slip in.

If you evaluate quality by its "average," you are defenseless when the single sample actually used in
the implementation comes from the left tail. The structurally correct way to defend is either to
raise the left-tail sample itself (tuning the AI, which is fundamentally limited) or to separately
prepare a path on which a left-tail sample does not reach catastrophic failure (the direction this
process adopts).

**Reason 3: distribution bias accumulates in one direction.**

An LLM's distribution `P(y|x)` is not uniform; it is biased by the distribution of the training
data. Even when there are several "plausible solutions" for the same SPEC, the LLM chooses a
particular one (the solution frequent in the training data) with high probability.

If, at a 100-crate scale, you generate one sample per UC, the design accumulates overall toward the
LLM's training-distribution bias. It does not look like a problem in an individual UC, but the whole
system skews in one direction. This is a property unique to probabilistic transformers, absent in
deterministic compilers.

### 1.3 Formulating Quality-Bias Prevention

From the above, what should be demanded when using a probabilistic transformer as a compiler is:

**Demand 1**: a left-tail sample of `P(y|x)` does not reach catastrophic failure.
**Demand 2**: the bias of `P(y|x)` does not accumulate in a particular direction.

This is the precise formulation of "quality-bias prevention."

If "quality maximization" means raising the right tail (the good samples), then "quality-bias
prevention" means preventing left-tail catastrophic failure and preventing bias accumulation across
the whole distribution.

Internal tuning of the AI (prompting, fine-tuning, RAG) is an attempt to change the distribution from
`P(y|x)` to `P'(y|x)`, but it remains fundamentally probabilistic. By contrast, the effort to prevent
left-tail catastrophic failure and the effort to prevent bias accumulation can be implemented in
structure *outside* the AI (redundancy, multiple methodologies, independent verification channels,
human observation), and have no fundamental limit.

**This process implements quality-bias prevention through structural design outside the AI, not
through internal tuning of the AI.**

### 1.4 Connections to Existing Fields

Design principles for probabilistic transformers, or for systems under uncertainty, are well
established in existing fields:

- **Robust statistics**: the median is used over the mean because it prioritizes robustness against
  the left tail (outliers) of the data distribution over the accuracy of central tendency. This is
  the minimax idea.
- **Adversarial robustness (machine learning)**: a model's robustness against out-of-training-
  distribution inputs is treated as a metric separate from average accuracy.
- **Safety engineering**: FMEA / FTA systematically enumerate failure paths and layer up defenses for
  each. Aircraft redundancy, reactor defense-in-depth, and medical-device interlocks all take "the
  upper bound on the worst case, not maximum performance" as the design goal.

This process applies the "design principles for probabilistic or uncertain systems" established in
those fields to a new structural material — the AI compiler. It is positioned not as an independent
discovery but as a transplant of existing robust-design thinking into the software-engineering
domain.

Because software engineering has traditionally assumed deterministic systems, the vocabulary and
methodology of robust design are not established in the software-engineering domain. This process is
one solution that fills that gap.

---

## 2. Structural Measures for Quality-Bias Prevention

The measures for achieving the primary goal (§1) fall into five categories. They function as
independent lines of defense, each providing a counter to a different source of bias.

### 2.1 Narrowing the Input Distribution — the Front-Pass Loop

A probabilistic transformer's output distribution `P(y|x)` depends on the input `x`. If the input is
ambiguous, the distribution widens and left-tail samples become more likely. **By resolving input
incompleteness you narrow the distribution and structurally lower the probability of left-tail
samples.**

This is the essential role of the front-pass loop
([`../ja/03a-frontend-pass.md`](../ja/03a-frontend-pass.md)). Normalizing a Raw SPEC through the
iteration QSET ⇄ SPP ⇄ FCR corresponds to raising the quality of the input `x` and narrowing the
variance of `P(y|x)`.

Hard Rule 9 (a SPEC must not start TP[SPEC] / UC until it reaches `FCR.frontend_status = ACCEPTED` in
the front-pass loop) is a structural constraint forbidding the start of downstream sampling before
the input distribution is sufficiently narrow.

### 2.2 Making Output Bias Detectable — Observability and TP/GAP

The bias of a probabilistic transformer's output `y` is undetectable from a single sample. Looking at
one sample, you can judge "this is a reasonable solution," but bias is a property of the whole
distribution and cannot be read off an individual sample.

**By generating perspectives and throwing them against the spec, you convert bias into an "observable
omission."** This is the essential role of the TP/GAP loop
([`../ja/03-spec-level-tdd.md`](../ja/03-spec-level-tdd.md)).

A "perspective" is not a "test case" but **a list of questions to ask of the spec document**. By
keeping a perspectives knowledge base ([`../ja/perspectives/`](../ja/perspectives/)) outside the AI,
you forcibly inject perspectives the AI would not think of on its own. This is a path that demands
coverage from outside, against the bias of the AI's distribution.

Hard Rule 2 (do not proceed to the next phase while a GAP is open) forbids proceeding downstream
while leaving a detected bias unaddressed.

### 2.3 Multiple Independent Verification Paths — Juxtaposing Methodologies

Every methodology has its own blind spot (an inability to catch failures in quality dimensions it
does not anticipate). **By deliberately juxtaposing multiple methodologies so that each one's blind
spot is structurally covered by another, you prevent bias accumulation in a particular direction.**

The methodologies this process juxtaposes:

| Methodology | Quality dimension covered | Source |
|---|---|---|
| TDD (code level) | Implementation verifiability | Beck/Cunningham |
| Spec-level TDD (TP/GAP) | Spec completeness | This process |
| ICONIX two-tier (RBA/SEQA/RBD/SEQD/DD) | Structural consistency | Jacobson OOSE 1992 + Rosenberg & Stephens 2007 |
| Three-party consistency check (both schools) | Dynamic + static consistency | Jacobson-style + ICONIX-style |
| Traceability (legixy) | Spec⇄implementation traceability | Compiler theory (symbol table / DWARF) |
| Property-based testing | Coverage of invariants | proptest / hypothesis family |
| Model checking | Concurrency, protocols | loom / Spin |
| AT (human observation) | Tacit knowledge, domain conventions | Acceptance-testing family |
| NFR | Performance, concurrency, resources | Non-functional-requirements family |
| ADR | Rationale for design decisions | Michael Nygard |
| AI-antipattern catalog | AI-specific blind spots | This process |
| 9-perspective AI reviewer layer | Between machine verification and human judgment | This process |
| Delivery-axis contract conformance (CTR/DLV/TC[DLV]) | External exposure of a function = conformance to a frozen boundary contract | This process (v1.0, [`../ja/12-delivery-layer.md`](../ja/12-delivery-layer.md)) |

These are not a "grab bag of best practices" but an arrangement in which each methodology's blind
spot is structurally covered by another:

- TDD's blind spot (design skews) → ICONIX structural translation fixes the structure upstream
- ICONIX's blind spot (performance/concurrency deferred) → NFR and loom verify independently
- Formal verification's blind spot (validity of the spec itself) → AT detects it through human observation
- AT's blind spot (low frequency) → TP/GAP lift it to the spec stage on a perspective basis
- AI reviewer's blind spot (homogeneous model) → the machine-verification layer and AT exist as independent paths
- ADR's blind spot (record only) → the AI reviewer's `[Doc]` verifies documentation follow-through
- **The blind spot of functional-chain GREEN (non-conformance/orphaning of the contract surface =
  CLI/API/MCP does not surface under functional GREEN) → the delivery axis's TC[DLV] real-binary E2E
  plus the structural WARN-escalate gate force independent verification (v1.0,
  [`../ja/12-delivery-layer.md`](../ja/12-delivery-layer.md))**

Hard Rule 10 (no ICONIX two-tier layer contamination + mandatory three-party consistency check) is a
constraint that preserves the structure of the multiple independent verification paths.

### 2.4 Observation from Outside the Distribution — AT

The AI reviewer sits *inside* the AI's probability distribution (it operates on the same or a highly
correlated distribution). There is a structural limit whereby one AI overlooks a pattern that another
AI also overlooks. This can be partially mitigated by prompt tricks or by introducing a different
model, but it is not fundamentally resolved.

**As observation from outside the AI's probability distribution, AT (human observation) is
structurally necessary.** The AT defined in [`../ja/07-at-and-nfr.md`](../ja/07-at-and-nfr.md)
detects divergence from reality that the AI cannot capture at the descriptive level, through
operating the real system.

In this process, AT is positioned as the "last line of defense for downstream quality." However
refined the AI reviewer layer becomes, AT cannot be omitted.

Problems found in AT are recorded as GAP[UC] / GAP[SPEC] and promoted to new perspectives in
`perspectives.md` (§2.5).

### 2.5 After-the-Fact Accumulation of Bias Patterns — ai-antipattern.md and Recurrence

The bias of a probabilistic transformer is not fully predictable. "What kind of bias will occur" is
not known until you operate it.

**As a path that records biases after they occur and raises the chance of detecting them next time,
the `ai-antipattern.md` catalog and the `[Recurrence]` perspective function.**

`ai-antipattern.md` is a structural taxonomy of AI-specific traps, appended to when a new pattern is
discovered (human-on-the-loop). The `[Recurrence]` perspective requires every bug-fix PR to state
explicitly "how to prevent it next time" (add a trace-check / promote to perspectives / add a
guideline / ADR exception / do nothing).

This does not change the AI's distribution directly; it grows an after-the-fact filter on the AI's
output. It treats bias as a structure that is "**impossible to improve away, but observable and
learnable**."

---

## 3. The Structural Rationale for the Human-Involvement Boundary — SPEC and UC Only

In this process, human involvement is limited to SPEC and UC. From RBA onward (SEQA, RBD, SEQD, DD,
TS, TC, SRC), quality is assured by the combination of autonomous AI execution + the AI reviewer
layer + AT.

This is normalized as Hard Rule 11 (see the hard-rule list in [`README.md`](README.md)).

### 3.1 The Structural Rationale for the Involvement Boundary

The quality-bias-prevention logic of §1 applies to the positioning of human involvement too.

**Concentrating human involvement on the most important line of defense** is a structurally more
correct design than "reducing intervention." There are three reasons.

**Rationale 1: input-distribution quality is the premise of every line of defense.**

As shown in §2.1, a probabilistic transformer's output distribution depends on the input. If the
input (SPEC, UC) is high quality, the efficiency of every downstream line of defense rises.
Conversely, if the input is ambiguous, no amount of layered defense downstream structurally lowers
the probability of catastrophic failure.

Concentrating humans' limited cognitive resources on improving input quality maximizes the efficiency
of the whole defense.

**Rationale 2: SPEC + UC function as observation from outside the distribution.**

§2.4 positioned AT as "observation from outside the distribution," but SPEC and UC have the same
positioning. SPEC and UC are not artifacts the AI generates probabilistically; they are artifacts a
human fixes with domain knowledge and judgment.

They are simultaneously the input to the probabilistic transformer and the *criterion* against its
output. Even if the AI generates a biased design downstream, the bias is detected by checking whether
it is consistent with the SPEC and UC. If SPEC and UC were inside the AI's distribution, this
checking path would cease to function.

**Rationale 3: most root causes of catastrophic failure are upstream.**

As the defect-fix flow in [`../ja/10-modification-events.md`](../ja/10-modification-events.md) shows,
the true cause of a defect is, in many cases, an upstream documentation deficiency. An SRC-level patch
is symptomatic treatment; unless you fix the upstream, the same class of problem recurs.

If you scatter human involvement downstream (from RBA onward), the dynamic of "filling in" upstream
deficiencies downstream tends to take hold (see `ai-antipattern.md` A-1, A-2). By concentrating human
involvement on SPEC + UC, the discipline of always returning upstream the moment a deficiency is
found is structurally preserved.

### 3.2 The Operational Definition of the Involvement Boundary

Work humans are directly involved in:

- Drafting, revising, and final approval of SPEC
- Answering QSET
- Approving / rejecting SPP
- Reviewing UC flow validity and final approval
- Confirming perspective gaps in TP[SPEC] / TP[UC]
- Judging GAP severity and close decisions
- Conducting AT (observing subjects)
- Setting NFR thresholds
- Approving ADRs
- Release decisions
- Firing and approving modification events (`/defect-fix`, `/spec-change`, `/spec-add`)
- Final approval of quality-criterion changes (`review-guidelines/`, `.trace-engine.toml`, the
  hard-rule text)

Work humans are *not* directly involved in:

- Generating RBA, SEQA, RBD, SEQD, DD
- Generating TS, TC, SRC
- Quality review of the above downstream artifacts (delegated to the AI reviewer layer)
- Layer-contamination checks (delegated to machine verification)
- Conducting the three-party consistency check (delegated to the AI Adversary; only the verdict is
  cross-checked at the AT stage)

Exception: the freeze decision of Hard Rule 7 (boundary APIs are frozen in DD) remains human-
mandatory, but it is operated as the AI presenting "the list of APIs to freeze" and the human
approving them in bulk (not reading the full DD per API).

### 3.3 Preconditions for the Involvement Boundary to Hold

Preconditions under which limiting human involvement to SPEC + UC holds:

- SPEC and UC have enough information density for downstream autonomous AI execution (assured by the
  TP[UC] perspective in [`../ja/03-spec-level-tdd.md`](../ja/03-spec-level-tdd.md))
- The AI reviewer layer is functioning (the VERDICT mechanism in
  [`../ja/08-gates.md`](../ja/08-gates.md); the 9 perspectives in
  [`../ja/review-guidelines/`](../ja/review-guidelines/))
- AT is conducted as an independent verification channel
  ([`../ja/07-at-and-nfr.md`](../ja/07-at-and-nfr.md))
- The `ai-antipattern.md` catalog is grown in operation (human-on-the-loop)
- Traceability via legixy is functioning ([`../ja/06-trace-engine.md`](../ja/06-trace-engine.md))

If you narrow the involvement boundary to SPEC + UC while these preconditions are broken, downstream
quality becomes defenseless. For the procedure to empirically confirm the preconditions hold in Phase
E0 (the verification phase), see
[`../ja/guides/adoption-phases.md`](../ja/guides/adoption-phases.md).

---

## 4. Repositioning Existing Philosophical Concepts

The philosophical descriptions up to SCP (moving the trust boundary upstream, observability, the
formality gate, the no-filling-in rule, adopting ICONIX, adopting traceability) remain valid as the
core of this process. They are repositioned, each as an independent line of defense, under the
higher principle of quality-bias prevention from §1.

| Existing concept | Positioning within the quality-bias-prevention framework |
|---|---|
| Moving the trust boundary upstream | Narrowing the distribution `P(y|x)` by improving the quality of the input `x` (§2.1) |
| Observability | Making the bias of the output `y` detectable by throwing perspectives at it (§2.2) |
| Formality gate | Structural constraint forbidding the start of sampling before the input distribution narrows (§2.1, Hard Rule 9) |
| No filling-in | Forbidding the compensation of input-distribution deficiencies by downstream sampling (§2.1 + §3.1 Rationale 3) |
| Adopting ICONIX | The structural-consistency channel among the multiple independent verification paths (§2.3) |
| ICONIX two-tier | Bias detection by juxtaposing the abstract and concrete sides as separate channels (§2.3) |
| Adopting traceability | Securing the traceability of the bias-detection paths (the central apparatus of the verification paths in §2.3; [`../ja/09-compiler-lens.md`](../ja/09-compiler-lens.md) §7) |
| AT independence | Observation from outside the distribution (§2.4) |
| AI-antipattern catalog | After-the-fact accumulation of bias patterns (§2.5) |

These can be discussed independently, but organizing them under the unifying principle of quality-
bias prevention lets the "why is each necessary" of each concept be explained by one consistent logic.

---

## 5. Why "Quality Maximization" Is the Wrong Goal

Development processes that target "quality maximization" grew up in the context of deterministic
systems (code, compilers, and OSes). In a deterministic system, "raise quality" and "prevent quality
skew" are effectively the same problem. Raise the maximum and the minimum rises too.

In a probabilistic system, this identity breaks. Raising the maximum can lower the minimum (when the
distribution widens). There is a way to raise only the minimum without raising the maximum (when the
distribution narrows).

The best-practice theory of software engineering was built, implicitly, without handling the concept
of a "distribution." The embedding of a probabilistic transformer into the development process is
something happening for the first time in the generative-AI era, and the quality theory required
there must be reassembled from the traditional framework of software engineering.

Evaluating this process with the "collect best practices and optimize" mindset makes the 19
typecodes, 5-layer ICONIX, multiple independent verification channels, and front-pass loop look
"heavy," "redundant," and "ritualistic."

But within the quality-bias-prevention framework, these are positioned as the necessary number of
layers of defense-in-depth. It is the same structure as aircraft redundancy, reactor defense-in-
depth, and financial-system defense-in-depth. Precisely because each layer is "inefficient on its
own," "together they are strong against catastrophic failure."

For a product operated at a 100-crate scale for 5+ years, the trade-off between efficiency and
redundancy should tip toward redundancy. For a short-term prototype it is the reverse, but this
process is clearly for long-term operation (see §7).

A structural response to the "heavy" criticism: those are the number of layers necessary as defense-
in-depth. To reduce them, you must consciously choose which bias's defense you sacrifice. Reduce them
unconsciously, and the bias the removed layer covered becomes defenseless.

---

## 6. What Can and Cannot Be Detected

| Domain | Detection means | §2 line of defense covered |
|---|---|---|
| Spec completeness (boundary values, errors, permissions, state transitions, abnormal paths) | TP / GAP | §2.2 |
| Spec↔implementation consistency | TDD + legixy | §2.3 |
| Performance, concurrency, resource management | NFR + benchmarks + loom | §2.3 |
| Tacit knowledge, domain conventions, mismatched assumptions | AT | §2.4 |
| AI-specific blind-spot patterns | ai-antipattern.md catalog | §2.5 |
| Left-tail samples of the probabilistic transformer | All of the above defense-in-depth | §2.1–2.5 |

"The domain detected by AT" is, in principle, undetectable by spec-level TDD. Through the
`perspectives.md` promotion mechanism, a perspective found in AT becomes detectable in the next round
of TP generation. This progressively expands the range detectable by spec-level TDD (§2.5).

---

## 7. Where This Process Fits and Does Not Fit

### Fits

- There is a public API (FFI boundary, library, SDK, service API)
- Spec correctness directly drives quality (payments, medicine, simulation, content-generation
  pipelines)
- Multiple implementations (languages, runtimes) share a boundary API
- A project that makes heavy use of AI generation
- Long-term operation (5+ years assumed)
- Large scale (50+ UCs, multi-crate scale)
- The cost of catastrophic failure is high (regulated, safety-critical, high-availability)

### Does Not Fit

- An exploratory-phase prototype (the spec itself is the object of exploration)
- A short-term throw-away script
- A one-off bug fix to an existing system
- Small scale (a few UCs, single-file scale)
- The cost of catastrophic failure is low (personal tools, internal hacks)

Judge the boundary between the exploratory phase and this process by "**have you entered the stage
where the boundary API should be frozen?**" Once you enter the freeze phase, use this process;
before it, ordinary TDD is fine.

Long-term operation + large scale + high catastrophic-failure cost — these three conditions overlap
to determine the applicability of this process. If even one is missing, the cost of defense-in-depth
likely exceeds the benefit.

---

## 8. The Premise of Phased Adoption

Even for a new project, you do not need to stand up all layers at once. For the phase structure, see
[`../ja/guides/adoption-phases.md`](../ja/guides/adoption-phases.md).

The effectiveness metric for each phase is **"the number of spec-induced bugs discovered at TS and
later,"** but this does not measure a reduction in the average bug count; it measures **how often,
when the probabilistic transformer emits a left-tail sample, that sample flows back upstream and is
detected at the spec level**. More than the bugs decreasing per se, the evidence that defense-in-
depth is functioning is that the root cause of a bug can be traced back to the spec layer.

---

What to read next: [`01-overview.md`](01-overview.md) (the process overview and layer structure).

An alternate lens: [`../ja/09-compiler-lens.md`](../ja/09-compiler-lens.md) restates this document's
philosophy (quality-bias prevention, moving the trust boundary upstream, observability, defense-in-
depth, single source of truth) in the vocabulary of compiler structure.
