# clawdance

Autonomous app development stack built on the Claude ecosystem.

## Project context

clawdance extends oh-my-claudecode (OMC) and clawhip to enable autonomous
app development — from idea to working product with minimal human
intervention.

**Core stack:** OMC (in-session orchestration) + clawhip (event routing) +
Claude Code (runtime, public API only).

**We do NOT use Claude Code internal APIs.** See ADR-001. All integration
through hooks, MCP, skills, CLAUDE.md, Agent tool, SendMessage, Tasks.

**We extend OMC, not rebuild it.** See ADR-002.

## Repository structure

- `docs/` — Roadmap, ADRs, research, specs
- `docs/SESSION.md` — Current session state for resuming across sessions
- `upstream/` — Git submodules (forks) of OMC and clawhip
- `reference/` — Git submodule of oh-my-openagent (study material only)
- `src/` — Our own code (when we build things)

## Key documents

- `docs/ROADMAP.md` — Start here. Vision, product workflow, work items.
- `docs/SESSION.md` — Where we left off. Read this when starting a new
  session.
- `docs/decisions/` — Architectural Decision Records (numbered).
- `docs/research/` — Ecosystem analysis, challenges, patterns.

## Working conventions

- **Everything is a draft.** See the draft-awareness skill. Nothing in the
  roadmap, decisions, or code is fixed. Always consider the big picture
  and be ready to refactor anything.
- **Persist discussion outcomes.** When a discussion produces decisions or
  insights, write them to the appropriate doc before moving on.
- **Update SESSION.md before ending.** Capture what was discussed, what was
  decided, what's next, and any needed context for the next session.
