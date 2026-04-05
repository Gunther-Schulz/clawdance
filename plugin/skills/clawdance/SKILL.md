---
name: clawdance
description: Autonomous build from design artifacts with cross-session constraint persistence. Reads .clawdance/ state, picks next unit, executes via OMC ralph/team, writes checkpoints, discovers constraints. Invoke with "resume" to continue a build, "status" for progress.
argument-hint: "[resume|status|rollback unit-NNN]"
---

# clawdance — Session Skill

You are the orchestrator of an autonomous build. Your job: read state,
pick the next unit, prepare context, hand to ralph or team for execution,
then checkpoint and review constraints. Loop until done or context is
getting full.

You do NOT implement code yourself. You delegate to OMC skills (ralph for
single units, team for parallel groups). You handle state management,
context injection, and constraint persistence.

## Commands

- **resume** (default): Continue the build from where it left off.
- **status**: Read-only progress report. Do not start or modify anything.
- **rollback unit-NNN**: Delete the checkpoint for the specified unit,
  move it from units_completed back to units_remaining in state.yaml,
  reset consecutive_failures to 0. Do not start building.

---

## Resume Flow

### Step 1 — Read state

Read `.clawdance/state.yaml`.

- If `status: pending`: first run. Read `.clawdance/task-graph.yaml`.
  Set status to `in_progress`. Populate `units_remaining` from the task
  graph. Write state.yaml.
- If `status: in_progress`: read all files in `.clawdance/checkpoints/`.
  Determine which units are completed, failed, and remaining.
- If `status: completed` or `status: failed`: report the status and stop.

### Step 2 — Check stop signals

- If `.clawdance/compact-signal` exists: delete it, write current state,
  report "Context getting full, stopping gracefully." Stop.
- If you have completed 5 or more units in THIS session: write state,
  report "Session unit limit reached, stopping for fresh context." Stop.

Track units completed this session with a counter (starts at 0, increments
each time you write a checkpoint in this session).

### Step 3 — Pick next unit(s)

Read `.clawdance/task-graph.yaml`. For each unit in `units_remaining`:
check if all entries in its `depends_on` are in `units_completed`.

- If a `parallel_group` has ALL its units ready (all dependencies met for
  every unit in the group): collect the group for team mode execution.
- If no complete parallel group is ready but individual units are ready:
  pick the single highest-priority ready unit (first in the task graph).
- If no units are ready but units remain: something is blocked. Report
  which units are blocked and on what. Stop.

### Step 4 — Prepare context (hybrid injection)

For the selected unit(s), read all files listed in `contracts_read`.
For each contract file:
- Extract the key interface definitions (types, endpoints, schemas — not
  the entire file if it's large)
- Note the full file path for reference

Read `.clawdance/constraints.yaml`.

Build the prompt for ralph (single unit) or team (parallel group):

```
Implement [unit name]: [unit description]

## Contracts (conform to these)
### [contract name] (full file: [path])
[extracted key interface definitions]

### [contract name] (full file: [path])
[extracted key interface definitions]

## Constraints (do not violate)
[full content of constraints.yaml]

## Notes
- Record any cross-component invariants you discover in progress.txt.
- If you need full contract details, read the file paths above.
- When creating a cross-component connection, write an integration test
  for it immediately.
```

### Step 5 — Execute

**Single unit:**
```
Skill(skill="oh-my-claudecode:ralph", args="[the prompt from step 4]")
```

**Parallel group:**
```
Skill(skill="oh-my-claudecode:team", args="[N]:executor [prompts for each unit]")
```

Wait for completion. Ralph exits via `/oh-my-claudecode:cancel` and control
returns to you. If control does not return (test this — it should, based
on how OMC's autopilot→ralph chain works), use the fallback: include all
post-unit steps in the ralph prompt itself rather than running them after.

### Step 6 — Post-unit

After ralph/team completes:

**a) Write checkpoint:**
Write `.clawdance/checkpoints/[unit-id].yaml` with all required fields:
unit_id, status, completed_at (current ISO timestamp), session_id, branch
(if a branch was created), tests_passing, notes.

**b) Validate checkpoint:**
Re-read the checkpoint file you just wrote. Verify all required fields are
present and have the correct types. If malformed, rewrite it.

**c) Mine progress.txt:**
Read `.omc/progress.txt` (ralph's progress file). Look for any mentions of
cross-component invariants, constraints, or things other components need to
know about. Deduplicate: if a constraint with the same description already
exists in constraints.yaml, skip it.

**d) Constraint review:**
Read `.clawdance/constraints.yaml`. Ask yourself:
- Are any existing constraints affected by what was just built?
- Did the implementation reveal new cross-component invariants — things
  that would break if another component doesn't know about them?

For new constraints: if this was a single unit, add directly to
constraints.yaml with the next available c-NNN id and
`discovered_by: unit_review`. If this was a parallel group, add to the
checkpoint's `new_constraints` field instead (merged after all parallel
units complete).

**e) Merge parallel constraints:**
If a parallel group just completed, read `new_constraints` from ALL
checkpoints in the group. Deduplicate by description. Add unique ones to
constraints.yaml with next available IDs.

**f) Update state.yaml:**
Move the unit from `units_remaining` to `units_completed` (or
`units_failed` if it failed). Set `current_unit` to null. Update
`last_checkpoint_at` to now. **Reset `consecutive_failures` to 0**
(this was a productive session). Validate: re-read state.yaml and verify.

### Step 7 — Sweep check

Quick, open-ended review before continuing:

- Is the state consistent? Does state.yaml's units_completed match the
  checkpoint files that exist?
- Anything look wrong in the checkpoint just written?
- Any loose ends from the unit that just completed?
- Does the task graph still make sense given what was built?

If something's off, fix it before continuing. This catches housekeeping
issues that the structured checks (constraint review, YAML validation)
miss.

### Step 8 — Loop or stop

- If more units remain and no stop signal: go to Step 2.
- If all units are complete: proceed to Step 9.
- If context is getting heavy (even without compact-signal): consider
  stopping for a fresh session. Recommend: "5 units completed, stopping
  for fresh context."

### Step 9 — All units complete

All units have checkpoints with `status: completed`.

1. Run full-stack integration tests as described in `design/STACK.md`
   (or the project's test configuration).
2. If tests fail: identify which constraint was missing, add it to
   constraints.yaml with `discovered_by: integration_test`. Consider
   which unit needs rework. Update the relevant checkpoint to
   `status: failed` and move the unit back to `units_remaining`.
3. If tests pass: set state.yaml `status: completed`.

Report summary: units completed, constraints discovered, any concerns.

---

## Principles

- **You orchestrate, you don't implement.** Ralph and team do the coding.
  You manage state, context, and constraints.
- **Self-resolve from context.** When a practical question arises (which
  pattern to follow, which convention to use), derive the answer from the
  codebase, STACK.md, constraints.yaml, or prior checkpoints. Don't ask
  the human for things you can figure out.
- **Recommendation-first.** When you DO interact with the human (at
  blockers or completion), present your recommendation with reasoning and
  a default action. Not open questions.
- **Persist everything that matters.** If you learned something that a
  future session needs to know, write it to a checkpoint note or
  constraints.yaml. The conversation dies; the files survive.
