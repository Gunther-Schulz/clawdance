# ADR-004: Build our own cost tracking, don't depend on ccusage

**Status:** Draft  
**Date:** 2026-04-05

## Context

ccusage (ryoppippi/ccusage, 12K stars) is the popular cost tracking tool
for Claude Code. It reads Claude Code's JSONL session files and reports
token usage and costs. It has an MCP server variant (@ccusage/mcp).

We evaluated it as a dependency for clawdance's cost tracking needs.

**What ccusage provides:**
- Reads ~/.claude/projects/ JSONL files for token counts and costs
- Per-session, per-project, per-model cost breakdown
- CLI + MCP server interface
- Multi-backend: Claude, Codex, OpenCode, pi-agent, Amp

**What ccusage lacks for our needs:**
- No per-agent or per-task cost attribution
- No budget enforcement (reporting only, read-only)
- No real-time tracking (reads files after the fact)
- No library API (CLI-only, must shell out or use MCP)
- Cannot feed cost data into routing decisions

## Decision

Build our own cost tracking reader. Read the same JSONL session files
(proven, stable format) but add:
- Per-agent and per-task cost attribution via our own metadata
- Real-time cost updates via PostToolUse hooks
- Budget enforcement (recommend/block based on thresholds)
- Feed cost data into routing decisions

ccusage validated the approach of reading Claude Code's JSONL files. We
adopt the same data source but build the features ccusage doesn't have.

## Consequences

- We own the cost tracking implementation (maintenance burden)
- We can attribute costs at any granularity we need
- We can enforce budgets in real-time, not just report
- Cost data can drive routing decisions
- If ccusage changes its data source approach and we learn from it, we
  can adapt
