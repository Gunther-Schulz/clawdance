# Competitive Landscape

Research conducted 2026-04-05. Comprehensive search of GitHub, web, and
industry sources for projects that overlap with clawdance's niche:
cross-session orchestration for autonomous app development.

## Executive summary

The niche is crowded at the **within-session orchestration** layer but
nearly empty at the **cross-session constraint persistence** layer.

Dozens of projects solve parallel agents, tmux management, rate-limit
resume, and within-session task decomposition. A handful attempt
cross-session continuity. **Nobody explicitly solves the validated problem
of "cross-component constraints lost at session boundaries causing
integration bugs."**

The closest competitors are Gas Town (Beads + Hooks architecture),
Anthropic's own autonomous-coding quickstart (feature_list.json pattern),
and OmO's Sisyphus tasks (cross-session task tracking). Each addresses
parts of the problem but none combine structured decomposition, constraint
persistence, and session lifecycle management into a single orchestration
layer on top of OMC.

---

## Tier 1 — Direct competitors (cross-session orchestration on Claude Code)

### Gas Town (Steve Yegge)
- **URL:** https://github.com/steveyegge/gastown
- **Stars:** ~13.5K | **Commits:** ~6,900
- **What it does:** Multi-agent orchestration with 7 specialized roles
  (Mayor, Polecats, Refinery, Witness, Deacon, Dogs, Crew). Coordinates
  20-30 Claude Code instances on the same codebase. "Kubernetes for AI
  coding agents."
- **Cross-session state:** Yes — via "Hooks" (git worktree-based persistent
  storage that survives crashes and restarts) and "Beads" (git-backed issue
  tracking storing work state as structured data).
- **Task graph:** Yes — via "Molecules" (workflow templates) and "Formulas"
  (TOML dependency definitions). Two execution modes: root-only wisps
  (lightweight) and poured wisps (with checkpoint recovery).
- **Constraint persistence:** Implicit via Beads (work state) but NOT
  explicit cross-component constraint tracking. Beads track issues and
  work items, not "component A requires X in component B's config."
- **Session lifecycle:** Has Witness (health monitoring) and Deacon (patrol
  loops) but focused on agent health, not session-boundary continuity.
- **Assessment:** **Strongest competitor.** Addresses structured
  decomposition and cross-session state with a mature, opinionated
  architecture. However, it's a complete replacement for your orchestration
  stack, not a thin layer on top of OMC. Different philosophy: build
  everything vs. extend existing tools. Does not specifically target the
  constraint-persistence gap we validated.

### Anthropic's autonomous-coding quickstart
- **URL:** https://github.com/anthropics/claude-quickstarts/tree/main/autonomous-coding
- **What it does:** Official two-agent pattern for building complete apps
  over multiple sessions. Initializer agent creates feature_list.json with
  200+ test cases; coding agent picks up incomplete features and implements
  them sequentially.
- **Cross-session state:** Yes — feature_list.json (test case registry),
  claude-progress.txt (session notes), git commits.
- **Task graph:** Flat list, not a graph. Sequential feature implementation
  with no dependency tracking.
- **Constraint persistence:** No. Constraints are test cases, not
  cross-component invariants. No mechanism for "every MCP tool must be
  in the allowlist."
- **Session lifecycle:** Auto-continues between sessions with 3-second
  delay. Simple but functional.
- **Assessment:** **Inspiration, not threat.** Validates the pattern of
  on-disk state for cross-session continuity but uses a flat feature list,
  not structured decomposition. No constraint persistence. No parallel
  agents. A starting point, not a solution for complex multi-component apps.

### Aperant (AndyMik90/Auto-Claude)
- **URL:** https://github.com/AndyMik90/Aperant
- **Stars:** ~13.8K | **Commits:** ~1,100 | **Releases:** 37
- **What it does:** Electron desktop app for autonomous multi-agent coding.
  Kanban UI, up to 12 parallel terminals, AI-powered merge with conflict
  resolution. TypeScript + Vercel AI SDK v6.
