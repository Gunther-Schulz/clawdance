# Session Handoff

**Last updated:** 2026-04-06
**Status:** Major architectural decision — merge clawdance into Clippy.

## What happened this session

### Phase 1: Design, implementation, first test
Full design phase, competitive analysis, Gas Town, bildhauer updates.
Implemented item A plugin. First test: habit tracker, 31 tests passing.

### Phase 2: Architecture revision
Discovered we were using only ralph from OMC (Phase 2 of 5), skipping
QA cycling and multi-reviewer validation. Investigated OMC's full
pipeline and Clippy's investigation discipline.

### Phase 3: Tool relationship decision
Evaluated: clawdance as separate orchestrator vs merging into Clippy.

**Decision: merge clawdance into Clippy.**

Clippy becomes the single tool. Its composer gets extended with:
- Design phase (interactive, iterative, contracts)
- Decomposition (task graph)
- Cross-session state (constraints, checkpoints, session loop)
- OMC integration (calls ralph for execution — OMC optional, only
  needed for autonomous mode)
- Post-implementation pipeline: TBD, separate discussion

Interactive Clippy stays zero-dependency (as today).
Autonomous Clippy requires OMC as execution engine.

**Rationale:** The investigation discipline IS what makes autonomous
development work. Separating "the investigation tool" from "the build
tool" was artificial. One plugin, one state directory, one install.

### Clippy refactor already done
- investigate-design skill has autonomous mode (--autonomous flag)
- Internal cycle looping, structured return, tracker to disk
- Committed and pushed to coding-clippy repo

### Bildhauer updates
- Observation 22 + session-level conflation fix
- Conditional self-challenge
- Retrospective diminishing returns
- Data-flow tracing as most productive element

## Where to pick up

### Immediate: merge plan

1. **Plan the Clippy extension** — which clawdance skills move into
   Clippy, how the composer handles autonomous mode with design →
   investigate → OMC ralph → checkpoint.

2. **Move product code** — clawdance skills → Clippy skills.
   clawdance repo becomes: docs, research, planning only (or archived).

3. **State directory** — `.ai/` with subdirs? `.clippy/` extended?
   Decide naming.

4. **OMC integration in Clippy** — composer checks for OMC when
   autonomous mode is requested. Optional dependency.

5. **Cross-session state in Clippy** — constraints.yaml, checkpoints,
   session loop. These are new Clippy capabilities.

6. **Post-implementation pipeline** — separate discussion. Could be
   Clippy verify, OMC Phase 3-4, both, or configurable.

### clawdance repo future

Options:
- Archive (docs stay, product code moves to Clippy)
- Keep as planning/research workspace (no product code)
- The Telegram sink for clawhip stays here or moves to clawhip fork

### Context the next session needs

- **KEY DECISION: clawdance merges into Clippy.** Clippy becomes the
  autonomous development orchestrator.
- Clippy repo: ~/dev/Gunther-Schulz/coding-clippy
- clawdance repo: ~/dev/Gunther-Schulz/clawdance (product code to move)
- OMC source: ~/dev/Gunther-Schulz/clawdance/upstream/oh-my-claudecode
- Gas Town: ~/dev/reference/gastown
- Autonomous investigate-design already implemented in Clippy
- First test (habit tracker) proved the basic flow works
- All clawdance research/design docs are valuable — they inform the
  Clippy extension design
- Bildhauer updated multiple times this session
