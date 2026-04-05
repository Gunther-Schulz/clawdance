# Implementation Plan: Roadmap Item A

Implementation plan for the core automation flow (product steps 3-4).
Six deliverables in priority order. Bildhauer-validated.

Reference: [automation-flow.md](automation-flow.md) for full spec.

## Overview

```
Step 1: constraints.yaml ──► can be used standalone immediately
Step 2: state format ──► task-graph.yaml, checkpoints/, state.yaml
Step 3: session skill ──► SKILL.md that ties 1+2 together with OMC
Step 4: decomposer ──► SKILL.md that produces step 2 from design artifacts
Step 5: session loop ──► bash script that keeps step 3 alive across sessions
Step 6: Telegram sink ──► clawhip Rust extension for notifications
```

Steps 1-2 are file conventions (no code). Steps 3-4 are SKILL.md prompt
templates. Step 5 is ~30-40 lines of bash. Step 6 is Rust.

**Parallelism:** Steps 1-3 are sequential (each validates the previous).
Steps 4+5 can be parallel after 3. Step 6 is independent (different repo,
different language) and can be built from the start.

```
Sequential: [1: constraints] → [2: state format] → [3: session skill]
                                                      │           │
Parallel after 3:                         [4: decomposer]  [5: session loop]

Parallel from start:                      [6: Telegram sink (independent)]
```

**Validation philosophy:** In-production validation is NOT a blocker for
building. All steps use best-guess/best-effort. Items flagged "validate
in practice" are built now and tuned later.

## Packaging: Claude Code plugin

Same pattern as bildhauer and clippy. Plugin structure:

```
plugin/
├── .claude-plugin/
│   └── plugin.json                # Manifest
├── skills/
│   ├── clawdance/
│   │   └── SKILL.md               # Session skill (/clawdance)
│   ├── clawdance-decompose/
│   │   └── SKILL.md               # Decomposer (/clawdance-decompose)
│   └── clawdance-build/
│       └── SKILL.md               # Full auto mode (/clawdance-build)
├── CLAUDE.md                      # Constraint convention (injected into sessions)
└── bin/
    └── clawdance-loop.sh          # Session loop script
```

**plugin.json:**
```json
{
  "name": "clawdance",
  "version": "0.1.0",
  "description": "Autonomous app development with cross-session constraint persistence",
  "author": { "name": "Gunther Schulz" },
  "repository": "https://github.com/Gunther-Schulz/clawdance",
  "license": "MIT"
}
```

**PreCompact hook:** Registered in the user's settings.json (plugin doesn't
auto-register hooks — same as bildhauer/clippy). Documentation tells the
user to add:

```json
{
  "hooks": {
    "PreCompact": [{
      "type": "command",
      "command": "touch .clawdance/compact-signal"
    }]
  }
}
```

**Plugin CLAUDE.md** is injected into every session alongside the project's
own CLAUDE.md. Claude Code merges both (proven by bildhauer). Contains the
constraint convention snippet.

## User journey

### One-time setup

```
1. Install OMC plugin (prerequisite)
2. Install clawdance plugin (local path or marketplace)
3. Add PreCompact hook to settings.json
4. Configure Telegram (optional):
   export CLAWDANCE_TELEGRAM_TOKEN=...
   export CLAWDANCE_TELEGRAM_CHAT=...
```

### Per-project

```
1. Create design artifacts:
   design/DESIGN.md      — architecture overview
   design/STACK.md       — tech stack + testing approach
   design/contracts/     — one file per inter-component interface

2. Decompose:
   /clawdance-decompose design/
   → produces .clawdance/ (task-graph.yaml, state.yaml, constraints.yaml)

3. Review (human checkpoint):
   Read .clawdance/task-graph.yaml
   Adjust units, dependencies, parallelism if needed
   Optionally seed constraints.yaml with known design-phase constraints

4. Build — choose one:
   With checkpoint:  /clawdance resume
                     (re-run after each session death)
   Full auto:        /clawdance-build design/
                     (decomposes + builds, no checkpoint)
   Automated loop:   clawdance-loop.sh .
                     (handles restart automatically)

5. Monitor — choose any:
   Telegram notifications (if configured)
   tmux attach -t clawdance-*
   /clawdance status (read-only progress check)
   cat .clawdance/state.yaml

6. Done:
   state.yaml → status: completed
   All checkpoints in .clawdance/checkpoints/
   Constraints accumulated in constraints.yaml
```

### Three build modes

| Mode | Command | Human involvement | Use when |
|---|---|---|---|
| Step-by-step | `/clawdance resume` | Re-run after each session death | First use, learning, debugging |
| Full auto | `/clawdance-build design/` | None until completion | Trusted decomposer, confident design |
| Loop | `clawdance-loop.sh .` | None (auto-restart) | Overnight builds, CI/CD |

