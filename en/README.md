# SPEC Compiling Pipeline (SCP) v1.0 — A Framework for Operating AI as a Compiler, with Quality-Bias Prevention as Its Primary Goal

> **A development process that adopts a probabilistic transformer (AI) as a software compiler from
> SPEC and UC should take quality-bias *prevention*, not quality *maximization*, as its primary
> goal.**
>
> This framework integrates **ICONIX (two-tier) + SDD + TDD + Traceability (legixy) + spec-level TDD
> + a front-pass loop + a modification-event flow + a 9-perspective AI reviewer layer + independent
> AT** as multiple independent verification paths under the single unifying principle of quality-bias
> prevention.

> **About this edition**: English is a translation; the **Japanese edition
> ([`../ja/`](../ja/)) is the source of truth**. Translation is in progress — see the status table
> below. Links to untranslated chapters point to `../ja/`.

The documents here are written generically, not tied to any particular project. A concrete worked
example (the author's product, anonymized as `APP`) is collected under
[`../ja/appendix/`](../ja/appendix/).

## Translation status

| Doc | EN | JA (source) |
|---|:--:|:--:|
| README (this file) | ✅ | [`../ja/README.md`](../ja/README.md) |
| 00 — Philosophy | ✅ [`00-philosophy.md`](00-philosophy.md) | [`../ja/00-philosophy.md`](../ja/00-philosophy.md) |
| 01 — Overview | ✅ [`01-overview.md`](01-overview.md) | [`../ja/01-overview.md`](../ja/01-overview.md) |
| 02 — Typecodes | ⏳ | [`../ja/02-typecodes.md`](../ja/02-typecodes.md) |
| 03 — Spec-level TDD | ⏳ | [`../ja/03-spec-level-tdd.md`](../ja/03-spec-level-tdd.md) |
| 03a — Front-pass loop | ⏳ | [`../ja/03a-frontend-pass.md`](../ja/03a-frontend-pass.md) |
| 04 — ICONIX two-tier | ⏳ | [`../ja/04-iconix-layer.md`](../ja/04-iconix-layer.md) |
| 05 — Test & implementation | ⏳ | [`../ja/05-test-and-impl.md`](../ja/05-test-and-impl.md) |
| 06 — Trace engine (legixy) | ⏳ | [`../ja/06-trace-engine.md`](../ja/06-trace-engine.md) |
| 07 — AT & NFR | ⏳ | [`../ja/07-at-and-nfr.md`](../ja/07-at-and-nfr.md) |
| 08 — Gates | ⏳ | [`../ja/08-gates.md`](../ja/08-gates.md) |
| 09 — Compiler lens | ⏳ | [`../ja/09-compiler-lens.md`](../ja/09-compiler-lens.md) |
| 10 — Modification events | ⏳ | [`../ja/10-modification-events.md`](../ja/10-modification-events.md) |
| 11 — Responsibility-preservation check | ⏳ | [`../ja/11-responsibility-preservation-check.md`](../ja/11-responsibility-preservation-check.md) |
| 12 — Delivery layer | ⏳ | [`../ja/12-delivery-layer.md`](../ja/12-delivery-layer.md) |
| templates / guides / review-guidelines / perspectives / appendix / bootstrap | ⏳ | [`../ja/`](../ja/) |

✅ translated · ⏳ pending (read the Japanese edition for now)

## What it solves

**When you use a probabilistic transformer as a compiler, quality assurance becomes a problem of
"bias prevention," not "maximization."**

A traditional compiler (GCC, Clang) is a deterministic transformer (the same input always yields the
same output), so quality assurance can be formulated as a maximization problem. An AI (LLM) is a
probabilistic transformer: even for the same input it returns a sample from a distribution `P(y|x)`,
so the nature of quality assurance differs:

- What gets used in the implementation is a single sample from the distribution.
- You must prevent that sample from coming from the left tail (the bad region).
- Due to the LLM's training-distribution bias, multiple samples accumulate bias in a particular
  direction.

This process counters this structural problem not by tuning the AI from the inside (prompting,
fine-tuning, RAG) but by **structural design outside the AI** (multiple independent verification
paths, observation from outside the distribution, after-the-fact accumulation of bias patterns).

See [`00-philosophy.md`](00-philosophy.md) for details.

## Structure

The English edition (`en/`) mirrors the Japanese edition (`ja/`). The directory layout (shown with
its `docs/SCP/` mount point inside a consuming project):

```
docs/SCP/
├── README.md                   # this file (entry point)
├── TESTBED-USAGE.md            # operating guide as a testbed / observation-log procedure
├── 00-philosophy.md            # the design principle: quality-bias prevention first
├── 01-overview.md              # the whole picture, the layered structure, observability
├── 02-typecodes.md             # artifact typecodes and ID rules
├── 03a-frontend-pass.md        # front-pass loop (Raw SPEC → Accepted SPEC normalization)
├── 03-spec-level-tdd.md        # SPEC/UC ⇄ TP ⇄ GAP loop = making output bias detectable
├── 04-iconix-layer.md          # ICONIX two-tier: RBA → SEQA → RBD → SEQD → DD
├── 05-test-and-impl.md         # TS → TC[RED] → SRC → TC[GREEN]
├── 06-trace-engine.md          # operating legixy v3
├── 07-at-and-nfr.md            # AT (acceptance tests) and NFR = observation from outside the distribution
├── 08-gates.md                 # phase-progression gates (machine verification + AI reviewer + human)
├── 09-compiler-lens.md         # compiler-structure lens (maps to traditional/incremental compilers)
├── 10-modification-events.md   # modification-event flow (spec-change / defect-fix / spec-add / new)
├── 11-responsibility-preservation-check.md  # abstract→concrete responsibility-preservation check (RPC)
├── 12-delivery-layer.md        # delivery layer (CLI/API/MCP contract surface): CTR/DLV/multi-area/conformance gate
├── templates/                  # Markdown templates per artifact
├── review-guidelines/          # operating discipline for the AI reviewer layer
├── bootstrap/                  # new-project initialization kit
├── perspectives/               # generic templates for the perspectives knowledge base
├── guides/                     # adoption phases, AI collaboration, language stacks
├── appendix/                   # worked example (anonymized product "APP")
└── manual/legixy/              # legixy manual (copy; shared at repo root)
```

## Quick adoption steps

To adopt this process in a new project (details in
[`../ja/guides/adoption-phases.md`](../ja/guides/adoption-phases.md)):

1. **Install the tool**: place `legixy` v3 (`v0.4.0-alpha4` or later) in `~/.local/bin/`, etc.
   `legixy` is the renamed/rebuilt successor of the tool implemented as `traceability-engine` during
   SCP's development; the currently distributed binary may still be named `traceability-engine` (same
   tool — see [`../ja/06-trace-engine.md`](../ja/06-trace-engine.md)).