- **Cross-session state:** Claims "Memory Layer — agents retain insights
  across sessions." Implementation details sparse.
- **Task graph:** Implicit via planning pipeline (spec creation → planner
  → coder → QA reviewer → QA fixer). No explicit dependency graph.
- **Constraint persistence:** Not documented.
- **Session lifecycle:** Desktop app manages session lifecycle directly.
- **Assessment:** **Adjacent, not competing.** Different architecture
  (Electron app, multi-provider) targeting a different audience (visual
  task management). Not a thin orchestration layer. Does not use OMC or
  Claude Code's agent infrastructure.

---

## Tier 2 — Within-session orchestration (handle parallel agents but not cross-session)

### oh-my-claudecode (OMC)
- **URL:** https://github.com/Yeachan-Heo/oh-my-claudecode
- **Stars:** ~24K
- **What it does:** The foundation we build on. 32 agents, 5 execution
  modes, team mode with parallel worktrees, ralph persistence mode,
  clawhip integration.
- **Cross-session:** Rate limit wait daemon (tmux auto-resume). No
  cross-session task state or constraint persistence.
- **Assessment:** Our upstream, not a competitor. clawdance adds what OMC
  lacks: cross-session continuity, structured decomposition, constraint
  persistence.

### claw-code (ultraworkers)
- **URL:** https://github.com/ultraworkers/claw-code
- **Stars:** ~164K
- **What it does:** Clean-room rewrite of Claude Code in Python/Rust.
  Multi-agent orchestration, autonomous coding loops, multi-layer memory
  system.
- **Cross-session state:** Claims "session persistence, transcript
  compaction, and context discovery." Uses persisted JSON session files
  and semantic search for memory.
- **Constraint persistence:** Not documented. Memory system is
  conversational (what was discussed), not structural (what constraints
  exist between components).
- **Assessment:** **Different layer entirely.** Claw-code replaces Claude
  Code itself. We build on top of Claude Code. Their autonomous workflow
  uses OmX/clawhip as development tools, similar to our stack, but their
  product is the agent harness, not the orchestration layer above it.

### Ruflo (ruvnet/claude-flow)
- **URL:** https://github.com/ruvnet/ruflo
- **Stars:** Moderate | **Agents:** 60+
- **What it does:** Enterprise agent orchestration with swarm intelligence,
  RAG integration, 215 MCP tools. Persistent memory via .swarm/memory.db.
- **Cross-session state:** Claims cross-session state management via
  memory.db (SQLite). Agent memory survives across sessions and compaction.
- **Constraint persistence:** Not specific. Memory is general-purpose, not
  structured around cross-component constraints.
- **Assessment:** **Over-engineered for a different problem.** 60+ agents,
  enterprise swarm architecture. Solves breadth (lots of agents doing lots
  of things), not depth (precise constraint tracking across sessions for
  a single build). Memory system is conversational/episodic, not
  structural.

### OpenClaw (Enderfga/openclaw-claude-code)
- **URL:** https://github.com/Enderfga/openclaw-claude-code
- **What it does:** Plugin turning Claude Code CLI into a headless coding
  engine. 27 tools, multi-engine support (Claude, Codex, Gemini, Cursor).
  Team tools for cross-session messaging.
- **Cross-session:** Team tools provide cross-session messaging as a
  "virtual team layer" for non-Claude engines.
- **Assessment:** **Plumbing, not orchestration.** Makes Claude Code
  programmable. Useful building block but doesn't provide task graphs,
  constraint persistence, or session lifecycle management.

---

## Tier 3 — Session lifecycle tools (handle rate limits / tmux, nothing more)

