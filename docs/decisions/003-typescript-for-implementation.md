# ADR-003: TypeScript for implementation

**Status:** Draft  
**Date:** 2026-04-05

## Context

We need to choose a language for any code we build (skills, hooks, MCP
servers, daemon). The main candidates are TypeScript and Rust.

Arguments evaluated:

**TypeScript:**
- Claude Code is TypeScript. Plugin system, hooks, skills, MCP — same
  ecosystem.
- Official MCP SDK exists for TypeScript (`@modelcontextprotocol/sdk`).
- OMC is TypeScript — easier interop for extending it.
- Node.js is already required by Claude Code — no new runtime dependency.
- Faster iteration during planning/prototyping phase.

**Rust:**
- clawhip is Rust — native integration if we build a daemon.
- Better for long-running daemon processes (memory, performance).
- Single binary distribution (`cargo install`).
- ratatui for TUI dashboard is best-in-class.
- Official MCP SDK exists for Rust (`rmcp`).

**Hybrid (TypeScript plugin + Rust daemon):**
- Best of both but doubles build complexity, CI, and creates serialization
  boundaries.

## Decision

Lean TypeScript. The highest-value work is Claude Code integration (hooks,
skills, MCP), where TypeScript has a clear advantage. Components where Rust
shines (event bus, policy engine, cost tracker) are small enough that
TypeScript handles them adequately.

If a Rust daemon becomes necessary later (TUI dashboard, performance-
critical event processing), it can be added without rewriting the plugin
layer.

## Consequences

- Single language, single build system, single CI pipeline
- Direct access to Claude Code's ecosystem and OMC's codebase
- Node.js runtime dependency (acceptable — Claude Code requires it)
- TUI dashboard would use ink/blessed instead of ratatui (less mature
  but functional)
- Can revisit if performance requirements emerge
