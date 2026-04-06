# Session Handoff

**Last updated:** 2026-04-06
**Status:** Major architecture revision in progress. First test complete.

## What happened this session

### Phase 1: Design and implementation (completed)
Full design phase: real-world validation, architecture, competitive
analysis, Gas Town deep-dive, stack decisions, Bildhauer validation.
Implemented item A: plugin with orchestrator + phase skills + session
loop + Telegram sink for clawhip.

### Phase 2: First test run (completed)
Habit tracker API built from one-line idea. 8/8 units, 31 tests passing.
Validated: design phase, decomposition, task graph, ralph execution,
checkpointing. Found: transparency gap, constraint schema drift,
direct agent delegation breaks checkpoint loop (fixed).

### Phase 3: Architecture revision (in progress)
Critical discovery: we were using only ralph from OMC, ignoring the
full pipeline (QA cycling, multi-reviewer validation). This happened
because we built our own orchestrator that reaches INTO OMC instead of
handing off TO OMC.

Investigation of OMC's full pipeline revealed:
- Phase 0-1: Expansion + Planning (we replaced with our design phase)
- Phase 2: Execution via ralph (we use this)
- Phase 3: QA cycling via ultraqa (we skipped entirely)
- Phase 4: Multi-reviewer validation — architect + security-reviewer +
  code-reviewer all must approve (we skipped entirely)

Investigation of Clippy revealed:
- Pre-implementation investigation with V1 evidence standards
- 2-5 investigation cycles before implementation
- Tracker with explicit unknowns, assumptions, design decisions
- This is what prevents "build it wrong, then hotfix" — the validated
  problem from our real-world data

### Revised per-unit pipeline (decided)

```
Per unit:
  → Clippy investigate-design (understand codebase, resolve unknowns)
  → OMC Phase 2 (ralph execution)
  → [Phase 3-4 TBD — separate discussion]
  → clawdance checkpoint + constraint review
```

Clippy provides pre-implementation investigation (what OMC lacks).
OMC provides execution (what Clippy isn't designed for at scale).
clawdance provides cross-session continuity (what both lack).

### Clippy refactor plan (drafted)
Plan at: coding-clippy/docs/plans/autonomous-mode.md
Scope: make investigate-design skill invocable autonomously with results
on disk. Internal looping (2-5 cycles per invocation), V1 standards
unchanged, tracker written to .clippy/tracker.yaml.

### Bildhauer updates
- Observation 22: diminishing returns (+ session-level conflation failure)
- Procedure: conditional self-challenge, explicit artifact identification,
  retrospective (not predictive) diminishing returns check
- Strategy: data-flow tracing as most productive finding mechanism

## Key decisions this session

- ADR-005: Thin layer on OMC, not Gas Town
- ADR-003 superseded: no TypeScript (YAML + SKILL.md + bash + Rust)
- Orchestrator + phase skills architecture
- Single entry point: /clawdance "Build me X"
- Design phase: our interactive design → Clippy investigation → OMC
  execution. Each tool does what it's best at.
- .omc/ littering: install OMC per-project, not globally
- Four-element loop: find, resolve, persist, redirect

## Where to pick up

### Immediate next

1. **Implement Clippy autonomous investigation mode** — the refactor
   plan is at coding-clippy/docs/plans/autonomous-mode.md. Add
   --autonomous flag to investigate-design skill.

2. **Integrate Clippy investigation into clawdance build skill** —
   before invoking ralph, invoke Clippy's autonomous investigation.
   Feed investigation findings into the ralph prompt.

3. **Decide on post-implementation pipeline** — QA cycling (OMC ultraqa
   or our own) + review (OMC reviewers or Clippy verify or our own).
   Separate discussion.

4. **Fix .omc/ littering** — update docs to recommend per-project OMC
   install. Investigate if OMC has a config to disable state in non-OMC
   projects.

### Context the next session needs

- Plugin is installed and working: /clawdance "Build me X"
- First test produced a working habit tracker (31 tests passing)
- Architecture is being revised: Clippy investigation + OMC execution
- Clippy refactor plan exists at coding-clippy/docs/plans/
- OMC source at upstream/oh-my-claudecode/ (cloned, not submodule)
- Gas Town at ~/dev/reference/gastown
- Bildhauer updated multiple times this session
- Everything is a draft. User works out of order.