2. **Initialize directories**: run `bootstrap/init-tree.sh`, or create the `docs/{...}/` tree
   manually.
3. **Place config files**: `.trace-engine.toml`, `docs/traceability/graph.toml`,
   `scripts/trace-check.sh`, and root `CLAUDE.md` from the `bootstrap/` templates.
4. **Place perspective bases**: copy `perspectives/*.md` into `docs/perspectives/` and append
   domain-specific perspectives.
5. **Phased adoption**: start at Phase 1 (front-pass loop + SPEC-layer TP/GAP) → Phase 2 (add the UC
   layer) → Phase 3 (separate AT as independent). See
   [`../ja/guides/adoption-phases.md`](../ja/guides/adoption-phases.md).

## Hard Rules (always applied; both AI and humans obey)

1. **Changing the SPEC requires human approval.** The AI proposes; the human decides.
2. **Do not proceed to the next phase while a GAP is open.** While GAP[SPEC] is open, UC work is
   forbidden; while GAP[UC] is open, RBA work is forbidden. `bash scripts/trace-check.sh` verifies
   this mechanically.
3. **Every artifact carries a reference to its parent.** On-chain artifacts are verified by legixy
   v3's `check --formal`; off-chain artifacts by in-body metadata + `scripts/trace-check.sh`.
4. **A new artifact type requires updating `.trace-engine.toml` first.** Do not invent types not in
   the chain.
5. **AT is not a terminus but an independent verification channel.** It is dedicated to the domain
   that spec-level TDD cannot, in principle, detect (tacit knowledge, domain conventions, mismatched
   assumptions). It is positioned as observation from outside the distribution
   ([`00-philosophy.md`](00-philosophy.md) §2.4).
