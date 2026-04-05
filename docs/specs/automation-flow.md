# Core Automation Flow

Spec draft 2026-04-05. Revised after investigation of OMC internals, Claude
Code CLI, and clawhip capabilities. Covers roadmap item A (implementation
flow, product steps 3-4).

## Goal

Design artifacts go in, working app comes out. Minimal human intervention.
Sessions can die at any point and work resumes automatically.

## What clawdance actually is

An iterative loop of four elements, orchestrated across session boundaries:

1. **Find problems** (bildhauer principles) — data-flow tracing, structural
   alternatives, unchecked assumptions. Pre-phase investigation gates and
   post-unit constraint reviews catch structural incoherence.

2. **Resolve problems** (investigation) — read contracts, read codebase,
   verify assumptions against real code. When a structural problem is
   found, gather evidence to resolve it. Ralph's implementation +
   verification cycle is the per-unit instance of this.

3. **Persist what's learned** (constraint persistence) — constraints.yaml,
   checkpoints, state.yaml. Findings survive session death, compaction,
   and rate limits. Without this, each session re-discovers and re-debates.

4. **Redirect at transitions** (human judgment) — review the task graph
   after decomposition. Monitor progress via Telegram/status. Intervene
   when the automation goes in the wrong direction. The human provides
   direction that the other three can't derive.

These four alternate during execution:

```
find problem → investigate → persist finding →
find again → investigate → persist →
human redirects → investigate new direction → persist →
find confirms stable → move forward
```

No single element is sufficient. Bildhauer finds problems but can't
investigate external systems. Investigation gathers evidence but doesn't
check structural coherence. Persistence preserves state but doesn't
improve quality. Human judgment doesn't scale but provides direction.

The session loop keeps all four running across session boundaries. That's
clawdance's value: not any one element, but the orchestration of all four,
persisted across sessions.

## Architecture: Three components

```
┌─────────────────────────────────────────┐
│          On-disk state (files)          │
│  Task graph, checkpoints, constraints   │
│  Survives everything. The real system.  │
└──────────┬──────────────┬───────────────┘
           │              │
           ▼              ▼
┌──────────────────┐  ┌──────────────────────────────┐
│  Session loop    │  │  Session skill (SKILL.md)    │
│  (bash script)   │  │  Runs inside Claude Code     │
│  Spawns tmux     │  │  with OMC loaded.            │
│  sessions.       │  │  Reads state, picks units,   │
│  Polls for       │  │  invokes OMC skills,         │
���  session death.  │  │  writes checkpoints.         │
│  Checks state.   │  │  Dies with session — fine.   │
└──────────────────┘  └──────────────────────────────┘
```

The on-disk state format is the contract between the session loop and the
skill. Neither needs to know the other's internals.

## Key investigation findings

These findings shaped the architecture. Preserved here so future sessions
don't re-investigate.

### OMC skill invocation (verified)

Skills are SKILL.md prompt templates, not function calls. A skill invokes
another via Claude Code's native `Skill` tool:
`Skill(skill="oh-my-claudecode:ralph", args="...")`. The bridge.ts
post-tool-use hook intercepts and manages state. Skills communicate via
shared state files in `.omc/state/`.

**For our use case:** The session skill invokes ralph directly for
individual units (skip autopilot's decomposition — we already have a task
graph). For parallel groups, the skill invokes team mode.

Source: `upstream/oh-my-claudecode/src/hooks/bridge.ts` (skill routing),
`upstream/oh-my-claudecode/skills/*/SKILL.md` (skill templates).

### Claude Code CLI (verified)

`claude -p "prompt"` runs non-interactively with hooks, plugins, CLAUDE.md,
and the Skill tool all loaded. Only `--bare` disables them. Key flags:

- `-p` / `--print` — non-interactive execution
- `--resume <session-id>` — resume previous session
- `--continue` — continue most recent session
- `--max-turns N` — limit execution length
- `--max-budget-usd N` — limit spend
- `--dangerously-skip-permissions` — unattended execution
- `--output-format json|stream-json` — structured output

