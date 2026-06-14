# 01 — Process Overview

> English translation. The Japanese edition ([`../ja/01-overview.md`](../ja/01-overview.md)) is the
> source of truth. Links to chapters not yet translated point to the Japanese edition (`../ja/`).

## 1. Chain Order (conceptual)

```
Raw SPEC → [front-pass loop] → Accepted SPEC → TP[SPEC] → GAP[SPEC]
        → UC → TP[UC] → GAP[UC]
        → RBA → SEQA → RBD → SEQD → DD
        → TS → TC[RED] → SRC → TC[GREEN]
```

Here the **front-pass loop** is:

```
Raw SPEC ⇄ QSET ⇄ SPP ⇄ FCR
(questionnaire ⇄ SPEC-diff proposal ⇄ check result)
```

**ICONIX two-tier**: RB/SEQ are split into an abstract tier (RBA/SEQA, domain level) and a concrete
tier (RBD/SEQD, class-diagram level). Both are language-independent; language-specific elements
first appear in DD. See [`../ja/04-iconix-layer.md`](../ja/04-iconix-layer.md).

Independent artifacts (off-chain): `QSET`, `SPP`, `FCR` (front-pass loop); `TP`, `GAP` (spec-level
TDD loop); `AT` (acceptance tests), `NFR` (non-functional requirements), `ADR` (architecture
decision records), `VAL` (cross-cutting validation).

**Implementation note**: legixy v3's `[id.chain] order` holds
`UC → RBA → SEQA → RBD → SEQD → DD → TS → TC → SRC`, while
`SPEC / QSET / SPP / FCR / TP / GAP / AT / NFR / ADR / VAL` are treated as `independent`. The
front-pass loop (Raw SPEC ⇄ QSET ⇄ SPP ⇄ FCR) and the spec-level TDD loop (SPEC ⇄ TP ⇄ GAP) are
verified by in-body metadata plus the grep-based gate in `scripts/trace-check.sh`.

**Two-axis structure (added in v1.0)**: the above is the **functional axis** (what the system does =
UC → library). Orthogonal to it is the **delivery axis** (how a function is exposed across a frozen
boundary contract = CLI/API/MCP), held as a second chain in a separate area:
`CTR (boundary contract, root) → DLV → TS → TC → SRC(binary)`. The delivery axis's SRC anchors the
binary/surface source, admitting the contract surface into the chain (preventing orphaning). See
[`../ja/12-delivery-layer.md`](../ja/12-delivery-layer.md).

## 2. The Five Nested Loops

```
[front-pass loop (frontend pass)]   Raw SPEC ⇄ QSET ⇄ SPP ⇄ FCR
        ↓ (FCR = ACCEPTED)
[spec-level TDD loop]   SPEC ⇄ TP ⇄ GAP, UC ⇄ TP ⇄ GAP
        ↓
[ICONIX abstract tier]  RBA → SEQA            (domain level, language-independent)
        ↓
[ICONIX concrete tier]  RBD → SEQD → DD       (class-diagram level → language-specific)
        ↓
[code-level TDD loop]   TS → TC[RED] → SRC → TC[GREEN]
        ↓
[independent verification channels]  AT, NFR
```

Each layer has its own RED/GREEN cycle, and you do not descend to a lower layer until the upper
layer is GREEN. **The front-pass loop is a precondition for the spec-level TDD loop**: a SPEC whose
FCR is not ACCEPTED must not become a target for TP[SPEC] / UC work (Hard Rule 9). **There must be
no layer contamination between the ICONIX abstract and concrete tiers** (Hard Rule 10).

### Responsibilities of each layer (summary)

| Layer | Input | Output | RED condition | GREEN condition |
|---|---|---|---|---|
| Front-pass loop | Raw SPEC | QSET, SPP, FCR | FCR has unmet items, or developer has not approved | Latest FCR is ACCEPTED (required-item template filled + terminology consistent + no contradictions + exception paths covered + boundary consistency + UC-generatability + human approval) |
| Spec-level TDD (SPEC) | Accepted SPEC | TP, GAP | A TP has an open GAP | All GAPs closed, all TPs green |
| Spec-level TDD (UC) | UC draft | TP, GAP | A TP has an open GAP | All GAPs closed, all TPs green |
| ICONIX abstract tier | UC (GREEN) | RBA, SEQA | Insufficient domain-subject extraction, unclear responsibility scope, communication-constraint violation | All UCs expanded on the abstract side, communication constraints honored |
| ICONIX concrete tier | RBA, SEQA (GREEN) | RBD, SEQD, DD | Ambiguous class boundaries, layer contamination (function names/types/modifiers leaking in) | Class diagrams complete, `scripts/trace-check.sh` layer-contamination check passes, API frozen in DD |
| Code-level TDD | DD, TP | TS, TC, SRC | TC fails (because unimplemented) | All TCs pass, trace check passes |
| AT | SRC (GREEN) | AT results, new perspectives | An AT fails | All ATs pass, or failures converted to GAPs |
| NFR | SRC (GREEN) | benchmark results | An NFR is violated | All NFRs pass, or improvements filed as issues |