6. **Do not change the spec and test code after implementation begins.** The implementation conforms
   to the tests. Upstream-document fixes routed through a defect-fix event (`/defect-fix`) or
   spec-change event (`/spec-change`) are exempt
   ([`../ja/10-modification-events.md`](../ja/10-modification-events.md) §4.1.2).
7. **Boundary-API contracts are frozen at the DD stage.** Post-freeze changes are treated as a SPEC
   revision for the next version.
8. **Do not merge an implementation whose tests do not pass.**
9. **A SPEC must not start TP[SPEC] / UC until it reaches `FCR.frontend_status = ACCEPTED` in the
   front-pass loop.** Flowing a Raw SPEC straight into TP/UC is the old process's breakdown pattern
   and causes the downstream to fill in the SPEC's incompleteness. `bash scripts/trace-check.sh`
   verifies this. Record any skip in an ADR (details in
   [`../ja/03a-frontend-pass.md`](../ja/03a-frontend-pass.md) §11). Narrowing the input distribution
   ([`00-philosophy.md`](00-philosophy.md) §2.1).
10. **No ICONIX two-tier layer contamination + mandatory three-party consistency check.** The
    abstract side (RBA/SEQA) carries only domain vocabulary; the concrete side (RBD/SEQD) goes up to
    operation names (human language) and class-diagram notation. Function names
    (snake_case/camelCase calls), concrete argument/return types, modifiers (`pub`, `async`),
    crate/module identifiers (`tokio::`, `std::`), and language-specific generic types
    (`Result<T,E>`, `Vec<T>`, `Arc<Mutex<T>>`) are written only in DD. The `[5/5]` layer-
    contamination check in `bash scripts/trace-check.sh` detects violations via grep. In addition,
    confirming abstract-tier GREEN requires both the **Jacobson-style three-party consistency
    (UC ⇄ RBA ⇄ SEQA)** and the **ICONIX-style three-party consistency (UC ⇄ RBA ⇄ SPEC)**. See
    [`../ja/04-iconix-layer.md`](../ja/04-iconix-layer.md). Preserving the structure of the multiple
    independent verification paths ([`00-philosophy.md`](00-philosophy.md) §2.3).
11. **Limit human involvement to SPEC and UC.** From RBA onward (SEQA, RBD, SEQD, DD, TS, TC, SRC),
    quality is assured by autonomous AI execution + the AI reviewer layer + AT. Concentrating humans'
    limited cognitive resources on the most important lines of defense (improving input quality, and
    the observation criterion from outside the distribution) maximizes the efficiency of the whole
    defense. As an exception, the boundary-API freeze decision (Hard Rule 7) remains human-mandatory,
    operated as the AI presenting the list of APIs to freeze for the human to approve in bulk. For the
    structural rationale see [`00-philosophy.md`](00-philosophy.md) §3; for the operational
    definition see [`../ja/guides/ai-collaboration.md`](../ja/guides/ai-collaboration.md) §1.

Hard Rules 1–10 are the foundation of this framework, positioned under the quality-bias-prevention
framework ([`00-philosophy.md`](00-philosophy.md) §1). Hard Rule 11 adds the discipline of
concentrating human involvement on SPEC and UC.

## The Lens Document

The normal 00–08 + 03a documents **prescribe** the process, whereas
[`../ja/09-compiler-lens.md`](../ja/09-compiler-lens.md) is a lens spec (`LENS-SCP-COMPILER-002`) that
**describes** the process in a different vocabulary. It does not change the implementation procedure;
it provides a viewpoint for switching the reference frame of design decisions. The lens document aims
to "introduce," not to force understanding, and can be read independently of the prescriptive docs
(00–08, 03a).

## The Modification-Event Flow

The event-driven modification flow classifies changes to an existing chain into four events:

| Event | Slash command | Description |
|---|---|---|
| **New creation** | (normal chain) | Project start / an independent new chain |
| **Spec addition** | `/spec-add` | Add a new SPEC to an existing system |
| **Spec change** | `/spec-change` | Intentional change to an existing SPEC / UC |
| **Defect fix** | `/defect-fix` | From defect detection through root-cause analysis, fix, and rebuild |