### Tmux is the primary execution model (decided)

OMC's team mode spawns parallel agents in tmux panes. clawhip monitors tmux
sessions natively (keyword scanning, stale detection, session lifecycle).
The ecosystem is tmux-native.

Tmux over `-p` because:
- Team mode requires tmux panes for parallel workers
- Session persists independently of the spawning process
- clawhip provides monitoring for free
- OMC's write-then-notify messaging pattern is tmux-based

`-p` mode remains a valid alternative for single-unit execution without
parallelism (CI/CD, scripted workflows, lightweight runs).

Source: `upstream/oh-my-claudecode/src/team/tmux-session.ts` (session
creation, worker spawning), `upstream/clawhip/src/source/tmux.rs`
(monitoring).

### clawhip sink limitations (verified)

clawhip delivers to Discord and Slack only. No exec, webhook, or custom
sinks. It cannot directly trigger session restarts. The session loop polls
tmux directly (`tmux has-session`) instead of subscribing to clawhip events.
clawhip remains useful for human-facing notifications, not lifecycle
management.

### Constraint write conflicts in parallel (identified, mitigated)

constraints.yaml is read before each unit AND written during units. Parallel
agents in separate worktrees each have their own copy — writes won't be
visible to each other until merge. Mitigation: parallel agents write new
constraints to their own checkpoint file. The skill merges them into
constraints.yaml after parallel units complete and integration tests pass.

## Component 1: On-disk state

The real system. Everything that matters is files on disk. If you deleted
the session loop and the skill and kept only these files, a human could
resume the build manually.

```
.clawdance/
├── task-graph.yaml       # Units, dependencies, parallelism groups
├── checkpoints/          # One file per completed unit
│   ├── unit-001.yaml
│   └── unit-002.yaml
├── constraints.yaml      # Operational invariants (cross-component)
└── state.yaml            # Current progress, active session, errors
```

### task-graph.yaml

```yaml
# Produced by decomposition, consumed by the session skill.
# The session loop doesn't read this — it only reads state.yaml.

units:
  - id: unit-001
    name: "Database schema and migrations"
    description: "Create Postgres schema per DESIGN.md data model"
    depends_on: []
    contracts_read:
      - contracts/data-model.yaml
    contracts_produced:
      - contracts/db-schema.sql
    parallel_group: null  # null = can run anytime deps are met

  - id: unit-002
    name: "Auth API endpoints"
    depends_on: [unit-001]
    contracts_read:
      - contracts/api-auth.yaml
      - contracts/data-model.yaml
    contracts_produced: []
    parallel_group: "api"

  - id: unit-003
    name: "User API endpoints"
    depends_on: [unit-001]
    contracts_read:
      - contracts/api-users.yaml
      - contracts/data-model.yaml
    contracts_produced: []
    parallel_group: "api"  # Same group as 002 — can run in parallel
```

Key properties:
- **depends_on** — hard dependencies. Unit cannot start until deps complete.
- **contracts_read** — files the agent MUST read before implementing.
- **contracts_produced** — files this unit creates that others depend on.
- **parallel_group** — units in the same group can run concurrently (OMC
  team mode in tmux panes). null means no grouping constraint.

### checkpoints/unit-NNN.yaml

Written by the session skill when a unit completes.

```yaml
unit_id: unit-001
status: completed            # completed | failed | partial
completed_at: 2026-04-05T14:30:00Z
session_id: "abc123"
branch: "unit-001/db-schema"
tests_passing: true
integration_tests: []        # Cross-component tests written
new_constraints: []          # Constraints discovered during this unit
notes: "Added migration for users and sessions tables"
errors: []
```

The `new_constraints` field is how parallel agents report constraint
discoveries without conflicting on constraints.yaml. After parallel units
complete, the skill merges new_constraints from all checkpoints into
constraints.yaml.

### constraints.yaml

