# clawdance — Roadmap

**Everything in this document is a draft.** Nothing is fixed. When working
on any area, always consider the big picture — any decision, pattern, or
design in this roadmap (or in code) may need to be refactored based on
what we learn. Do not treat earlier sections as settled just because they
were written first. The roadmap evolves as understanding deepens. Be ready
to change anything, anytime.

## Vision

Give a high-level app idea to the system and have it built as autonomously
as possible, leveraging the Claude ecosystem to its fullest potential.

## Current status: Planning

We are defining what to build. No implementation has started.

### Decisions made

- [ADR-001](decisions/001-public-api-only.md) — Public API only. No Claude
  Code internal APIs.
- [ADR-002](decisions/002-extend-omc-not-rebuild.md) — Extend OMC, don't
  rebuild orchestration from scratch.
- [ADR-003](decisions/003-typescript-for-implementation.md) — TypeScript for
  implementation (draft).
- [ADR-004](decisions/004-build-own-cost-tracking.md) — Build own cost
  tracking, don't depend on ccusage (draft).

### Research completed

- [Ecosystem analysis](research/ecosystem.md) — OMC, clawhip, OmO, and the
  broader landscape.
- [Challenges](research/challenges.md) — Near-certain and likely problems
  for autonomous app development, with mitigations.
- [Quality comparison](research/quality-comparison.md) — OMC vs Bildhauer
  vs Clippy enforcement approaches.
- [Convergent audit loop](research/convergent-audit-loop.md) — Pattern for
  autonomous iterative auditing with diminishing returns detection.
- [Cross-session daemon](research/cross-session-daemon.md) — Analysis of
  whether/how to orchestrate across session boundaries.

---

## Product workflow: Idea to App

This is the order in which a user goes from app idea to finished product.
This order is fixed (though iteration loops back to earlier steps).

### Step 1 — Requirements

Clarify what to build. Scope to MVP. Kill scope creep before it starts.

Input: vague app idea from the user.  
Output: scoped requirements document on disk.

Key concerns:
- Explicit MVP boundary (what's in, what's deferred to v2/v3)
- User-facing behavior described, not implementation details
- Ambiguity resolved via back-and-forth with the user

### Step 2 — Design

Architecture, tech stack, data model, API contracts, component breakdown.

Input: requirements document from step 1.  
Output: design artifacts on disk — DESIGN.md, contract files (API schemas,
data models), STACK.md, component breakdown.

Key concerns:
- Contracts must exist as files before any implementation starts (prevents
  semantic conflicts between parallel agents)
- Tech stack decisions captured in STACK.md so agents don't introduce
  unwanted dependencies
- Design decisions written with rationale (survives compaction)

### Step 3 — Implementation

Autonomous build with parallel agents working from the design artifacts.

Input: design artifacts and contract files from step 2.  
Output: working code in branches/worktrees, with per-component tests.

Key concerns:
- Agents read contract files, not conversation context
- Parallel agents in worktrees — semantic consistency enforced by contracts
- Context persistence: checkpoint files written at phase boundaries so
  sessions can resume after rate limits/crashes
- Per-agent quality: review pipeline (verify, code-review, security-review)

### Step 4 — Integration

Merge parallel work, resolve conflicts, run end-to-end tests.

Input: completed branches/worktrees from step 3.  
Output: integrated codebase on a single branch, passing end-to-end tests.

Key concerns:
- Semantic conflicts surface here (file conflicts caught by git, but
  mismatched API assumptions only caught by integration tests)
- End-to-end tests run against the merged codebase, not individual
  worktrees
- This is a verification gate, not "just merge"

### Step 5 — Validation

Does the integrated product meet the original requirements?

Input: integrated codebase from step 4, requirements from step 1.  
Output: validation report — what works, what doesn't, what's missing.

Key concerns:
- Check against requirements document, not just "does it compile"
- User acceptance: does the product match the user's intent?
- Security review of the whole, not just individual components

### Step 6 — Iteration

Feedback loops back to any earlier step.

- "The API is wrong" → back to step 2 (design)
- "Missing a feature" → back to step 1 (requirements)
- "Bug in the auth flow" → back to step 3 (implementation)
- "Tests don't cover edge case" → back to step 4 (integration)

---

## Roadmap work items

These are the things we need to build/flesh out to make the product workflow
above work. **These are NOT ordered sequentially.** We can work on any item
at any time. When working on one item, check whether it affects any other
item and adjust accordingly.

### A — Implementation flow (product steps 3-4)

The core. Making "here's a task, build it autonomously" work with OMC +
our mitigations.

Includes:
- Context persistence across compaction and sessions
- Contract coordination for parallel agents
- Cross-session continuity (checkpoints, resumption)
- Integration testing across components
- See [challenges](research/challenges.md) for full list

### B — Design flow (product steps 1-2)

Taking an app idea and producing design artifacts that step A consumes.

Includes:
- Requirements clarification flow (scope, MVP boundary)
- Architecture and tech stack selection
- Contract/schema generation as files
- Design document format that agents can consume

### C — Gap-filling between A and B

Whatever we discover doesn't connect cleanly between design output and
implementation input. The handoff, the seams. TBD as we work on A and B.

### D — Extensions

Technical improvements and additional features:
- Cost tracking and budget enforcement
- Cross-backend routing (Claude → Codex for cost-sensitive work)
- Ideas from OmO's patterns (category-based delegation, multi-model
  fallback chains)
- Bildhauer/Clippy integration into the orchestration pipeline
- See [quality comparison](research/quality-comparison.md)

### E — Packaging, validation, and distribution

- End-to-end validation against real projects
- Plugin packaging for easy installation
- Documentation for users
- Community feedback and iteration

**Cross-impact note:** Changes to any item may affect others. In particular:
- Changes to A (implementation) may reveal requirements for B (design) —
  "implementation needs X as input, so design must produce X"
- Changes to B (design) may change what A expects as input
- Changes to D (extensions) may require adjustments to A or B
- Always check adjacent items when modifying one

---

## Core stack

- **OMC** (oh-my-claudecode) — In-session orchestration. Task decomposition,
  parallel agents, review pipeline, recovery. Covers ~85% of the autonomous
  development flow.
- **clawhip** — Event routing and notifications. Monitors sessions, routes
  to Discord/Slack.
- **Claude Code** — The runtime. All integration through public consumer
  interface (hooks, MCP, skills, CLAUDE.md, Agent tool, SendMessage, Tasks).

## Open questions

1. What form does context persistence take? Skills that enforce writing
   design docs? A project template? Modifications to OMC's pipeline stages?

2. How do we handle cross-session continuity? A daemon that manages session
   lifecycle? Structured checkpoint files that a new session reads? Both?

3. Where do Bildhauer/Clippy integrate — as OMC pipeline stages, as
   enhanced agent definitions, or as separate plugins?

4. Should we add cost tracking and cross-backend routing (Claude → Codex)?
   Deferred until core flow works, but remains a genuine ecosystem gap.

## Repository structure

```
docs/
├── ROADMAP.md                   # This file
├── decisions/                   # ADRs (numbered, with reasoning)
├── research/                    # Ecosystem analysis, challenges, comparisons
└── specs/                       # Future: contracts, schemas, component specs
upstream/
├── oh-my-claudecode/            # Fork (submodule) — build on and PR to
└── clawhip/                     # Fork (submodule) — build on and PR to
reference/
└── oh-my-openagent/             # Fork (submodule) — study material
src/                             # Our own code (when we build things)
```