---

## Step 1: constraints.yaml schema + convention

**What:** Define the schema, write the plugin CLAUDE.md that injects the
constraint convention, document discovered_by tracking.

**Deliverables:**
- constraints.yaml schema definition
- Plugin CLAUDE.md with constraint convention
- Documentation

**Schema:**

```yaml
# .clawdance/constraints.yaml
version: 1
constraints:
  - id: c-001                    # Unique ID, auto-incrementing
    description: "..."           # What the constraint is
    affects: [component-a, ...]  # Which components must respect this
    added_by: unit-001           # Which unit discovered it (or "design")
    discovered_by: unit_review   # unit_review | integration_test | design
    created_at: 2026-04-05       # When it was added
```

**Plugin CLAUDE.md snippet:**

```markdown
## Cross-component constraints (clawdance)

This project may track cross-component invariants in
`.clawdance/constraints.yaml`. If this file exists:

- **Before starting work:** read constraints.yaml. Check if any constraints
  affect the components you're about to modify.
- **After completing work:** review constraints.yaml. Are any existing
  constraints affected? Did you discover new invariants? Add new
  constraints with `discovered_by: unit_review`.
- **When an integration test reveals a missing constraint:** add it with
  `discovered_by: integration_test`.
```

**Validation:** Add to an existing project, verify agents read/write it.

**Depends on:** Nothing.

---

## Step 2: State format (task graph, checkpoints, state)

**What:** Define YAML schemas for all .clawdance/ files.

**Deliverables:**
- task-graph.yaml schema
- checkpoints/unit-NNN.yaml schema
- state.yaml schema
- Example files for a hypothetical 3-component project

**Required fields (session skill reads these, extras ignored):**

task-graph.yaml:
```yaml
version: 1
units:
  - id: unit-NNN               # Required
    name: "..."                 # Required
    description: "..."          # Required
    depends_on: []              # Required (empty = no deps)
    contracts_read: []          # Required (empty = no contracts)
    contracts_produced: []      # Optional
    parallel_group: null        # Optional (null = no group)
```

checkpoints/unit-NNN.yaml:
```yaml
unit_id: unit-NNN              # Required
status: completed              # Required: completed | failed | partial
completed_at: ISO-8601         # Required
session_id: "..."              # Required
branch: "..."                  # Optional
tests_passing: true            # Required
integration_tests: []          # Optional
new_constraints: []            # Optional
notes: "..."                   # Optional
errors: []                     # Optional
```

state.yaml:
```yaml
version: 1                     # Required
status: pending                # Required: pending|in_progress|completed|failed
current_unit: null             # Optional
units_completed: []            # Required
units_failed: []               # Required
units_remaining: []            # Required
last_session_id: "..."         # Optional
last_checkpoint_at: ISO-8601   # Optional
consecutive_failures: 0        # Required
error: null                    # Optional
```