Operational invariants that span components. The critical file that
prevents session-boundary bugs (see research/real-world-validation.md).

```yaml
# Written during design (step 2) and updated during implementation.
# Every session skill invocation reads this before starting work.

constraints:
  - id: c-001
    description: "Every new MCP tool must be added to the allowlist
                  in gateway/config.go"
    affects: [gateway, tools]
    added_by: unit-001
    discovered_by: unit_review    # or: integration_test

  - id: c-002
    description: "audit-sink gRPC server has no compression —
                  exporters must not enable gzip"
    affects: [otel-collector, audit-sink]
    added_by: unit-003
    discovered_by: integration_test
```

Agents are instructed to:
1. Read constraints.yaml before starting any unit
2. Record new constraints in their checkpoint's new_constraints field
3. Check constraints.yaml when modifying any component listed in `affects`

### state.yaml

High-level progress. The session loop reads this to decide whether to
spawn a new session.

```yaml
status: in_progress          # pending | in_progress | completed | failed
current_unit: unit-002
units_completed: [unit-001]
units_failed: []
units_remaining: [unit-002, unit-003, unit-004]
last_session_id: "abc123"
last_checkpoint_at: 2026-04-05T14:30:00Z
consecutive_failures: 0      # For backoff logic in session loop
error: null                  # Set when a unit fails after retries
```

## Component 2: Session skill

A SKILL.md file — a prompt template, like all OMC skills. Runs inside a
Claude Code session with OMC loaded. This is where the actual work happens.

### How it invokes OMC

The skill is a prompt template that instructs Claude to call OMC's skills
via the native Skill tool. It does NOT use autopilot's full 5-phase
pipeline — the task graph already provides decomposition. Instead:

- **Single unit:** `Skill(skill="oh-my-claudecode:ralph", args="<unit description with inlined context>")`
  Ralph provides the PRD-driven persistence loop: decomposes the unit into
  stories with testable acceptance criteria, implements story by story,
  verifies against criteria, gets reviewer sign-off. Ralph's prd.json
  provides sub-unit checkpointing — if a session dies mid-ralph, the next
  session resumes from the last completed story.

- **Parallel group:** `Skill(skill="oh-my-claudecode:team", args="N:executor <unit descriptions>")`
  Team mode spawns N agents in tmux panes with merge coordination.

**Context injection (hybrid approach):** The session skill reads contracts
and constraints BEFORE invoking ralph. It extracts key interface
definitions from each contract (not the full file) and inlines those along
with file paths for full reference. This keeps the ralph prompt focused
while ensuring contracts are visible:

```
Skill(skill="oh-my-claudecode:ralph", args="
  Implement unit-002: Auth API endpoints.

  ## Contracts (conform to these)
  ### api-auth (full file: contracts/api-auth.yaml)
  [key interface definitions extracted by session skill]

  ### data-model (full file: contracts/data-model.yaml)
  [key interface definitions extracted by session skill]

  ## Constraints (do not violate)
  [content from .clawdance/constraints.yaml]

  ## Notes
  Record any cross-component invariants you discover in progress.txt.
  If you need full contract details, read the file paths above.
")
```

Ralph's PRD generation (step 1c) analyzes this full prompt and produces
stories with acceptance criteria that incorporate the contracts and
constraints. Ralph doesn't need to know about clawdance conventions — it
just sees a well-described task.

After ralph exits (via /cancel), control returns to the session skill,
which handles checkpointing, constraint extraction from progress.txt,
and state updates.

### Lifecycle

1. **Read state** — reads state.yaml, task-graph.yaml, checkpoints/
2. **Pick next unit(s)** — find units whose dependencies are all in
   checkpoints/ with status: completed.
   - If a parallel_group is ready: collect all units in that group.
   - Otherwise: pick the next single unit.
3. **Prepare context** — read all contracts_read files for the unit(s).
   Read constraints.yaml. Build the prompt for ralph/team.