Key features: a common core operation (`trace --upstream` → `impact` → reference artifacts →
generate fix candidates); incremental rebuild (selectively regenerate downstream from the modified
document); a 3-cycle overrun warning; and an event log appended to `.scp/event-log.txt`.
**Unverified**: the event flow is a spec built through a thought experiment and not yet validated in
operation; Phases E1–E5 progressively enable and confirm it. See
[`../ja/10-modification-events.md`](../ja/10-modification-events.md).

## The AI Reviewer Layer

Each gate, formerly two layers (`machine verification + human judgment`), is extended to three by
inserting an **AI reviewer layer** between them:

```
machine verification (trace-check.sh) → AI reviewer layer (9 perspectives + severity + VERDICT) → human judgment
```

The AI reviewer layer checks the 9 perspectives sequentially in one session, raises findings under a
severity hierarchy and a no-demotion rule, and outputs a machine-readable VERDICT marker at the end.
This moves the human reviewer off per-PR adjudication into a **human-on-the-loop** role of catching
the patterns the AI gets wrong and fixing the guidelines. However, **SPEC changes, release
decisions, and quality-criterion relaxations** cannot be AI-approved and remain human-mandatory (Hard
Rule 1 / meta-level safety valve). See [`../ja/review-guidelines/README.md`](../ja/review-guidelines/README.md)
and [`../ja/08-gates.md`](../ja/08-gates.md).

**Local single-developer premise**: SCP assumes a synchronous local environment of one developer +
Claude Code. Cloud CI runners and GitHub PR workflows are structurally unnecessary; the AI reviewer
is launched via Claude Code's subagent / hook / slash command. See
[`../ja/08-gates.md`](../ja/08-gates.md) §17.

## Terminology

| Abbr. | Name | Meaning |
|---|---|---|
| SPEC | Specification | The project's Why and What |
| QSET | Questionnaire Set | Front-pass loop: the questionnaire the AI issues |
| SPP | SPEC Patch Proposal | Front-pass loop: a SPEC diff reflecting QSET answers |
| FCR | Frontend Check Result | Front-pass loop: the frontend check result (holds `frontend_status`) |
| UC | Use Case | Behavior described from the actor's viewpoint |
| TP | Test Perspective | A list of perspectives for verifying the spec (not test cases) |
| GAP | Gap Analysis | Record of omissions found by throwing TP at the spec |
| RB | Robustness Diagram | Boundary / Control / Entity structural consistency |
| SEQ | Sequence Diagram | Time-series expansion of a UC |
| DD | Detailed Design | Mapping to the implementation language's structures |
| TS | Test Specification | TP translated into executable form |
| TC | Test Code | TS converted into machine-runnable tests |
| SRC | Source Code | The minimal implementation that passes TC |
| AT | Acceptance Test | Verification of tacit knowledge / domain conventions / mismatched assumptions |
| NFR | Non-Functional Requirement | Performance, concurrency, resources, security |
| ADR | Architecture Decision Record | Record of the rationale for design decisions |
| VAL | Validation | Cross-cutting verification of the whole project |
| RPC | Responsibility Preservation Check | Preservation check from abstract (RBA/SEQA) to concrete (RBD/SEQD) responsibilities (v1.0) |
| CTR | Boundary Contract | The frozen boundary contract; root of the delivery axis (v1.0) |
| DLV | Delivery design | Dispatch design from the contract to library SRC (v1.0) |

## The Philosophy This Framework Adopts

> **A software-development process that adopts a probabilistic transformer as structural material
> should take quality-bias prevention, not quality maximization, as its primary goal.**

As sub-principles, the following are positioned within the quality-bias-prevention framework:

- **Moving the trust boundary upstream**: raise the quality of the input `x` to narrow `P(y|x)`.
- **Observability**: make the bias of the output `y` detectable by throwing perspectives at it.
- **Multiple independent verification paths**: each methodology's blind spot is structurally covered
  by another.
- **Observation from outside the distribution**: AT (human observation) is the last line of defense
  for downstream quality.
- **After-the-fact accumulation of bias patterns**: the `ai-antipattern.md` catalog and the
  `[Recurrence]` perspective make bias learnable.
- **Concentrating human involvement**: concentrate it on the most important lines of defense
  (SPEC + UC + AT) (Hard Rule 11).

See [`00-philosophy.md`](00-philosophy.md) for details.

---

## License

Licensed under the **Apache License 2.0** — see [`../LICENSE`](../LICENSE) and [`../NOTICE`](../NOTICE).
