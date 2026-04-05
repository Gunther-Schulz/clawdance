# Gas Town Deep Analysis

Research conducted 2026-04-05. Deep architectural analysis of Gas Town
(steveyegge/gastown) — what it does, how it compares to our OMC-based
approach, and what we should learn from it.

Source: cloned to ~/dev/reference/gastown (6,908 commits, Go, 13.5K stars).

## What Gas Town is

A **workspace manager for AI agent fleets.** Coordinates 20-30 agents
across multiple repositories with persistent work tracking. "Kubernetes
for AI coding agents."

Written in Go. Requires Dolt (git for data), Beads CLI, SQLite, tmux.
Supports Claude Code, Codex, Copilot, Gemini, OpenCode as agent runtimes.

## Architecture

### Role taxonomy

**Infrastructure roles** (manage the system):

| Role | What it does | Lifecycle |
|---|---|---|
| Mayor | Global coordinator. Assigns work, cross-rig communication. | Singleton, persistent |
| Deacon | Background supervisor. Patrol cycles across all rigs. | Singleton, persistent |
| Witness | Per-rig lifecycle manager. Monitors polecats, detects stuck agents, triggers recovery. | One per rig, persistent |
| Refinery | Per-rig merge queue. Bors-style bisecting merge with verification gates. | One per rig, persistent |
| Dogs | Deacon helpers for infrastructure tasks (e.g., Boot for triage). | Ephemeral |

**Worker roles** (do project work):

| Role | What it does | Lifecycle |
|---|---|---|
| Polecats | Workers with persistent identity, ephemeral sessions. Witness-managed. | Persistent identity, ephemeral sessions |
| Crew | Human workspaces with full git clones. User-managed. | Persistent |

### Key concepts

- **Town** — workspace directory (`~/gt/`). Contains all projects.
- **Rigs** — per-repo containers. Each wraps a git repo + its agents.
- **Beads** — git-backed issue tracking. Work state as structured data
  with dependencies. Separate tool (`bd`). Uses Dolt for storage.
- **Convoys** — batched work tracking. Groups of beads assigned to agents.
- **Formulas** — TOML workflow templates defining multi-step processes.
- **Molecules** — instantiated formulas. Two modes:
  - Root-only wisps (lightweight, steps read inline)
  - Poured wisps (steps materialized as sub-wisps with checkpoint recovery)
- **Hooks** — git worktree-based persistent storage (not Claude Code hooks).
- **Seance** — session discovery. Query previous agent sessions for context.
- **Wasteland** — federated work coordination across Gas Towns via DoltHub.

### Operational modes

Gas Town scales from minimal to full fleet:

| Configuration | What's active | Use case |
|---|---|---|
| Polecats only | Manual spawning, Beads tracking | Testing, simple workflows |
| + Witness | Automatic lifecycle, stuck detection | Supervised automation |
| + Refinery | Merge queue with verification gates | Code integration |
| + Mayor | Cross-project coordination | Multi-rig orchestration |
| + Daemon | Full automatic lifecycle | Production fleet management |

Minimal mode: no daemon, run claude manually, Gas Town just tracks state.

## OMC vs Gas Town: what each uniquely provides

They don't overlap. They're different layers.

### OMC: in-session execution quality

OMC operates INSIDE the Claude Code context window. It changes how the
agent thinks and codes.

- **Role-separated review:** 19 agents reviewing from different angles.
  Executor can't approve own code. Code-reviewer, security-reviewer,
  verifier each have distinct concerns.
- **Smart retries:** Ralph retries with full context of WHY it failed.
  Same session, sees the error, understands the approach that didn't work.
- **Model routing:** Haiku for simple tasks, sonnet for standard, opus
  for architecture — within a single task.
- **Behavioral enforcement:** Orchestrator hook prevents coordinators from
  writing code directly. Forces delegation to executor agents.
- **Anti-slop cleanup:** 4-pass cleaner for AI-generated boilerplate.
- **Parallel subtasks:** Team mode spawns N executors for subtasks of one
  unit, with merge coordination.
- **Structured commits:** Trailers capture constraints, rejected
  alternatives, scope risk in git history.