4. **Execute** — invoke ralph (single unit) or team (parallel group) via
   the Skill tool. OMC handles the implementation, review, and
   verification pipeline.
5. **Write checkpoint** — on completion, write checkpoints/unit-NNN.yaml.
   Update state.yaml (move unit to completed, reset consecutive_failures
   to 0).
6. **Merge constraints** — if parallel units discovered new constraints
   (in their checkpoint new_constraints fields), merge into
   constraints.yaml.
7. **Loop or stop** — if more units remain and context window has room,
   go to step 2. Otherwise, write state and let the session end.

### Parallel execution

When multiple units share a parallel_group and all their dependencies are
met, the skill uses OMC's team mode. OMC handles:
- Tmux pane creation for each worker
- Worker environment isolation (OMC_TEAM_WORKER env var)
- Worker-to-worker messaging via inbox files + tmux triggers
- Worker guard (prevents recursive spawning)
- Merge coordination

After parallel units complete, the skill:
1. Merges new_constraints from all checkpoints into constraints.yaml
2. Runs integration tests across the merged result
3. Writes checkpoints for all completed units

### Context window management

Claude Code's PreCompact hook fires before compaction. The session skill
can use this as a signal to checkpoint and stop gracefully. Additionally,
the skill can track unit count — after N units in one session, write state
and exit to start fresh.

Heuristics (to be tuned with real builds):
- PreCompact fires → checkpoint immediately, finish current unit, stop
- More than 3 units completed in this session → consider stopping
- After any error that required ralph retries → stop after this unit

### Error handling

- Unit fails after ralph retries: write checkpoint with status: failed
  and errors. Update state.yaml. Increment consecutive_failures. Move to
  next unit if possible (respecting dependencies), or stop.
- Session ending (rate limit, crash): state.yaml reflects last checkpoint.
  Next session resumes from there.
- Repeated failure: session loop backs off after N consecutive failures
  (see component 3).

## Component 3: Session loop

A bash script that spawns tmux sessions and monitors them. All intelligence
is in the skill and on-disk state — the loop just keeps sessions alive.

```bash
#!/usr/bin/env bash
set -euo pipefail

PROJECT_DIR="$(pwd)"
STATE_FILE="$PROJECT_DIR/.clawdance/state.yaml"
MAX_FAILURES=3

while true; do
  status=$(yq -r '.status' "$STATE_FILE")
  failures=$(yq -r '.consecutive_failures // 0' "$STATE_FILE")

  case "$status" in
    completed)
      echo "Build completed."
      # Optionally: clawhip emit build.completed
      exit 0 ;;
    failed)
      echo "Build failed. Check state.yaml for details."
      # Optionally: clawhip emit build.failed
      exit 1 ;;
  esac

  if [ "$failures" -ge "$MAX_FAILURES" ]; then
    echo "Backed off after $failures consecutive failures."
    # Optionally: clawhip emit build.backed-off
    exit 2
  fi

  # Rate-limit-aware delay after unproductive sessions
  if [ "$failures" -gt 0 ]; then
    delay=$((30 * failures))
    echo "Waiting ${delay}s before retry ($failures/$MAX_FAILURES)"
    sleep "$delay"
  fi

  SESSION="clawdance-$(date +%s)"
  tmux new-session -d -s "$SESSION" -c "$PROJECT_DIR"
  tmux send-keys -t "$SESSION" -l 'claude "/clawdance resume"'
  tmux send-keys -t "$SESSION" Enter

  # Wait for session to end
  while tmux has-session -t "$SESSION" 2>/dev/null; do
    sleep 10
  done

  # Check if session was productive (new checkpoint written)
  new_checkpoint=$(yq -r '.last_checkpoint_at // ""' "$STATE_FILE")
  if [ "$new_checkpoint" = "$LAST_CHECKPOINT" ]; then
    current=$(yq -r '.consecutive_failures // 0' "$STATE_FILE")
    yq -i ".consecutive_failures = $((current + 1))" "$STATE_FILE"
  fi
  LAST_CHECKPOINT="$new_checkpoint"
done
```

