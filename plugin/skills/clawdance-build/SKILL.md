---
name: clawdance-build
description: Build phase skill — handles one unit or parallel group per invocation. Reads state, prepares context, invokes ralph/team, writes checkpoint, reviews constraints. Called by the orchestrator repeatedly.
argument-hint: "[unit-NNN or automatic]"
---

# clawdance-build — Build Phase

You handle one unit (or one parallel group) per invocation. Read state,
prepare context, delegate to OMC for implementation, write checkpoint,
review constraints. The orchestrator calls you repeatedly for each unit.

## Steps

### 1. Read state

Read `.clawdance/state.yaml` and `.clawdance/checkpoints/`. If this is
the first build invocation (status: pending), set status to in_progress.

### 2. Check stop signals

- `.clawdance/compact-signal` exists → delete it, report "Context full."
  Return to orchestrator.
- Orchestrator told you a specific unit → use that.
- Otherwise: pick the next ready unit (see step 3).

### 3. Pick unit

Read `.clawdance/task-graph.yaml`. Find units in `units_remaining` whose
`depends_on` are all in `units_completed`.

- Parallel group fully ready → report to orchestrator that team mode is
  needed (provide all units in group)
- Single unit ready → proceed with it
- Nothing ready → report blocked to orchestrator

### 4. Prepare context (hybrid injection)

Read the unit's `contracts_read` files. For each:
- Extract key interface definitions (not full file if large)
- Note full file path for reference

Read `.clawdance/constraints.yaml`.

Build the prompt:
```
Implement [unit name]: [unit description]

## Contracts (conform to these)
### [name] (full file: [path])
[key interface definitions]

## Constraints (do not violate)
[constraints.yaml content]

## Notes
- Record cross-component invariants in progress.txt.
- When creating a cross-component connection, write an integration test.
- If you need full contract details, read the file paths above.
```

### 5. Execute

**Single unit:**
```
Skill(skill="oh-my-claudecode:ralph", args="<prompt>")
```

**Parallel group (orchestrator handles team invocation):**
```
Skill(skill="oh-my-claudecode:team", args="N:executor <prompts>")
```

Wait for completion. Ralph exits via /cancel, control returns.

### 6. Post-unit

a) **Write checkpoint** `.clawdance/checkpoints/unit-NNN.yaml` — all
   required fields.
b) **Validate:** re-read checkpoint, verify fields.
c) **Mine progress.txt:** read `.omc/progress.txt` for constraint
   discoveries. Deduplicate by description.
d) **Constraint review:** read constraints.yaml. Any existing constraints
   affected by this work? New cross-component invariants? Add with
   `discovered_by: unit_review`. For parallel groups, write to
   checkpoint `new_constraints` instead.
e) **Update state.yaml:** move unit to completed (or failed), reset
   `consecutive_failures` to 0. Validate after write.

### 7. Sweep check

"Is state consistent? Anything look wrong? Any loose ends?"
Fix before returning to orchestrator.

### 8. All units complete

If no units remain in `units_remaining`:
1. Run full-stack integration tests per `.clawdance/design/STACK.md`
2. If tests fail: identify missing constraint, add with
   `discovered_by: integration_test`. Mark relevant unit failed, move
   to remaining. Report to orchestrator.
3. If tests pass: set state.yaml `status: completed`. Report done.

## Principles

- **One unit per invocation.** The orchestrator manages the loop.
- **Hybrid injection.** Contract summaries + file paths, not full files.
- **Self-resolve.** Derive answers from codebase, STACK.md, constraints.
- **Persist everything.** Checkpoints, constraints — files survive.
