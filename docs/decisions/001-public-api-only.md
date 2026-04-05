# ADR-001: Public API only

**Status:** Accepted  
**Date:** 2026-04-05

## Context

The Claude Code CLI source was extracted from a source map bundled with the
npm package. This source reveals internal APIs (coordinator mode, fork
subagents, permission bubble, programmatic hook callbacks) that are
feature-gated and not available to normal users.

Several of these internal primitives would enable more efficient orchestration
than what the public interface offers. However, building on them means:
- Depending on undocumented, unstable APIs that Anthropic can change at will
- Using feature-gated code that may never ship publicly
- Risk of the entire integration breaking on any Claude Code update
- If Anthropic ships these features first-party, our implementation becomes
  redundant overnight

## Decision

clawdance uses only Claude Code's public consumer interface:
- Hooks (shell commands configured in settings.json)
- MCP servers (configured in settings.json)
- Skills (markdown files in .claude/skills/)
- CLAUDE.md project instructions
- CLI flags (--print, --model, --allowedTools, --permission-mode, etc.)
- The Agent tool (with isolation: "worktree", run_in_background: true)
- SendMessage (continue previously spawned agents)
- Tasks (TaskCreate, TaskGet, TaskUpdate, TaskStop)
- Remote triggers / Cron

The extracted Claude Code source is used only as reference documentation to
understand the public extension surface. No code, types, or internal APIs
are imported or depended on.

## Consequences

- Integration is resilient to Claude Code internal changes
- We may need workarounds where internal APIs would be cleaner
- Shell command hooks have per-invocation process overhead (vs in-process
  callbacks)
- We cannot use coordinator mode for worker orchestration — must use the
  Agent tool + worktrees as the parallelism mechanism
- If Anthropic later makes internal APIs public, we can adopt them then
