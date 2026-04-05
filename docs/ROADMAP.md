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
- [ADR-005](decisions/005-thin-layer-over-gas-town.md) — Thin layer on OMC,
  not Gas Town adoption. Gas Town is the upgrade path for multi-project.

### Research completed

- [Competitive landscape](research/competitive-landscape.md) — Direct and
  adjacent competitors. Key finding: within-session orchestration is crowded,
  cross-session constraint persistence is unoccupied.
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
- [Real-world validation](research/real-world-validation.md) — Bug taxonomy
  from a multi-session autonomous build. Validates challenges, informs tool
  placement.
- [Gas Town analysis](research/gas-town-analysis.md) — Deep comparison with
  Gas Town fleet manager. Lessons learned, future integration path.
- [Competitive landscape](research/competitive-landscape.md) — Direct and
  adjacent competitors. Cross-session constraint persistence is unoccupied.

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
Output: working code in branches/worktrees, with per-component and
per-connection integration tests.

Key concerns:
- Agents read contract files, not conversation context
- Parallel agents in worktrees — semantic consistency enforced by contracts
- Context persistence: checkpoint files written at phase boundaries so
  sessions can resume after rate limits/crashes
- Cross-component constraints persisted to files (not just API contracts —
  also operational invariants like "tool X requires allowlist entry in Y")
- Per-agent quality: review pipeline (verify, code-review, security-review)
- **Pre-phase investigation gate:** before each phase, investigate existing
  codebase for constraints that affect new work (Clippy principle)
- **Data-flow boundary trace:** before implementing cross-component
  connections, read both producing and consuming ends (Bildhauer principle)
- **Per-connection integration tests:** when a cross-component connection
  is created, write the integration test immediately — don't defer to step 4

### Step 4 — Integration

Merge parallel work, resolve conflicts, run full-stack end-to-end tests.

Input: completed branches/worktrees from step 3 (each with per-connection
integration tests already passing).  
Output: integrated codebase on a single branch, passing full-stack e2e tests.

Key concerns:
- Per-connection integration tests already ran during step 3 — this step
  runs the full stack together for the first time
- Semantic conflicts surface here (file conflicts caught by git, but
  mismatched API assumptions only caught by integration tests)
- End-to-end tests run against the merged codebase, not individual
  worktrees
- This is a verification gate, not "just merge"
- Convergent audit loop runs here for cross-codebase quality assessment

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
our mitigations. **Spec draft:** [automation-flow](specs/automation-flow.md).

Architecture: three components.
- **On-disk state** (task graph, checkpoints, constraints) — the real
  system. Survives sessions, crashes, rate limits. YAML files.
- **Session skill** — SKILL.md prompt template. Reads state, picks next
  unit, invokes OMC (ralph for single units, team for parallel groups),
  writes checkpoints.
- **Session loop** — bash script (~30 lines). Spawns tmux sessions with
  claude, polls for session death, checks state, loops. MVP: human
  replaces this.

Build order:
1. constraints.yaml schema (highest proven value — prevents session-boundary bugs)
2. State format (task graph, checkpoints, state.yaml)
3. Session skill (SKILL.md — core execution logic)
4. Task decomposer (SKILL.md — design artifacts → task graph)
5. Session loop (bash script)
6. Telegram sink for clawhip (Rust — extend our fork with Telegram bot
   API support for build progress notifications)

Includes:
- Context persistence across compaction and sessions
- Contract coordination for parallel agents
- Cross-session continuity (checkpoints, resumption)
- Integration testing per-connection during implementation
- Pre-phase investigation gates (Bildhauer/Clippy principles)
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
- Cross-backend routing (Claude -> Codex for cost-sensitive work)
- Ideas from OmO's patterns (category-based delegation, multi-model
  fallback chains)
- ~~Telegram sink for clawhip~~ — moved to item A build order
- **Moved to A:** Bildhauer/Clippy principles are now part of the
  implementation flow (step 3 pre-phase gates), not a separate extension.
  External plugin integration remains a noted alternative if built-in
  approach proves insufficient.
- See [quality comparison](research/quality-comparison.md)

### E — Packaging, validation, and distribution

- End-to-end validation against real projects
- Plugin packaging for easy installation
- Documentation for users
- Community feedback and iteration

**Dependency chain:**

```
B (design) ──produces──► A (implementation) ──produces──► Steps 4-5
                              │
                              ├── constraints.yaml ◄── feeds back to B
                              ├── session loop + Telegram ◄── D extends
                              └── all of it ◄── E packages
```

- **A is the foundation.** Everything else plugs into it.
- **B feeds A.** B produces the design artifacts (DESIGN.md, STACK.md,
  contracts/) that A's decomposer consumes. B must produce artifacts
  matching A's required input format (see spec, resolved question 4).
- **A feeds back to B.** constraints.yaml discovered during implementation
  can reveal design problems — "this constraint means the design needs
  to change." Iteration (step 6) routes back through B.
- **C is discovered, not built.** The gap between B's output and A's input
  is found by testing A+B together. C resolves as we validate the handoff.
- **D extends A.** Cost tracking hooks into the session loop (budget per
  session/unit). Cross-backend routing extends the session skill's unit
  dispatch. OmO patterns extend OMC invocation.
- **E wraps everything.** End-to-end validation runs the full A+B pipeline
  on a real project. Packaging bundles skills, conventions, session loop,
  clawhip config (including Telegram sink).

**Cross-impact note:** Changes to any item may affect others. Always check
adjacent items when modifying one.

---

## Core stack

- **OMC** (oh-my-claudecode) — In-session orchestration. Task decomposition,
  parallel agents, review pipeline, recovery. Covers ~85% of the autonomous
  development flow.
- **clawhip** — Event routing and notifications. Monitors sessions, routes
  to Discord/Slack/Telegram (Telegram sink to be added to our fork).
- **Claude Code** — The runtime. All integration through public consumer
  interface (hooks, MCP, skills, CLAUDE.md, Agent tool, SendMessage, Tasks).

## Open questions

1. ~~Context persistence form?~~ **Resolved:** YAML files on disk
   (constraints.yaml, task-graph.yaml, checkpoints/, state.yaml).
   Session skill (SKILL.md) reads and writes them. See
   [automation-flow spec](specs/automation-flow.md).

2. ~~Cross-session continuity?~~ **Resolved:** Bash session loop (~30
   lines) spawns tmux sessions, polls for death, checks state, loops.
   No daemon. MVP: human restarts manually. See
   [automation-flow spec](specs/automation-flow.md) and ADR-005.

3. ~~Where do Bildhauer/Clippy integrate?~~ **Resolved:** Absorb their
   principles into our own pipeline, not as external plugins. Pre-phase
   investigation gate (Clippy principle) and data-flow boundary trace
   (Bildhauer principle) built into step 3. External plugin integration
   remains a noted alternative. See [real-world validation](research/real-world-validation.md)
   and [quality comparison](research/quality-comparison.md).

4. Should we add cost tracking and cross-backend routing (Claude → Codex)?
   Deferred until core flow works (roadmap item D), but remains a genuine
   ecosystem gap.

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