### What the session loop does

1. Read state.yaml for status and failure count
2. Exit if completed, failed, or backed off
3. Wait if previous session was unproductive (exponential: 30s × failures)
3. Create a tmux session with claude
4. Wait for the session to die (poll `tmux has-session`)
5. Loop — check state again, spawn next session if needed

### What the session loop does NOT do

- Read the task graph (skill's job)
- Decide what to work on (skill's job)
- Know about OMC, contracts, or constraints (not its concern)
- Manage clawhip subscriptions (clawhip monitors tmux independently)

### clawhip integration (notifications, not lifecycle)

clawhip can monitor the tmux sessions the loop creates — keyword scanning,
stale detection, session lifecycle events routed to Discord/Slack/Telegram.
This gives human observers visibility without the loop depending on clawhip.

**Telegram support:** clawhip currently supports Discord and Slack only.
We will extend our clawhip fork with a native Telegram sink (Rust).
Telegram's bot API is a simple HTTP POST — the implementation follows the
same pattern as the existing Discord/Slack webhook sinks. This gives us
a single notification system for all channels (Discord/Slack/Telegram)
with clawhip's event routing, keyword scanning, and stale detection.

To register sessions with clawhip, the loop can use `clawhip tmux new`
instead of raw `tmux new-session`:

```bash
clawhip tmux new \
  -s "$SESSION" \
  -c "$PROJECT_DIR" \
  --keywords "error,failed,completed" \
  --stale-minutes 15 \
  -- 'claude "/clawdance resume"'
```

### MVP: No session loop

The human starts sessions manually. The skill reads state and resumes.
If the session dies, the human starts a new one. The on-disk state format
works identically whether a loop or a human spawns the session.

## Flow: End to end

```
 1. User runs: clawdance-loop.sh  (or starts claude manually)
 2. Tmux session created. Claude starts. OMC loads. Skill activates.
 3. Skill reads .clawdance/state.yaml
    → First run? Read task-graph.yaml, set status: in_progress
    → Resuming? Read checkpoints/, find where we left off
 4. Skill picks next unit(s)
    → Single unit: invoke ralph
    → Parallel group: invoke team mode (tmux panes)
 5. Agent(s) read contracts + constraints.yaml
 6. Agent(s) implement. OMC runs review pipeline.
 7. Agent(s) write per-component tests + integration tests for new
    cross-component connections.
 8. Skill writes checkpoint(s). Merges new constraints. Updates state.
 9. Context check:
    → Room left: go to 4
    → Getting full (PreCompact fired, or N units done): write state, stop
10. Session ends (graceful, crash, or rate limit).
11. Session loop sees session ended, reads state.yaml.
12. Work remaining + not backed off? Go to 2. Otherwise exit.
13. All units complete → skill runs full-stack integration tests.
14. state.yaml status: completed. Done.
```

## What we need to build

| Component | What it is | Complexity | Priority |
|---|---|---|---|
| constraints.yaml | Schema + convention | Schema definition | First (highest proven value) |
| State format | YAML file conventions (task graph, checkpoints, state) | Schema definition | Second |
| Session skill | SKILL.md prompt template | ~100-200 lines of prompt | Third |
| Task decomposer | SKILL.md prompt template | ~50-100 lines of prompt | Fourth |
| Session loop | Bash script | ~30 lines | With session skill |
| clawhip config | Route config for notifications | Configuration | Optional |

**Build order rationale:** constraints.yaml is first because it has the
highest proven value — it prevents the session-boundary bugs validated in
real-world-validation.md, and it's useful even without the task graph.
The task graph is justified by parallelism (team mode) and structured
checkpointing (retry one unit, not everything), but constraints alone
already solve the most validated problem.

**No TypeScript. No daemon process. No custom infrastructure.** The heavy
lifting (parallel agents, retries, reviews, tmux management, monitoring)
already exists in OMC + clawhip.

## Resolved questions

### From investigation (verified against source)

- **How does the skill invoke OMC?** Via `Skill()` tool. Ralph for single
  units, team for parallel groups. Verified in bridge.ts.
- **Session spawning CLI?** Tmux session with `claude` prompt. `-p` mode
  also works (hooks, plugins, CLAUDE.md all load) but tmux is primary for
  team mode compatibility and session persistence.
- **Worktree management?** OMC team mode handles worktrees, merge
  coordination, and worker guards. Skill just invokes team mode.

### From design analysis

**1. Task graph granularity.**

A unit is one component or feature that can be implemented and tested
independently. Target 30-50% of context per unit.

If a unit is too large and the session dies mid-ralph, ralph's prd.json
provides sub-unit checkpointing. Each story has `passes: true/false`. The
next session reads the existing prd.json and resumes from the next
incomplete story — no work is lost. An oversized unit costs one wasted
session start (re-reading context), not one wasted session of work.

The decomposer includes a unit size validation step: after producing
task-graph.yaml, it reviews each unit against heuristics (file count,
component boundaries, feature independence) and splits units that are
likely too large. See risks section for details.

**2. Context window measurement.**

PreCompact hook as primary signal, unit count as safety net. A PreCompact
hook writes `.clawdance/compact-signal`. The session skill checks for this
file after each unit. If present: finish current unit, write state, stop.

Safety net: stop after 5 units in one session regardless. This reduces the
chance of PreCompact firing mid-unit where we can't checkpoint.

**3. Constraint discovery.**

Cross-reference check after each unit. The session skill prompt includes:
"After completing each unit, read constraints.yaml and check: (1) are any
existing constraints affected by what you just built? (2) did you discover
new cross-component invariants — things that would break if another
component doesn't know about them? Write new constraints to the
checkpoint's new_constraints field."

Grounding the check in existing constraints (rather than generating from
nothing) makes it more reliable. The agent may still miss some — that's
what integration tests catch (Category 2 bugs from our taxonomy).

**Validating effectiveness within the process:** When an integration test
fails, ask: "Was there a constraint that would have prevented this?" If
yes, add the missing constraint to constraints.yaml with
`discovered_by: integration_test`. Constraints found by the post-unit
review are tagged `discovered_by: unit_review`. Over time, the ratio of
unit_review vs integration_test discoveries shows whether the review step
is effective. If integration tests keep catching things the review misses,
refine the review prompt. This is self-improving — each miss teaches us
what the prompt doesn't catch.

**4. Design artifact format.**

Minimal required structure from step 2:

```
design/
├── DESIGN.md      # Required: architecture overview
├── STACK.md       # Required: tech stack + testing approach
└── contracts/     # Required: one file per inter-component interface
```

File formats within this structure are flexible (YAML, JSON Schema,
OpenAPI, markdown). The decomposer reads whatever exists and produces
task-graph.yaml. The decomposer verifies that every unit's contracts_read
entries exist on disk — if contracts are missing, it flags the gap before
producing the task graph.

**5. Integration test strategy.**

Project-dependent, driven by STACK.md. STACK.md (produced in step 2)
includes a section on how to run integration tests — docker compose, test
framework, service stubs, etc.

The session skill instructs the agent: "When you create a cross-component
connection, write an integration test that exercises the actual connection.
Read STACK.md for the project's testing approach." We don't prescribe a
specific strategy — the project decides.

## Risks — resolved and remaining

### Resolved

**1. Ralph works with injected contract/constraint context.** ~~Risk.~~

Ralph is a prompt loop driven by `{{PROMPT}}`. The session skill inlines
contract/constraint content into the prompt before invoking ralph. Ralph's
PRD generation (step 1c) analyzes the full prompt and produces stories
with acceptance criteria that incorporate the injected context. The session
skill handles pre/post logic (reads state before ralph, writes checkpoints
after). Ralph doesn't need to know about our file conventions.

Additionally, ralph's progress.txt (step 5b: "learnings for future
iterations") is a natural channel for constraint discovery. The session
skill's prompt includes: "In progress.txt, note any cross-component
invariants you discover." After ralph exits, the session skill reads
progress.txt for new constraints — a second discovery channel alongside
the post-unit constraint review.

**2. Catching the PreCompact signal in time.** ~~Risk.~~

PreCompact fires at ~80-90% context usage — sufficient lead time. Unit
count safety net (stop after 5 units) bounds work per session. Remaining
edge case (single unit exhausts the 10-20% remaining) is mitigated by
the decomposer targeting 30-50% of context per unit.

### Reduced (from high to low)

**3. Decomposer unit size estimation.**

Originally high risk: LLMs are bad at effort estimation. Now low risk for
two reasons:

a) **Ralph provides sub-unit checkpointing via prd.json.** Each story has
   `passes: true/false`. If a session dies mid-ralph, prd.json shows which
   stories completed. The next session's ralph invocation reads the existing
   prd.json (step 1a: "if prd.json exists, read it and proceed to Step 2")
   and picks up from the next incomplete story. A partial unit retry doesn't
   redo all work — ralph resumes from where it left off.

   This means the decomposer can be less precise about unit sizing because
   ralph handles granularity internally. An oversized unit costs one wasted
   session start, not one wasted session of work.

b) **Unit size validation step in the decomposer.** After producing
   task-graph.yaml, the decomposer reviews each unit against heuristics:
   - Touches more than ~10 files? Consider splitting.
   - Crosses more than 2 component boundaries? Consider splitting.
   - Description contains multiple independent features? Must split.
   
   If any unit fails, the decomposer splits it before implementation
   starts. This is a prompt-based check, part of the decomposer SKILL.md.