| Project | URL | What it does | Gap vs. clawdance |
|---|---|---|---|
| **autoclaude** | https://github.com/henryaj/autoclaude | TUI that monitors tmux panes, sends "continue" on rate limit reset | No task state, no constraints, just resume |
| **tmux-claude-resurrect** | https://github.com/mikedyan/tmux-claude-resurrect | Resumes Claude Code sessions after tmux restart | Session recovery only, no orchestration |
| **ralph-claude-code** | https://github.com/frankbria/ralph-claude-code | Autonomous dev loop with rate limit detection | Within-session loop, no cross-session state |
| **Codeman** | https://github.com/Ark0N/Codeman | WebUI managing 20 parallel tmux sessions with respawn | Session management and monitoring, no task decomposition or constraints |
| **claude-squad** | https://github.com/smtg-ai/claude-squad | TUI managing multiple AI terminal agents in isolated workspaces | Agent lifecycle manager, no cross-session state |

These tools solve the **bash session loop** piece of our architecture but
none of the structured decomposition, constraint persistence, or
cross-session task state.

---

## Tier 4 — Adjacent ecosystem (different agent runtimes)

### oh-my-codex / oh-my-openagent
- **OmX:** https://github.com/Yeachan-Heo/oh-my-codex — OMC equivalent
  for Codex CLI. Durable state under .omx/ (plans, logs, memory, mode
  tracking). Closest to cross-session continuity in the OMC family but
  still within-session focused.
- **OmO:** https://github.com/code-yeongyu/oh-my-openagent — Multi-agent
  for OpenCode. Sisyphus Tasks system enables cross-session task tracking
  with configurable storage path. **Most relevant adjacent project** —
  Sisyphus explicitly handles cross-session task resumption.

### Cursor 3 (Background Agents)
- **URL:** https://cursor.com/product
- **What it does:** Cloud VMs running autonomous background agents. Push
  changes as PRs. Multi-repo workspace. Handoff between local and cloud.
- **Cross-session:** Cloud-native — sessions persist on Cursor's
  infrastructure. No user-visible task graph or constraint system.
- **Assessment:** Commercial competitor at a different level. Solves
  session persistence by owning the infrastructure. Doesn't solve
  constraint persistence — just keeps sessions alive longer.

### Devin (Cognition)
- **URL:** https://devin.ai
- **What it does:** Most autonomous commercial coding agent. Takes task
  descriptions, autonomously researches/plans/codes/tests/iterates.
  Pricing dropped to $20/month + per-ACU in 2026.
- **Cross-session:** Proprietary. Likely has internal state management
  but nothing user-visible or customizable.
- **Assessment:** Different market (managed service vs. tool you control).
  Doesn't expose orchestration primitives. Can't extend or customize.

### Factory AI
- **URL:** https://factory.ai
- **What it does:** Enterprise autonomous coding with "Droids." End-to-end
  SDLC automation. "Enterprise memory" spanning GitHub, Notion, Linear,
  Slack, Sentry.
- **Cross-session:** Persistent enterprise memory across all agent
  interactions.
- **Assessment:** Enterprise SaaS. Different market entirely. Not
  extensible. Not built on Claude Code.

### OpenHands / SWE-agent
- **OpenHands:** https://github.com/All-Hands-AI/OpenHands — Open-source
  autonomous coding platform. Multi-agent, web UI. Best gpt-5 resolves
  only 21% of SWE-EVO tasks.
- **SWE-agent:** https://github.com/SWE-agent/SWE-agent — Research-focused.
  Takes GitHub issues, tries to fix them.
- **Assessment:** Research/benchmark-oriented. Solve single issues, not
  multi-session app builds. No cross-session task graph or constraint
  persistence.

---

## Tier 5 — Frameworks and patterns (not tools, but relevant architectures)

### Anthropic's long-running agent patterns
- **URL:** https://www.anthropic.com/engineering/effective-harnesses-for-long-running-agents
- **Pattern:** Initializer agent + coding agent. Progress files
  (claude-progress.txt), feature lists (feature_list.json), git commits
  as persistence. Agents read artifacts at session start.
- **Assessment:** **Validates our approach.** Anthropic's own recommendation
  is "write state to files, read at session start." But their pattern is
  flat (feature list), not structured (task graph with dependencies and
  cross-component constraints).

