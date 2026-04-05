# ADR-005: Thin layer on OMC, not Gas Town adoption

**Status:** Accepted  
**Date:** 2026-04-05

## Context

Gas Town (steveyegge/gastown) provides comprehensive cross-session agent
fleet management: persistent agent identity, session lifecycle (daemon +
Witness + Deacon), work tracking (Beads), checkpoint recovery (poured
wisps), merge queue (Refinery), session discovery (Seance), multi-runtime
support, rate limit scheduling.

It covers most of what we planned to build for cross-session continuity.
Five of seven planned components already exist in Gas Town. The two things
it doesn't provide — constraint persistence and design-artifact-driven
decomposition — are our actual contribution.

## Decision

Build a thin layer on OMC (YAML state + session skill + bash loop) rather
than adopting Gas Town as the cross-session layer.

### Rationale

**Cost/benefit for single-project autonomous builds:**

Gas Town's benefits over our approach (Seance, Refinery, multi-runtime,
persistent identity) are nice-to-haves for a single project. Its costs
(Go + Dolt + Beads + SQLite dependencies, ~15 concepts, setup ceremony,
untested OMC integration) aren't justified for one project.

Our approach: zero additional dependencies, ~5 concepts, trivial setup,
~200 lines of SKILL.md + ~30 lines of bash + YAML conventions.

**The Kubernetes analogy:** Gas Town is Kubernetes for AI coding agents.
We're deploying one container. `docker run` is the right tool.

**OMC and Gas Town don't overlap — they're different layers:**
- OMC: in-session execution quality (review, retry, model routing,
  behavioral enforcement)
- Gas Town: cross-session lifecycle management (state, identity, restart,
  merge queue)

We need OMC's layer (execution quality) regardless. The question was only
whether Gas Town or our thin layer provides the cross-session piece.

### Design principle

Keep conventions (constraint persistence, design artifact format,
checkpoint structure) independent of the execution layer. If we later need
fleet management, Gas Town becomes the upgrade path with our conventions
ported to its polecat workflow.

## Alternatives considered

| Alternative | Why not |
|---|---|
| Gas Town + OMC | Dependency weight, conceptual overhead, integration risk for one project |
| Gas Town instead of OMC | Loses in-session quality (review pipeline, smart retries, enforcement) |
| Just conventions (CLAUDE.md only) | Agents don't reliably recognize constraints at creation time — needs enforcement, not instruction |
| OMC patches only (no separate project) | Doesn't cover session lifecycle or constraint persistence convention |

## Consequences

- We build and maintain cross-session state (YAML), session skill
  (SKILL.md), and session loop (bash) ourselves
- Less battle-tested lifecycle management than Gas Town (30 lines vs
  6,900 commits)
- Zero additional dependencies — our stack is Claude Code + OMC
- Simple to modify (text files vs Go codebase)
- Gas Town remains the upgrade path for multi-project scaling
- Constraint persistence and design-artifact decomposition remain our
  unique contribution regardless of execution layer