- **Verification protocol:** "Zero pending tasks, tests passing, verifier
  evidence collected" before claiming completion.

### Gas Town: cross-session lifecycle management

Gas Town operates OUTSIDE sessions. It manages which agent works on what
and keeps agents alive.

- **Persistent identity:** Polecats survive session death. Identity,
  work history, and state persist across sessions.
- **Session lifecycle:** Daemon + Witness + Deacon. Automatic restart,
  stuck detection, patrol cycles.
- **Work tracking:** Beads (structured issues with dependencies) +
  Convoys (batched tracking across agents).
- **Checkpoint recovery:** Poured wisps resume from last completed step.
- **Merge queue:** Refinery does Bors-style bisecting merge with
  verification gates.
- **Session discovery:** Seance queries previous sessions for decisions.
- **Multi-runtime:** Same workflow with Claude, Codex, Copilot, Gemini.
- **Rate limit management:** Scheduler governs dispatch to avoid API
  exhaustion.
- **Inter-agent messaging:** Mail, nudge, escalation protocols.

### Neither provides

- **Cross-component constraint persistence.** Beads track what to do, not
  what invariants to maintain. OMC's state dies with the session.
- **Design-artifact-driven decomposition.** Neither takes design documents
  and produces a structured task graph for autonomous implementation.

## What we should learn from Gas Town

### 1. Persistent agent identity is powerful

Gas Town's polecats have identity that survives session death. When a new
session starts, the polecat knows who it is, what it's worked on before,
and what its current assignment is.

Our equivalent: checkpoints with enough context that the next session can
pick up where the last left off. Not identity per se, but the same effect
— work continuity across sessions.

### 2. The write-then-notify pattern

Gas Town's inter-agent messaging writes the message to a file first, then
sends a tmux trigger. If the trigger fails, the message is still in the
file. OMC uses the same pattern for team worker communication.

Our equivalent: state files on disk (YAML) are the source of truth. The
session loop just triggers sessions — if it fails, the state is still on
disk for manual or automatic resume.

### 3. Checkpoint recovery via poured wisps

When a poured workflow is interrupted, completed steps remain closed and
work resumes from the last checkpoint. Each step is a separate tracked
entity.

Our equivalent: per-unit checkpoints. When a session dies, the next
session reads checkpoints and picks up the next incomplete unit.

Lesson: Gas Town's granularity is per-step within a formula. Our
granularity is per-unit in the task graph. If a unit is too large to
complete in one session, we retry the whole unit. Gas Town would retry
from the last completed step within the unit. Consider adding sub-unit
checkpointing if units prove too large in practice.

### 4. Bors-style merge queue (Refinery)

Gas Town's Refinery batches merge requests, runs verification gates, and
uses bisecting to isolate failures. If an MR breaks the build, it's
automatically identified and either fixed inline or re-dispatched.

Our equivalent: OMC's team merge coordinator, which is simpler (merge and
check for file conflicts). Consider adopting a more sophisticated merge
strategy if parallel units produce frequent integration failures.

### 5. Session discovery (Seance)

Seance discovers previous agent sessions via `.events.jsonl` logs, enabling
agents to query their predecessors for context and decisions.

We have nothing equivalent. Our checkpoints capture what was done but not
the reasoning behind decisions. Consider adding a decision log to
checkpoints — not just "unit-001 completed" but "chose approach X because
of Y, rejected approach Z because of W."

This is actually related to OMC's commit protocol (structured trailers:
Constraint, Rejected, Directive, Confidence). If agents use OMC's commit
protocol, decision context is captured in git history. That may be
sufficient — `git log` becomes our seance.

### 6. Structural enforcement of delegation

Gas Town's Witness-AT design (future, not yet implemented) uses Claude
Code's delegate mode — structural enforcement that the Witness can only
coordinate, not code. This prevents role confusion.

OMC has the same pattern: orchestrator hook prevents coordinators from
writing code outside `.omc/` and `.claude/`. Structural, not advisory.

Lesson: behavioral enforcement via hooks is more reliable than prompt
instructions. Both Gas Town and OMC learned this independently.

### 7. Formula-driven workflows

Gas Town's Formulas (TOML templates) define repeatable multi-step
processes. Agents see a checklist via `gt prime` and work through it.