### Claude Code Tasks (January 2026)
- **What it does:** Built-in file-based persistence with dependency
  tracking, cross-session coordination, and broadcasting. Upgrade from
  the old Todos system.
- **Assessment:** Anthropic is moving toward cross-session task management
  natively. Could eventually subsume parts of our task graph. Worth
  watching as potential upstream capability.

### LangGraph
- **What it does:** Graph-based agent orchestration with built-in
  checkpointing, cross-thread memory, durable state. Industry standard
  for stateful agent workflows.
- **Assessment:** Different ecosystem (Python, API-based agents). Solves
  similar architectural problems (state persistence, checkpointing) but
  for general-purpose agents, not coding-specific. Architectural
  inspiration.

### CONTINUITY (MCP server)
- **URL:** https://github.com/duke-of-beans/CONTINUITY
- **Stars:** 0 | **Commits:** 7
- **What it does:** MCP server for session state persistence. Save/load
  session, checkpoint system, decision registry.
- **Assessment:** Right idea, wrong execution layer. MCP tool for generic
  session state, not structured for coding workflows. Essentially a
  key-value store with session semantics. Very early stage (0 stars).

---

## The specific gap we fill

Searched extensively for any project that explicitly addresses:
**"cross-component constraints lost at session boundaries cause integration
bugs."**

**Nobody frames the problem this way.** The closest framings found:

1. **"Context rot"** — widely discussed. Focus is on within-session
   attention degradation, not cross-session constraint loss. Solutions
   proposed: memory systems, embedding retrieval, structured extraction.
   None target structural constraints.

2. **"Session persistence"** — many projects address this. Focus is on
   resuming conversation context, not preserving operational invariants.
   Solutions: progress files, conversation replay, semantic memory.

3. **"Integration bugs in multi-agent systems"** — recognized problem.
   36.9% of multi-agent failures attributed to inter-agent misalignment.
   Solutions proposed: schema validation (MCP), structured communication.
   Nobody connects this to session boundaries.

4. **Anthropic's own pattern** — the closest. "Leave artifacts for the
   next session." But their artifacts are feature checklists, not
   constraint registries. They solve "what to work on next" but not
   "what invariants must be maintained."

### What's validated but unaddressed

Our real-world validation found that 2 of 5 integration bugs in a
multi-session build were caused by cross-component constraints not persisted
to files. The information was in the codebase but the next session didn't
know to look for it. This specific failure mode — **session boundary as a
constraint-loss boundary** — has no dedicated solution in the ecosystem.

The industry sees session boundaries as a **velocity** problem (losing
progress, re-reading context). We see them as a **correctness** problem
(losing invariants that prevent integration bugs). This framing difference
is our primary differentiation.

---

## Competitive positioning

| Capability | clawdance | Gas Town | Anthropic quickstart | Aperant | OMC | Cursor 3 | Devin |
|---|---|---|---|---|---|---|---|
| Cross-session task state | Planned | Yes (Beads) | Yes (flat list) | Partial | No | Cloud-native | Proprietary |
| Task graph with dependencies | Planned | Yes (Molecules) | No | No | No | No | Unknown |
| Cross-component constraint persistence | Planned | No | No | No | No | No | Unknown |
| Session lifecycle loop | Planned | Yes (Witness) | Yes (auto-continue) | Desktop app | Rate limit wait | Cloud-native | Managed |
| Parallel agents | Via OMC | Native (Polecats) | No | Yes (12 terminals) | Yes (team mode) | Yes (background) | Yes |
| Structured decomposition | Planned | Yes (Formulas) | No | Pipeline only | Yes (ralplan) | No | Unknown |
| Extends existing tools | Yes (OMC+clawhip) | No (standalone) | Standalone | Standalone | Is the tool | Is the tool | Is the tool |
| Open source | Yes | Yes | Yes | Yes (AGPL) | Yes | No | No |

---

## Threats and opportunities

