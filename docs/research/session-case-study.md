# Session Case Study: Manual Walk of the Automated Workflow

Research conducted 2026-04-05. Analysis of our own design session as the
first case study for the workflow clawdance automates.

## What happened

A single session went from "real-world bug data from another project" to
"implementation-ready spec with all risks resolved." This manually walked
the same path clawdance automates: idea → research → design → decompose →
validate → implementation plan.

## The iterative loop we discovered

The session didn't follow a linear pipeline. Four elements alternated
throughout:

### 1. Find problems (bildhauer principles)

Five Bildhauer passes found: parallel constraint write conflicts,
underspecified OMC invocation, missing YAML validation, session loop
invocation gap, consecutive_failures reset bug. Every pass used data-flow
tracing ("what writes this, what reads it") as the primary mechanism.

### 2. Resolve problems (investigation)

When bildhauer found "OMC invocation is underspecified," investigation
agents read OMC source. When bildhauer surfaced "is Gas Town better?",
we cloned and analyzed Gas Town. When bildhauer questioned "does ralph
return control?", we read ralph's SKILL.md. Bildhauer identifies gaps;
investigation closes them.

### 3. Persist what's learned (constraints + docs)

Every finding was persisted: ADRs for decisions, research docs for
analysis, spec revisions for design changes, constraints for invariants.
If this session had been split across 3-4 sessions without persistence,
the parallel write conflict, Gas Town portability analysis, and ralph
invocation pattern would have been re-investigated.

### 4. Human judgment (redirects)

The user provided redirections that none of the other three could derive:
- "Does Gas Town scale down?" → drove the stack decision
- "What can OMC do that Gas Town can't?" → clarified layer separation
- "We are working on docs, not code!" → kept us in the right phase
- "I want Telegram" → added a requirement from preference
- "Let's resolve those now" → prevented premature deferral

## Mapping to clawdance mechanisms

| Loop element | What we did manually | clawdance mechanism |
|---|---|---|
| Find problems | Bildhauer passes at transitions | Pre-phase investigation gate, post-unit constraint review |
| Resolve problems | Investigation agents, source reading | Contract reading, codebase investigation, ralph verification |
| Persist findings | ADRs, research docs, spec updates | constraints.yaml, checkpoints, state.yaml |
| Human judgment | User questions and redirections | Human checkpoint after decomposition, Telegram monitoring |

## Key observations

### The loop catches whatever is project-relevant

We observed: over-engineering (daemon → bash), missing ecosystem knowledge
(Gas Town), unverified technical assumptions (ralph behavior), and
undiscovered constraints (parallel writes). These are specific to THIS
session. A different project would surface different things. The loop is
general-purpose; the findings are project-specific.

### Constraints were discovered continuously

| Phase | Constraint discovered |
|---|---|
| Spec design | Parallel write conflict on constraints.yaml |
| OMC investigation | Skills invoke via Skill() tool |
| Gas Town analysis | Conventions must be portable |
| Implementation planning | Loop must send `/clawdance resume` |
| Bildhauer pass 5 | consecutive_failures never reset |

No single "constraint discovery phase" would have found all of these.
The post-unit constraint review captures some; integration tests catch
others; design-phase analysis catches the rest. The `discovered_by` field
tracks which mechanism found each constraint.

### Session boundaries would have been devastating

This session produced 5 ADRs, 8 research/spec documents, an
implementation plan, and bildhauer updates. Split across sessions without
constraint persistence, later sessions would have re-investigated the
same questions and potentially made different (inconsistent) decisions.

This is exactly the problem clawdance exists to solve — and we
experienced it firsthand as evidence.

### Bildhauer diminishing returns were real

Passes 1-3: high value (structural gaps). Pass 4: moderate (new content).
Pass 5: marginal (one bug, three notes). The new observation 19
(diminishing returns on stable artifacts) was added to bildhauer based
on this evidence.

## What this means for the automation

The product workflow (steps 1-6 in the roadmap) is correct as a
progression, but the real process is an iterative loop of all four
elements at every transition. The automation doesn't need hardcoded
phases for "research" or "simplification" — it needs the four-element
loop running robustly, and the loop catches whatever emerges.

The three components (on-disk state, session skill, session loop) are
the infrastructure. The four elements (find, resolve, persist, redirect)
are the process running on that infrastructure. The session skill
orchestrates find + resolve + persist per unit. The session loop keeps
it running across sessions. The human enters at defined checkpoints.

## Two review angles, complementary

The session used two distinct review mechanisms at different frequencies:

**Sweep checks** — broad, open-ended ("anything left to analyze?"). Caught
housekeeping issues: stale ADR-003, duplicate roadmap entry, loose ends.
Cheap, one pass, used frequently after any block of work.

**Bildhauer checks** — structural, prescribed mechanisms (data-flow trace,
structural alternative, assumption check). Caught architectural problems:
parallel write conflicts, wrong framing, unverified assumptions. Expensive,
full procedure, used at transitions until diminishing returns.

These are complementary, not redundant:
- Sweep checks find things Bildhauer misses (housekeeping, consistency)
- Bildhauer finds things sweep checks miss (structural problems that
  require specific lenses to see)

**Implication for automation:** The session skill should do cheap sweep
checks per unit ("is state consistent? any missing fields?") and deeper
Bildhauer-style checks at transitions (after parallel groups complete,
before full-stack integration tests). Multiple review angles, different
frequencies.
