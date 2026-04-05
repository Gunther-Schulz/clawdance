# Challenges for Autonomous App Development

Research conducted 2026-04-05. Based on analysis of OMC's architecture,
Claude Code's session model, and known constraints.

## Goal

Give a high-level app idea to the system and have it built as autonomously
as possible. The stack is OMC (in-session orchestration) + clawhip (event
routing) running on Claude Code.

## Near-certain challenges

These will happen. Not a question of if, but when.

### Rate limits will interrupt work mid-task

Claude Code has 5-hour usage caps on API plans. A complex build (autopilot
with team mode, multiple opus agents, reviews) burns tokens fast. You will
hit the cap mid-build.

When the cap resets, you need a new session. That new session doesn't know
what the previous one was doing, what's done, what's half-done, or what
failed.

### Compaction will lose design decisions

OMC's autopilot goes through 5 phases. By phase 3 (execution), the detailed
reasoning from phase 1 (expansion) and phase 2 (planning) will likely be
compacted. The agent makes implementation choices that contradict design
decisions it no longer remembers.

Especially bad for cross-component consistency — "the API returns paginated
results" gets compacted, so the frontend agent builds assuming it gets
everything at once.

### Parallel agents will make conflicting assumptions

Team mode spawns agents in separate worktrees. Agent A builds the API
endpoint returning `{ items: [...] }`. Agent B builds the frontend expecting
`{ data: [...], pagination: {...} }`. Neither is wrong — they just didn't
coordinate on the contract.

OMC's merge coordinator catches file conflicts but not semantic conflicts.
This is the single biggest risk for parallel autonomous development.

### Agent role context gets diluted after compaction

OMC's 19 agents get their role prompts from agent definitions. But
task-specific context — "we're building auth using JWT with refresh tokens
stored in httpOnly cookies" — lives in the conversation. After compaction,
a newly spawned executor agent gets its role prompt but not the
project-specific constraints. It makes reasonable but wrong choices.

### Tests will be insufficient for integration

Each agent tests its own work in its own worktree. Agent A's API tests pass.
Agent B's frontend tests pass with mocked API responses. Merge them and the
app is broken because the mock doesn't match the real API. Nobody ran
end-to-end tests against the integrated codebase.

### Session boundaries cause integration bugs (not just velocity loss)

Whether it's a rate limit, a crash, or closing your laptop — the next
session starts cold. Even with `.omc/` state and project memory, the agent
spends the first 10-15 minutes re-reading files and rebuilding context that
the previous session already had.

But velocity loss is the minor problem. The major problem is **correctness**.
When a session establishes a cross-component constraint (e.g., "every new
MCP tool must be added to the allowlist in config.go"), that constraint
dies at the session boundary. The next session doesn't know about it,
builds something that violates it, and the bug is only caught when
integration tests run — if they exist.

This was validated in a real multi-session build where 2 of 5 bugs were
caused by cross-component constraints that weren't persisted to files.
See [real-world validation](real-world-validation.md).

## Likely challenges

These will probably happen depending on project size and complexity.

### Scope creep within autopilot

You say "build a task management app." Autopilot's expansion phase produces
a comprehensive spec — user roles, permissions, notifications, real-time
updates, file attachments — because that's what a "complete" app has. Now
you're building something 5x larger than intended.

### OMC's recovery loops consume budget

Ralph retries up to 100 times. If an agent is stuck on a wrong approach,
it burns tokens trying variations of the same broken thing before the
circuit breaker kicks in. 100 retries at opus-level reasoning is expensive.

### Tech stack mismatches

Halfway through, an agent chooses an ORM or state management library you
didn't want. Other components now depend on it. This happened during a
phase that got compacted, so the reasoning is gone and reverting is costly.

## Mitigations

The pattern: almost every mitigation is "write it to a file on disk so it
survives compaction and session boundaries." The conversation is ephemeral.
Files are permanent.

| Challenge | Mitigation |
|---|---|
| Rate limit interruption | Checkpoint file written before each major phase — the next session reads it to resume |
| Compaction losing decisions | Write design decisions to DESIGN.md on disk early. Agents read files instead of relying on conversation context |
| Semantic conflicts between parallel agents | Define contracts (API schemas, data models) as actual files BEFORE spawning parallel workers. Agents read the contract file |
| Agent context dilution | Project-specific constraints go in CLAUDE.md or a constraints file, not just conversation |
| Integration test gap | Integration tests written per-connection during implementation, plus full-stack test after merge. Not deferred to a separate phase |
| Scope creep | Constrain the initial prompt with explicit MVP scope. Write scope document to disk for agents to reference |
| Recovery token burn | Lower retry limits, enforce "if same error 2x, stop and write a blocker report" |
| Tech stack drift | STACK.md or project config that agents check before introducing dependencies |
| Session boundary correctness | Persist cross-component constraints to files (not just design decisions — also operational invariants like "tool X requires allowlist entry in file Y"). Structured checkpoints for resumption |

## Key insight

The core intervention may not be a daemon or new orchestration tool. It may
be a structured set of project files and skills that ensure critical context
is always on disk — surviving compaction, session boundaries, and rate limit
interruptions.

This aligns with the principles from Bildhauer (externalize reasoning into
artifacts) and Clippy (evidence must be traceable, not just remembered).
These principles should be built into the development process itself, not
bolted on as external tools. See [real-world validation](real-world-validation.md)
for concrete evidence of which principles catch which bug categories.
