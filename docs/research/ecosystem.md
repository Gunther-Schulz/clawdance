# Ecosystem Research

Research conducted 2026-04-05. Repos cloned and analyzed locally.

## The claw-code autonomous development flow

The claw-code project (ultraworkers/claw-code, 168K stars) demonstrates
autonomous software development using three coordination tools:

1. **OmX (oh-my-codex)** — Workflow orchestration for Codex CLI. Turns
   directives into structured execution plans with planning, execution,
   and verification loops.
2. **clawhip** — Event-to-channel notification router. Watches git, tmux,
   GitHub, and agent lifecycle events. Routes to Discord/Slack. Keeps
   monitoring outside agent context windows.
3. **OmO (oh-my-openagent)** — Multi-agent coordination for OpenCode. 11
   named agents with role specialization, planning, handoffs, and
   disagreement resolution.

The human interface is Discord — humans give direction, agents execute.

## oh-my-claudecode (OMC)

**Repo:** Yeachan-Heo/oh-my-claudecode (24K stars)  
**What it is:** Claude Code equivalent of oh-my-codex. Multi-agent
orchestration as a Claude Code plugin.

**Key capabilities:**
- 19 specialized agents in 4 lanes (build, review, domain, coordination)
- 32 executable skills (autopilot, ralph, ralplan, team, etc.)
- 20 lifecycle hooks across 11 Claude Code event types
- MCP tools for state management and code intelligence
- Team mode: parallel agents in git worktrees with merge coordination
- Multi-backend: can spawn Codex and Gemini CLI workers via tmux
- Smart model routing: haiku/sonnet/opus based on task complexity
- clawhip integration for notifications

**Hooks used (11 of 24 available):** UserPromptSubmit, SessionStart,
PreToolUse, PermissionRequest, PostToolUse, PostToolUseFailure,
SubagentStart, SubagentStop, PreCompact, Stop, SessionEnd.

**Hooks NOT used (13):** PermissionDenied, StopFailure, TaskCreated,
TaskCompleted, TeammateIdle, Elicitation, ElicitationResult, ConfigChange,
CwdChanged, FileChanged, WorktreeCreate, WorktreeRemove, InstructionsLoaded,
Notification.

**Autonomous flow coverage:**
- Directive → task decomposition: Full (ralplan, autopilot, team-plan)
- Parallel agents: Full (team spawns N parallel teammates in worktrees)
- Architect → Executor → Reviewer: Full (5-stage pipeline)
- Recovery within session: Substantial (stop hook, watchdog, circuit breakers)
- Event routing: Full (clawhip integration)

**Gaps:**
- No cross-session orchestration (no backlog dispatcher)
- No closed-loop session recovery (clawhip notifies but doesn't restart)
- No configurable policy engine (logic hardcoded in prompts/hooks)

## clawhip

**Repo:** Yeachan-Heo/clawhip (479 stars)  
**What it is:** Rust daemon for event-to-channel notification routing.

**Key capabilities:**
- Daemon on 127.0.0.1:25294
- Event sources: GitHub, git, tmux, OMC/OMX hooks, custom CLI
- Delivery sinks: Discord (bot + webhook), Slack (webhook)
- Route filtering, batching, dynamic tokens, mention policies
- Native OMC integration (session lifecycle hooks)
- ~13K lines of Rust, v0.5.4, production-ready

**Role:** Monitoring and notification layer. Observes agent sessions
externally, routes events to Discord/Slack. Does NOT make decisions or
spawn sessions — it's plumbing, not a brain.

## oh-my-openagent (OmO)

**Repo:** code-yeongyu/oh-my-openagent (48K stars)  
**What it is:** Multi-model orchestration harness for OpenCode. ~214K LOC
TypeScript.

**Key capabilities:**
- 11 named agents (Sisyphus, Hephaestus, Prometheus, etc.)
- Category-based delegation (not model-specific — you say "ultrabrain",
  it picks the right model)
- Multi-model fallback chains (Claude, GPT, Gemini, Kimi, GLM, MiniMax)
- Background agent framework with circuit breakers and concurrency limits
- 52 lifecycle hooks across 5 tiers
- Claude Code plugin/hook/MCP loaders (production code, not stubs)

**Relevance:** Reference for multi-model routing and agent coordination
patterns. Runs on OpenCode, not Claude Code directly. In reference/ not
upstream/.

## Broader landscape

Searched for existing multi-backend orchestration tools. Key finding:
**no project provides automated cost/capability/policy-based routing
across multiple coding agent CLIs.** The landscape has:
- Multi-backend multiplexers (dmux, LeapMux) — human picks the agent
- Cross-model bridges (claude-codex-bridge) — hardcoded role assignments
- Orchestration frameworks (OMC, OMX, OmO) — within-backend coordination
- Unified workspaces (CC Switch, AionUi) — launchers, not routers