### Threats
1. **Gas Town** is the most architecturally similar. If Yegge adds explicit
   constraint persistence, the differentiation narrows significantly.
   However, Gas Town is a complete standalone system (7 roles, Beads, etc.)
   — fundamentally different philosophy from "thin layer on OMC."
2. **Claude Code Tasks** (native feature) could evolve to include
   dependency tracking and cross-session constraint management. If
   Anthropic builds this natively, the need for external orchestration
   shrinks.
3. **Cursor 3 background agents** eliminate session boundaries entirely
   by keeping agents alive in cloud VMs. If this model wins, the
   session-boundary problem becomes irrelevant (for Cursor users).

### Opportunities
1. **Nobody frames constraint persistence as the core problem.** The entire
   ecosystem focuses on velocity (resume faster) and memory (remember
   conversations). The correctness angle (prevent integration bugs) is
   unoccupied.
2. **OMC is the de facto Claude Code orchestrator.** Building on it gives
   us the largest installed base to target.
3. **Anthropic's own patterns validate our approach** (on-disk state, read
   at session start) but their implementation is minimal (flat feature
   lists). Room to build something much more structured.
4. **The session lifecycle tooling exists** (autoclaude, Codeman, etc.) —
   we don't need to build the tmux/restart layer from scratch, just
   integrate with it.

---

## Sources

- [claw-code](https://github.com/ultraworkers/claw-code)
- [claw-code website](https://claw-code.codes/)
- [Gas Town](https://github.com/steveyegge/gastown)
- [Gas Town: Kubernetes for AI coding agents](https://cloudnativenow.com/features/gas-town-what-kubernetes-for-ai-coding-agents-actually-looks-like/)
- [oh-my-claudecode](https://github.com/Yeachan-Heo/oh-my-claudecode)
- [oh-my-codex](https://github.com/Yeachan-Heo/oh-my-codex)
- [oh-my-openagent](https://github.com/code-yeongyu/oh-my-openagent)
- [clawhip](https://github.com/Yeachan-Heo/clawhip)
- [Aperant](https://github.com/AndyMik90/Aperant)
- [Ruflo](https://github.com/ruvnet/ruflo)
- [OpenClaw](https://github.com/Enderfga/openclaw-claude-code)
- [autoclaude](https://github.com/henryaj/autoclaude)
- [Codeman](https://github.com/Ark0N/Codeman)
- [claude-squad](https://github.com/smtg-ai/claude-squad)
- [tmux-claude-resurrect](https://github.com/mikedyan/tmux-claude-resurrect)
- [ralph-claude-code](https://github.com/frankbria/ralph-claude-code)
- [CONTINUITY](https://github.com/duke-of-beans/CONTINUITY)
- [Anthropic autonomous-coding quickstart](https://github.com/anthropics/claude-quickstarts/tree/main/autonomous-coding)
- [Anthropic long-running agent patterns](https://www.anthropic.com/engineering/effective-harnesses-for-long-running-agents)
- [Persistent memory for AI coding agents (Medium)](https://medium.com/@sourabh.node/persistent-memory-for-ai-coding-agents-an-engineering-blueprint-for-cross-session-continuity-999136960877)
- [Devin alternatives compared](https://agentfounder.ai/blog/best-devin-alternative-2026)
- [Factory AI](https://factory.ai)
- [OpenHands](https://github.com/All-Hands-AI/OpenHands)
- [SWE-agent](https://github.com/SWE-agent/SWE-agent)
- [Claude Agent SDK overview](https://platform.claude.com/docs/en/agent-sdk/overview)
- [Cursor 3](https://cursor.com/blog/cursor-3)
- [Context rot in AI coding agents](https://www.techaheadcorp.com/blog/context-rot-problem/)
- [Multi-agent orchestration failure playbook](https://cogentinfo.com/resources/when-ai-agents-collide-multi-agent-orchestration-failure-playbook-for-2026)
- [AI coding agents: Coherence through orchestration](https://mikemason.ca/writing/ai-coding-agents-jan-2026/)