**Hand-edited YAML:** Users may edit task-graph.yaml between decompose and
build. The session skill reads specific fields and ignores extras. If a
required field is missing or has the wrong type, the skill reports the
error and stops (doesn't guess).

**Validation:** Write example files, verify readability.

**Depends on:** Step 1.

---

## Step 3: Session skill (SKILL.md)

**What:** The core prompt template. Most complex piece. If this doesn't
work, nothing else matters.

**Deliverables:**
- `plugin/skills/clawdance/SKILL.md` (~150-200 lines)
- PreCompact hook documentation

**SKILL.md structure:**

```markdown
---
name: clawdance
description: Autonomous build from design artifacts with cross-session
  constraint persistence. Reads .clawdance/ state, picks next unit,
  executes via OMC ralph/team, writes checkpoints.
argument-hint: "[resume|status]"
---

[Session skill content — steps as designed in automation-flow.md]

Key steps:
1. Read state (state.yaml, checkpoints/)
2. Check compact signal + unit count safety net
3. Pick next unit(s) (dependency resolution, parallel groups)
4. Prepare context (hybrid contract injection: summaries + paths)
5. Execute (ralph for single, team for parallel)
6. Post-unit (checkpoint, YAML validation, constraint review,
   progress.txt mining with dedup, state update + reset failures)
7. Loop or stop
8. All complete → full-stack integration tests → done
```

**Key behaviors:**
- Hybrid contract injection: summaries + file paths, not full files
- YAML validation after every write: re-read, verify required fields
- Ralph exit returns control (proven by OMC autopilot→ralph pattern)
- `/clawdance status`: read-only, reports progress without starting work
- `/clawdance rollback unit-NNN`: delete checkpoint, move unit from
  completed back to remaining in state.yaml, reset consecutive_failures
- If ralph's prd.json exists from a previous partial run, ralph resumes
  from the last completed story (sub-unit checkpointing for free)

**Seam 2 fallback:** If ralph exit doesn't return control to the skill
(test during validation), fallback: single-prompt flow instead of
skill-to-skill. The session skill includes all steps inline rather than
invoking ralph as a separate skill. Less clean but functional.

**Validation:** Pre-build .clawdance/ with a 2-unit task graph (one done,
one remaining). Invoke `/clawdance resume`. Verify it picks the right
unit, invokes ralph, and — critically — writes checkpoint after ralph
exits. This tests seam 2.

**Depends on:** Steps 1-2.

---

## Step 4: Decomposer (SKILL.md)

**What:** Takes design artifacts, produces task-graph.yaml.

**Deliverables:**
- `plugin/skills/clawdance-decompose/SKILL.md` (~80-120 lines)

**Key behaviors:**
- Reads design/DESIGN.md, design/STACK.md, design/contracts/
- Identifies components → maps dependencies → maps contracts
- Validates: every inter-component interface has a contract file.
  Missing = STOP and report. No guessing.
- Unit size heuristics: >10 files? >2 component boundaries? Multiple
  independent features? → split
- YAML validation after producing task-graph.yaml
- Initializes .clawdance/ directory (state.yaml pending, empty
  constraints.yaml, checkpoints/ dir)

**Validation:** Hand-written design artifacts for a 3-component app. Verify
task-graph.yaml has correct dependencies. Verify session skill (step 3)
can consume the output (seam 4).

**Depends on:** Steps 1-2. Can be parallel with step 5 after step 3.

---

## Step 5: Session loop (bash script)

**What:** Spawns tmux sessions, monitors, restarts.

**Deliverables:**
- `plugin/bin/clawdance-loop.sh` (~30-40 lines)

**Script:**

```bash
#!/usr/bin/env bash
set -euo pipefail

PROJECT_DIR="${1:-.}"
STATE_FILE="$PROJECT_DIR/.clawdance/state.yaml"
MAX_FAILURES="${CLAWDANCE_MAX_FAILURES:-3}"
TELEGRAM_TOKEN="${CLAWDANCE_TELEGRAM_TOKEN:-}"
TELEGRAM_CHAT="${CLAWDANCE_TELEGRAM_CHAT:-}"

notify() {
  [ -n "$TELEGRAM_TOKEN" ] && curl -s \
    "https://api.telegram.org/bot$TELEGRAM_TOKEN/sendMessage" \
    -d "chat_id=$TELEGRAM_CHAT&text=$1" >/dev/null || true
}

LAST_CHECKPOINT=""

while true; do
  status=$(yq -r '.status' "$STATE_FILE")
  failures=$(yq -r '.consecutive_failures // 0' "$STATE_FILE")

  case "$status" in
    completed) notify "Build completed."; exit 0 ;;
    failed)    notify "Build failed."; exit 1 ;;
  esac

  if [ "$failures" -ge "$MAX_FAILURES" ]; then
    notify "Backed off after $failures failures."
    exit 2
  fi

  # Rate-limit-aware delay: wait longer after unproductive sessions
  if [ "$failures" -gt 0 ]; then
    delay=$((30 * failures))
    notify "Waiting ${delay}s before retry ($failures/$MAX_FAILURES)"
    sleep "$delay"
  fi

  SESSION="clawdance-$(date +%s)"
  notify "Starting session $SESSION"

  tmux new-session -d -s "$SESSION" -c "$PROJECT_DIR"
  tmux send-keys -t "$SESSION" -l 'claude "/clawdance resume"'
  tmux send-keys -t "$SESSION" Enter

  # Wait for session to end
  while tmux has-session -t "$SESSION" 2>/dev/null; do sleep 10; done

  # Check if session was productive (new checkpoint written)
  new_checkpoint=$(yq -r '.last_checkpoint_at // ""' "$STATE_FILE")
  if [ "$new_checkpoint" = "$LAST_CHECKPOINT" ]; then
    # No progress — likely rate limit, crash, or context exhaustion
    current=$(yq -r '.consecutive_failures // 0' "$STATE_FILE")
    yq -i ".consecutive_failures = $((current + 1))" "$STATE_FILE"
  fi
  LAST_CHECKPOINT="$new_checkpoint"
done
```

**Skill invocation:** `claude "/clawdance resume"` — the `/clawdance`
prefix directly triggers the skill in Claude Code.

**Rate-limit-aware spawning:** Measures whether sessions are productive
(new checkpoint written). Unproductive sessions get exponential delay
(30s × failure count). Doesn't need to know HOW the session died — rate
limits, crashes, and context exhaustion all get the same response (wait,
retry).

**Interim Telegram via curl:** Replaced by clawhip routing once step 6 is
built.

**Validation:** Mock .clawdance/ state, run loop, kill session, verify
restart, set completed, verify exit.

**Depends on:** Steps 1-3. Can be parallel with step 4.

---

## Step 6: Telegram sink for clawhip (Rust)

**What:** Native Telegram bot API sink for clawhip. Independent work.

**Deliverables:**
- TelegramBot variant in SinkTarget enum
- HTTP POST implementation (Telegram bot API)
- Config support + route configuration
- Tests

**Implementation:** Follow existing Discord webhook pattern. Telegram API
is `POST https://api.telegram.org/bot{token}/sendMessage` with `chat_id`
and `text`.

**Config:**
```toml
[telegram]
token = "bot123:ABC..."
default_chat_id = "-100123456"

[[routes]]
event = "session.*"
sink = "telegram"
chat_id = "-100123456"
```

**Validation:** `clawhip emit` → message in Telegram chat.

**Depends on:** Nothing. Can be built from the start in parallel.

---

## Step 7 (bonus): Full auto mode (SKILL.md)

**What:** `/clawdance-build design/` — decomposes and builds in one shot,
no human checkpoint.

**Deliverables:**
- `plugin/skills/clawdance-build/SKILL.md` (~20 lines, thin wrapper)

**SKILL.md:**
```markdown
---
name: clawdance-build
description: Full autonomous build — decompose design artifacts and build
  without human checkpoint
argument-hint: "<path to design/ directory>"
---

Run /clawdance-decompose on the specified directory, then immediately
run /clawdance resume to start building. No human review of the task
graph.
```

Thin wrapper over steps 3+4. Built after both exist.

**Depends on:** Steps 3-4.

---

## Integration seams (test in risk order)

| Seam | What | Risk | Test |
|---|---|---|---|
| 2 | skill → ralph → skill (control returns?) | Highest | Invoke /clawdance, verify checkpoint written after ralph exits |
| 1 | state format → skill (picks correct unit?) | Medium | Pre-built state with deps, verify correct unit picked |
| 3 | skill → YAML (writes valid files?) | Medium | Verify checkpoint has all required fields after write |
| 4 | decomposer → skill (output consumable?) | Low | Run decomposer, feed output to skill |
| 5 | loop → skill (triggers correctly?) | Low | Run loop, verify /clawdance resume activates skill |

**Gate:** If seam 2 fails, stop and use the fallback (inline prompt flow
instead of skill-to-skill). Don't build steps 4-6 on a broken foundation.

---

## What we expect to learn (validate in practice, not blockers)

- Whether ralph's PRD handles hybrid contract injection well
- Whether the unit count safety net (5) is right or needs tuning
- Whether the constraint review prompt catches real constraints
- Whether the decomposer's size heuristics are useful
- Whether YAML validation catches malformed writes
- Seam issues between session skill and ralph

---

## Implementation notes (from final Bildhauer review)

- **progress.txt constraint dedup:** Ralph may append across invocations.
  When mining progress.txt for constraints, check if a constraint with
  the same description already exists in constraints.yaml before adding.

- **Trust dialog in loop:** The session loop sends `claude "/clawdance
  resume"` via tmux. On trusted machines (user's dev environment), this
  works. On fresh environments, Claude Code may show a trust dialog first.
  Document: "run `claude` once manually in the project directory to accept
  the trust prompt before using the loop."

- **Decomposer `--partial` flag:** Strict contract validation ("if missing,
  STOP") could block users who want to start building before contracts are
  complete. Consider adding `--partial` that produces the task graph with
  warnings instead of stopping. Not needed initially — add if users hit
  this friction.

## Deferred

- **Gas Town integration** as upgrade path for multi-project fleet
  management. All conventions verified portable (see
  research/gas-town-analysis.md).

---

## Summary

| Step | What | Lines | Language |
|---|---|---|---|
| 1 | constraints.yaml | ~30 (schema + CLAUDE.md) | YAML + markdown |
| 2 | State format | ~60 (schemas + examples) | YAML |
| 3 | Session skill | ~150-200 | Markdown (SKILL.md) |
| 4 | Decomposer | ~80-120 | Markdown (SKILL.md) |
| 5 | Session loop | ~30-40 | Bash |
| 6 | Telegram sink | ~100-200 | Rust |
| 7 | Full auto mode | ~20 | Markdown (SKILL.md) |

Total: ~500 lines of prompts/schemas, ~40 lines of bash, one Rust module.
Packaged as a Claude Code plugin following the bildhauer/clippy pattern.
