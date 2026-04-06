---
name: clawdance
description: This skill should be used when the user says "clawdance", "autonomous build", or asks to "build me", "create an app", "start a project". Autonomous app development orchestrator — detects project state, recommends next action, confirms at phase transitions.
argument-hint: "<idea or task> | resume | status | rollback unit-NNN"
---

# clawdance — Orchestrator

Orchestration loop. Detect state, recommend actions,
confirm with the user at phase transitions, and invoke focused phase
skills. Do NOT do the work directly — delegate.

All clawdance state lives under `.clawdance/` — one hidden directory,
clean project root.

```
.clawdance/
├── design/
│   ├── DESIGN.md
│   ├── STACK.md
│   └── contracts/
├── task-graph.yaml
├── state.yaml
├── constraints.yaml
├── checkpoints/
└── history/            # Archived state from previous build cycles
```

## Commands

- **"Build me X"** / **"Add feature X"** (default): Detect state,
  recommend action, confirm, proceed.
- **resume**: Continue building from where the last session left off.
  No confirmation needed — intent is unambiguous.
- **status**: Read-only progress report. Do not start or modify anything.
- **rollback unit-NNN**: Delete checkpoint, move unit back to remaining,
  reset consecutive_failures to 0.

## Orchestration Loop

### 0. Check prerequisites

On first invocation, verify OMC is loaded. Do this quickly — no research,
no agents, no exploration. Just check:
1. Does `.omc/` directory exist? OR
2. Is `oh-my-claudecode` in the loaded skills list?

If neither: report this and stop:
"OMC plugin not detected. Install it globally (available in all projects):
  /plugin marketplace add Yeachan-Heo/oh-my-claudecode
  /plugin install oh-my-claudecode@oh-my-claudecode --scope user
  /reload-plugins
Then run /clawdance again."

Do NOT launch agents, search the codebase, or research OMC. Just check
and report. This should take under 2 seconds.

### 1. Validate state

If `.clawdance/` exists, validate before making decisions:
- `state.yaml`: has `version` field, valid `status` value, valid YAML
- `constraints.yaml`: valid YAML with `version` field
- `task-graph.yaml`: valid YAML, `units` is a list

If corrupted: report what's wrong, suggest fix. Don't guess, don't crash.

### 2. Detect and recommend

Read project state. Present the current state and recommend the next action.
**Confirm with the user at non-obvious decisions. Act without confirming
when intent is unambiguous.**

**No .clawdance/, no source code, user provided a task:**
"Empty project. I'll design [task] from scratch."
→ Interactive: confirm, then invoke design skill.

**No .clawdance/, source code exists, user provided a task:**
"I see an existing [language/framework] project. I'll analyze the
codebase first, then design [task]."
→ Interactive: confirm, then invoke design skill in analyze mode.

**No .clawdance/, source code exists, no task provided:**
"I see an existing project but no task. What would you like to build
or change?"
→ Interactive: wait for user input.

**.clawdance/ exists, status: completed, user provided a new task:**
"Previous build completed. Starting new build cycle for [task].
Preserving constraints from the previous build."
→ Interactive: confirm, then archive old state to `.clawdance/history/`,
  proceed with design for new task.

**.clawdance/ exists, status: in_progress, user said "resume":**
→ Autonomous: no confirmation needed. Read state, invoke build skill.

**.clawdance/ exists, status: in_progress, user provided a task:**
"Build in progress (N/M units complete). Continuing current build.
If you meant to start a new task, say 'start over'."
→ Autonomous: continue building. User redirects if wrong.

**.clawdance/ exists, status: pending:**
→ Present task graph for confirmation, then invoke build skill.

**.clawdance/ exists, status: failed:**
→ Report failure details, suggest next steps (rollback, retry, redesign).

**.clawdance/ exists, design incomplete:**
→ Invoke design skill to fill gaps.

### 3. Design phase (iterative)

Invoke the design skill multiple times at increasing resolution.

**For new projects:**
- Architecture: user's idea → DESIGN.md (interactive — user confirms)
- Stack: DESIGN.md → STACK.md (autonomous)
- Contracts: one per interface (autonomous)
- Validation: coherence check (autonomous)

**For existing projects:**
- Analyze mode produced the baseline (from step 2)
- Design the CHANGE: which components touched, what's new (interactive
  — user confirms scope)
- Updated/new contracts for affected interfaces (autonomous)

### 4. Decompose phase

Invoke the decompose skill. Present the task graph:
"Here's the build plan: N units, M parallel groups. [summary]. Go?"
→ Interactive: user confirms or adjusts.

### 5. Build phase (iterative, autonomous)

The build skill handles ONE UNIT per invocation. The orchestrator calls
it repeatedly. This is the autonomous core — no confirmation per unit.

- Read state.yaml → pick next unit(s)
- Invoke build skill
- Check: more units? Context room left? Invoke again or stop.

Between invocations: check stop signals, merge parallel constraints,
sweep check.

Pre-phase investigation gate reads actual code before each unit —
catches manual changes between sessions naturally.

### 6. Completion

Report: units completed, constraints discovered (with confidence levels),
any concerns. Interactive only if there are concerns to flag.

## Transparency

At every phase transition, show the user what's happening and what comes
next. The user should never wonder "what is it doing?" or "what did it
decide?"

**Before invoking ralph for a unit:**
```
Building unit-004 (auth-stack).
  Contracts: rest-api.md (auth endpoints), data-model.md (user types)
  Constraints: 8 active (auth middleware, ownership checks, sync DB...)
  Sending to ralph with --no-prd: [one-line summary of the prompt]
```

**After ralph completes a unit:**
```
Unit-004 complete.
  Files created: src/repositories/users.ts, src/services/auth.ts, +2 more
  Tests: tsc passes
  New constraints discovered: none
  Progress: 4/8 units done. Next: unit-005 (habits-stack)
```

**After parallel group completes:**
```
Parallel group "data-foundation" complete (units 002, 003).
  Constraints merged: 0 new
  Progress: 3/8 units done. Next: unit-004 (auth-stack)
```

**On constraint discovery:**
```
New constraint found during unit-008:
  c-009: "JWT_SECRET must be set via vitest.config.ts env option"
  Added to constraints.yaml (discovered_by: unit_review, confidence: verified)
```

**On session stop:**
```
Stopping: 5 units completed this session (safety limit).
  State saved. Run /clawdance resume to continue.
  Remaining: unit-006, unit-007, unit-008
```

Keep it concise — summary lines, not full dumps. The user can always
read the actual files for details.

## Principles

- **Detect, recommend, confirm.** Auto-detect state. Present your
  recommendation. Confirm at phase transitions. Act autonomously during
  focused work (build phase).
- **Show your work at transitions.** Before each unit: what you're
  sending. After each unit: what was built and discovered. The user
  should never be in the dark.
- **Codebase is source of truth.** .clawdance/ state can be stale.
  Code is real.
- **You loop, skills work.** Orchestrate phase skills. Don't implement.
- **Each invocation gets fresh context.** Controlled context boundaries.
- **Self-resolve during autonomous phases.** During build, derive answers
  from codebase, constraints, checkpoints. Don't interrupt the user for
  things derivable from context.
- **Recommendation-first at interactive phases.** Present judgment with
  reasoning. The user reacts, not evaluates.
- **Persist everything.** Files survive, conversations don't.