Our equivalent: the session skill (SKILL.md) defines the workflow. But
our workflow is one-size-fits-all (read state, pick unit, execute, 
checkpoint). Gas Town's formulas are customizable per task type.

Consider: our session skill could support different "modes" for different
unit types (e.g., "backend service" formula vs "frontend component" formula
vs "database migration" formula). Not needed for MVP but a natural
extension.

### 8. Rate-limit-aware scheduling

Gas Town's Scheduler governs polecat dispatch under configurable
concurrency limits. Prevents API rate limit exhaustion by batching.

Our session loop has no rate limit awareness. It just spawns sessions
and backs off on consecutive failures. Consider adding a delay between
session spawns based on API usage signals.

## Why we chose our thin layer over Gas Town

See ADR-005. Summary: Gas Town's cost/benefit ratio is wrong for a
single-project autonomous build. The dependency weight (Go + Dolt + Beads
+ SQLite), conceptual overhead (~15 concepts), untested OMC integration,
and setup ceremony aren't justified by what we get over YAML files + bash
for one project.

Gas Town is the natural upgrade path if we scale to multi-project fleet
management. Our conventions (especially constraint persistence) should be
portable to Gas Town's polecat workflow.

## Gas Town as future integration target

If clawdance succeeds and needs fleet management:

1. **Our constraints.yaml convention** could become a Gas Town bead type
   or formula step. Polecats read constraints before each task.
2. **Our design-to-task decomposer** could produce Gas Town Formulas
   instead of task-graph.yaml.
3. **OMC inside Gas Town polecats** would combine in-session quality with
   fleet lifecycle management.
4. **Our session skill** could become a Gas Town formula that polecats
   follow, with Gas Town handling the lifecycle and our skill handling
   the OMC integration.

The key design principle: keep our conventions (constraint persistence,
design artifact format, checkpoint structure) independent of the execution
layer so they're portable.

## Portability verification

Verified 2026-04-05. Every clawdance convention maps to a Gas Town
equivalent. The conventions are data (files on disk) and process (prompt
instructions) — both are portable because they don't depend on the
execution layer.

| Our convention | Gas Town equivalent | Portable? |
|---|---|---|
| constraints.yaml | File in rig's hook directory. Polecats read it via formula instruction. | Yes — just a file. Gas Town doesn't care what polecats read. |
| task-graph.yaml (units, deps, parallel groups) | Beads (issues with deps via `bd dep add`) + Formulas (TOML workflow steps). Units → beads. Parallel groups → multiple polecats in one convoy. | Yes, with format mapping. YAML → beads + formula TOML. Same information. |
| checkpoints/unit-NNN.yaml | Poured wisps (step-level completion, survives session death). | Yes — poured wisps are the native equivalent, richer metadata. |
| state.yaml (progress, failures) | Convoy status + bead statuses. `gt convoy list` shows progress. `bv` for graph analysis. | Yes — Gas Town tracking is more sophisticated. |
| design/ artifact structure | Exists in the rig's repo. Gas Town doesn't constrain repo contents. | Yes — orthogonal to Gas Town. |
| Session skill (SKILL.md) | Formula (TOML) defining polecat workflow. Steps shown via `gt prime`. | Yes, with rewrite. SKILL.md → formula.toml. Different format, same logic. |
| Session loop (bash) | `gt daemon` + Witness. Replaces our bash script entirely. | Yes — Gas Town subsumes it. |
| Constraint review step | Formula step: "Read constraints.yaml, check for new invariants, update." | Yes — same logic, different container (formula step vs SKILL.md prompt). |
| Telegram sink (clawhip) | clawhip is independent of Gas Town. Works with both. | Yes — no change needed. |

**Conclusion:** Fully portable. The execution layer (our bash loop vs Gas
Town daemon) is the part that gets swapped, not the conventions. If we
scale to multi-project and adopt Gas Town, the migration is:
1. Reformat task-graph.yaml → beads + formula TOML
2. Replace session loop with `gt daemon`
3. Move constraint review from SKILL.md prompt to formula step
4. Everything else (constraints.yaml, design/, Telegram) works as-is