## 3. Moving the Trust Boundary Upstream

| What the traditional process trusted | What this process trusts |
|---|---|
| Human code review | Completeness of TP generation |
| Human reading of the spec | Filter precision of GAP analysis |
| Human test-design skill | legixy's consistency checks |
| Bottom-up quality construction | The verified state of the whole chain |

Of the three reasons humans read code, (1) confirming spec completeness and (2) confirming
spec↔implementation consistency are pushed up into machine-verifiable layers. What remains is only
(3) code-specific quality confirmation, which compresses to performance, concurrency, FFI
boundaries, and architectural judgment.

## 4. The Core Operation: Making Things Observable

Spec incompleteness is inherently unobservable. But by generating TPs (test perspectives) and
throwing them against the spec, it can be converted into **observable omissions**. A GAP is the
record of that conversion.

This lets even domains with poor internal-concept formalization gradually acquire properties close
to an external spec, through the TP/GAP loop.

## 5. What Can and Cannot Be Detected

| Domain | Detection means |
|---|---|
| Spec completeness (boundary values, errors, permissions, state transitions, abnormal paths) | TP / GAP |
| Spec↔implementation consistency | TDD + legixy |
| Performance, concurrency, resource management | NFR + benchmarks |
| Tacit knowledge, domain conventions, mismatched assumptions | AT (acceptance tests, human-centric) |

The last category is, in principle, undetectable by spec-level TDD. AT is the dedicated independent
channel for it.

## 6. The Self-Similarity of the RED → GREEN Cycle

The five layers share the same "TDD rhythm" at different granularities:

```
Front-pass loop: Raw SPEC → throw questionnaire → detect unmet items → developer answers → approve diff → FCR ACCEPTED
Spec level:      spec draft → throw perspectives → discover GAP → fix spec → all perspectives GREEN
ICONIX abstract: UC → extract domain subjects → detect communication-constraint violation → fix → RBA/SEQA GREEN
ICONIX concrete: RBA/SEQA → map to class diagram → detect layer contamination → fix → RBD/SEQD/DD GREEN
Code level:      TS → TC[RED] → minimal implementation → TC[GREEN]
```

Proceeding to the next layer while RED is showing is a discipline violation. Hard Rules 2, 9, and 10
forbid it.

## 7. Phased Adoption

When retrofitting an existing project, do not stand up all layers at once:

1. **Phase 1**: Introduce TP/GAP for the SPEC layer only. Start with the rule "you cannot proceed to
   UC until GAP[SPEC] is closed."
2. **Phase 2**: Extend to the UC layer too. Full flow.
3. **Phase 3**: Explicitly separate AT as an independent typecode. Wire it in as a pre-release gate.

The effectiveness metric for each phase is "the number of spec-induced bugs discovered at TS and
later." If it drops as phases advance, the upstream move of the trust boundary is working.

See [`../ja/guides/adoption-phases.md`](../ja/guides/adoption-phases.md).

## 8. Three Grand Principles When Using the Process

1. **Ask humans about unknowns; do not fill them with guesses.** "Filling in" is the chief cause of
   the old process's breakdown.
2. **Do not skip gates.** When you do, record it in an ADR. Unrecorded skips accelerate the process
   becoming a hollow shell.
3. **AI-generated artifacts must cite their upstream IDs.** Do not create downstream artifacts with
   no cited source, so drift can be detected later.

---

What to read next:

- Artifact types and ID rules → [`../ja/02-typecodes.md`](../ja/02-typecodes.md)
- **Front-pass loop (normalizing Raw SPEC → Accepted SPEC) → [`../ja/03a-frontend-pass.md`](../ja/03a-frontend-pass.md)**
- Upstream loop (SPEC/UC ⇄ TP ⇄ GAP) procedure → [`../ja/03-spec-level-tdd.md`](../ja/03-spec-level-tdd.md)
- Gate decisions common to all layers → [`../ja/08-gates.md`](../ja/08-gates.md)
- An alternate lens describing the pipeline, the 4-layer structure, and the IR hierarchy in compiler vocabulary → [`../ja/09-compiler-lens.md`](../ja/09-compiler-lens.md)
