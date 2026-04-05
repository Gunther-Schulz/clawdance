# ADR-002: Extend OMC, don't rebuild orchestration from scratch

**Status:** Accepted  
**Date:** 2026-04-05

## Context

oh-my-claudecode (OMC) provides ~85% of the autonomous development flow we
want for Claude Code:
- Task decomposition with dependency graphs
- 19 specialized agents with role separation
- True parallel execution in git worktrees
- Structured pipeline (plan → prd → exec → verify → fix)
- Automatic retry/recovery within sessions
- clawhip integration for event routing

OMC deeply integrates with Claude Code's public ecosystem (20 hooks, 32
skills, MCP tools, plugin manifest, Agent tool, SendMessage, worktrees).

Building equivalent orchestration from scratch would take months and produce
something less mature than what OMC already offers.

## Decision

We extend OMC rather than building competing orchestration. Our contributions
focus on the gaps OMC doesn't cover:
- Cross-session orchestration (work backlogs, session dispatching, recovery)
- Quality standard integration (Bildhauer/Clippy discipline)
- Challenges mitigation (design persistence, contract coordination, etc.)

Our forks of OMC and clawhip live as git submodules in upstream/. Feature
branches and PRs go to the upstream repos.

## Consequences

- We ship faster by building on proven infrastructure
- We depend on OMC's maintenance and direction
- Our contributions must align with OMC's architecture and conventions
- If OMC's maintainer rejects our PRs, we maintain our fork
- We focus our effort on the genuinely unsolved problems