### Remaining (validate during first real build)

**4. End-to-end flow works as designed.** The full chain (decomposer →
session skill → ralph → checkpoint → constraint review → next unit) has
never run. Each piece is theoretically sound, but the integration between
them is untested. First real build will reveal seam issues.

**5. Constraint review prompt effectiveness.** The post-unit prompt "what
constraints does this impose on other components?" is plausible but
untested. The `discovered_by` tracking mechanism (unit_review vs
integration_test) will measure effectiveness over time. Ralph's
progress.txt provides a second discovery channel.

## Bildhauer analysis notes

The Bildhauer step-back surfaced a structurally different alternative worth
recording: **no task graph at all.** The session skill reads design
artifacts and builds sequentially, using ralph for implementation and team
for obvious parallelism. Recovery is git-based (read existing code and
continue). This eliminates the decomposer, state format, and session loop.

Not adopted because the task graph is justified by:
- **Parallelism:** without it, team mode has nothing to parallelize against
- **Structured checkpointing:** "retry one unit" vs "retry from the
  beginning"

But the analysis revealed: **constraints.yaml is more valuable than the
task graph.** Even without formal units, constraint persistence prevents
session-boundary bugs. This informed the build order (constraints first).

A second Bildhauer pass examined whether Gas Town should replace our thin
layer entirely. Conclusion: Gas Town's cost/benefit ratio is wrong for
single-project builds (see ADR-005). But several Gas Town patterns are
worth adopting:

- **Decision logging in checkpoints** (inspired by Seance). Not just
  "unit-001 completed" but approach chosen and alternatives rejected.
  OMC's commit protocol (structured trailers) may cover this via git log.
- **Sub-unit checkpointing** (inspired by poured wisps). If units prove
  too large, consider step-level checkpoints within units, not just
  unit-level.
- **Rate-limit-aware session spawning** (inspired by Scheduler). Add delay
  between session spawns based on API usage signals.
- **Portable conventions.** Keep constraint persistence and design artifact
  format independent of the execution layer, so they can port to Gas Town
  if we scale to multi-project.

See [Gas Town analysis](../research/gas-town-analysis.md) for full details.
