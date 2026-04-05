# Session Handoff

**Last updated:** 2026-04-05
**Status:** Item A theoretically complete — ready for first real build

## What happened this session

1. Analyzed real-world bug data from multi-session autonomous build.
   Key finding: session boundaries cause correctness bugs through lost
   cross-component constraints.

2. Decided to absorb Bildhauer/Clippy principles into pipeline (not
   external tools).

3. Designed core automation flow (specs/automation-flow.md). Started as
   three-component TypeScript architecture, simplified through investigation
   to: YAML state + SKILL.md + bash script.

4. Investigated OMC internals, Claude Code CLI, clawhip sinks. Confirmed
   all load-bearing assumptions.

5. Deep-dived Gas Town. Concluded: thin layer on OMC for single-project
   builds, Gas Town as upgrade path (ADR-005). Verified full portability
   of our conventions to Gas Town.

6. Competitive landscape research. Cross-session constraint persistence
   is an unoccupied niche.

7. Resolved all open questions and risks for item A:
   - Ralph: prompt loop, session skill wraps it, inlines context. Resolved.
   - PreCompact: 80-90% lead time, unit count safety net. Resolved.
   - Unit sizing: ralph's prd.json provides sub-unit checkpointing, so
     oversized units cost a session start, not a session of work. Decomposer
     includes validation heuristics. Reduced from high to low risk.
   - Constraint discovery: discovered_by tracking + ralph's progress.txt
     as second channel. Self-improving. Resolved.
   - Gas Town portability: full mapping verified. Resolved.

8. Added Telegram sink for clawhip to item A build order (step 6).

### Documents created/updated

- **Created** docs/research/real-world-validation.md
- **Created** docs/research/competitive-landscape.md
- **Created** docs/research/gas-town-analysis.md
- **Created** docs/specs/automation-flow.md (revised extensively)
- **Created** docs/decisions/005-thin-layer-over-gas-town.md
- **Updated** docs/research/challenges.md
- **Updated** docs/research/quality-comparison.md
- **Updated** docs/ROADMAP.md

### Key decisions

- ADR-005: Thin layer on OMC, not Gas Town adoption
- Absorb Bildhauer/Clippy principles, don't integrate as external tools
- constraints.yaml is highest-priority build item
- Session loop is bash script (~30 lines), not TypeScript daemon
- Ralph is the execution engine per unit; session skill wraps it
- Telegram sink for clawhip committed (item A, step 6)

## Where to pick up

### Item A status: theoretically complete

All risks resolved or reduced to low. Two items remain that can only be
validated by building:
1. End-to-end flow integration (decomposer → skill → ralph → checkpoint
   chain has never run together)
2. Constraint review prompt effectiveness (plausible, tracked via
   discovered_by, but untested)

### What to build (in priority order)

1. constraints.yaml schema + convention
2. State format (task graph, checkpoints, state.yaml)
3. Session skill (SKILL.md)
4. Task decomposer (SKILL.md)
5. Session loop (bash script)
6. Telegram sink for clawhip (Rust)

### Next moves

- **Option A:** Start building item A (constraints.yaml first)
- **Option B:** Move to item B (design flow) — define the design artifact
  format and requirements clarification flow that feeds into item A
- **Option C:** Try the full flow on a real project to validate end-to-end
- **Option D:** Revisit ADR-003 (TypeScript) — may not need a programming
  language at all for items 1-5, only Rust for the Telegram sink

### Context the next session needs

- Core spec: `docs/specs/automation-flow.md` — READ THIS FIRST
- Gas Town analysis: `docs/research/gas-town-analysis.md`
- OMC is used as-is (ADR-002). Ralph for single units, team for parallel.
- Ralph is a PRD-driven prompt loop. Session skill wraps it, inlines
  contract/constraint context. Ralph's prd.json provides sub-unit
  checkpointing.
- Gas Town is the upgrade path, not the starting point (ADR-005).
  All conventions verified portable.
- Telegram sink committed to item A build order.
- Everything is a draft. The user works out of order.
- Gas Town cloned at ~/dev/reference/gastown for reference.
