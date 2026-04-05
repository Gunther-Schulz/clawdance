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

- `plugin/` — **The product.** Claude Code plugin that users install.
  Everything here must be clean and self-contained. No references to
  `docs/` or `upstream/`.
- `docs/` — **Development reference only.** Roadmap, ADRs, research, specs,
  implementation plans. Not part of the shipped product. Lives here for
  our use during development.
- `upstream/` — **Dev workspace.** Git submodules (forks) of OMC and
  clawhip. For studying source and adding features (e.g., Telegram sink
  in clawhip). Not imported by the product — users install OMC and clawhip
  separately.
- `reference/` — Git submodule of oh-my-openagent (study material only).
- `docs/SESSION.md` — Current session state for resuming across sessions.

### Product vs development

| Directory | Ships to users? | Purpose |
|---|---|---|
| `plugin/` | Yes | The Claude Code plugin |
| `docs/` | No | Our research, specs, plans |
| `upstream/` | No | Forks for studying and extending deps |
| `reference/` | No | Study material |
| `update-plugin.sh` | No | Local dev testing |

### User dependencies (installed separately, not bundled)

- **Claude Code** — the runtime
- **OMC** (oh-my-claudecode) — in-session orchestration. Prerequisite plugin.
- **clawhip** — event routing + notifications. Optional. Our fork adds
  Telegram support (upstream/clawhip/ is where we develop this).

## Key documents

- `docs/ROADMAP.md` — Start here. Vision, product workflow, work items.
- `docs/SESSION.md` — Where we left off. Read this when starting a new
  session.
- `docs/specs/automation-flow.md` — Core automation flow spec.
- `docs/specs/implementation-plan-A.md` — Implementation plan for item A.
- `docs/decisions/` — Architectural Decision Records (numbered).
- `docs/research/` — Ecosystem analysis, challenges, patterns.

## Working conventions

- **Everything is a draft.** Nothing in the roadmap, decisions, or code is
  fixed. Always consider the big picture and be ready to refactor anything.
- **Persist discussion outcomes.** When a discussion produces decisions or
  insights, write them to the appropriate doc before moving on.
- **Update SESSION.md before ending.** Capture what was discussed, what was
  decided, what's next, and any needed context for the next session.
- **Self-resolve from context.** Derive answers from existing patterns
  (bildhauer/clippy plugins, codebase conventions) rather than asking.
  Present recommendations, not questions.
- **Product code in plugin/ only.** Nothing in plugin/ should reference
  docs/ or upstream/. The plugin is self-contained.
