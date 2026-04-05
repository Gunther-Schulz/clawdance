# ADR-003: Language choices for implementation

**Status:** Superseded (was: TypeScript for implementation)
**Date:** 2026-04-05
**Superseded:** 2026-04-05, after architecture simplification

## Original context

The original decision assumed we'd build a TypeScript daemon for session
lifecycle management, with hooks, skills, and MCP servers. TypeScript was
chosen for Claude Code ecosystem alignment.

## What changed

Investigation of OMC, Claude Code CLI, and clawhip revealed that the
architecture is much simpler than assumed:
- The "daemon" is a ~40-line bash script (session loop)
- Skills are SKILL.md prompt templates (markdown, not code)
- State is YAML files (no code)
- The only real code is a Telegram sink for clawhip (Rust)

There is no TypeScript in the architecture. See ADR-005 and the
[automation-flow spec](../specs/automation-flow.md).

## Revised decision

No single implementation language. Each component uses the simplest
appropriate tool:

| Component | Language | Why |
|---|---|---|
| Schemas (constraints, state, task graph) | YAML | File conventions, no code |
| Skills (session, decomposer, build) | Markdown (SKILL.md) | Prompt templates, Claude Code plugin pattern |
| Session loop | Bash | ~40 lines, spawns tmux, polls, loops |
| Telegram sink | Rust | Extends clawhip (Rust codebase), follows existing sink pattern |
| Plugin manifest | JSON | Standard Claude Code plugin format |

## Consequences

- No build system, no CI pipeline for the core (it's text files)
- Rust knowledge needed only for the Telegram sink (one module in clawhip)
- No Node.js runtime dependency beyond what Claude Code already requires
- If future components need real code (policy engine, cost tracker), the
  language choice is made per-component based on what it integrates with
