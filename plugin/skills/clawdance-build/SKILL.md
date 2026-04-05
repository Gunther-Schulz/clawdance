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

**ALWAYS use ralph.** Never delegate directly to executor agents or other
OMC skills. Ralph is the only execution path verified to return control
to this skill for post-unit checkpointing. Direct agent invocation may
cause the session to end without writing checkpoints.

For trivial units (scaffolding, config), use `--no-prd` to skip the PRD
ceremony: `ralph --no-prd <prompt>`. Still goes through ralph's loop but
without story tracking overhead.

**Single unit:**
```
Skill(skill="oh-my-claudecode:ralph", args="<prompt>")
```

**Small/trivial unit:**
```
Skill(skill="oh-my-claudecode:ralph", args="--no-prd <prompt>")
```

**Parallel group (orchestrator handles team invocation):**
```
Skill(skill="oh-my-claudecode:team", args="N:executor <prompts>")
```

Wait for completion. Ralph exits via /cancel, control returns to this
skill for checkpointing.

### 6. Post-unit

a) **Write checkpoint** `.clawdance/checkpoints/unit-NNN.yaml` with
   these exact fields:
   ```yaml
   unit_id: unit-NNN
   status: completed          # completed | failed | partial
   completed_at: ISO-8601
   session_id: "..."
   tests_passing: true
   new_constraints: []        # constraints discovered during this unit
   notes: "..."
   ```

b) **Validate:** re-read checkpoint, verify fields present.

c) **Mine progress.txt:** read `.omc/progress.txt` for constraint
   discoveries. Deduplicate by description against constraints.yaml.

d) **Constraint review:** read `.clawdance/constraints.yaml`. Any existing
   constraints affected by this work? New cross-component invariants?
   
   New constraints use this exact format:
   ```yaml
   - id: c-NNN              # next available ID
     description: "..."     # NOT "rule" — use "description"
     affects: [component-a]
     added_by: unit-NNN
     discovered_by: unit_review  # unit_review | integration_test
     confidence: verified        # NOT "specified" — use "verified"
     created_at: YYYY-MM-DD
   ```
   
   Write new constraints DIRECTLY to `.clawdance/constraints.yaml` (not
   just to the checkpoint). The checkpoint's `new_constraints` field is
   a record of what was found, but constraints.yaml is the authoritative
   file that future units read. If you found constraints and wrote them
   to the checkpoint but not to constraints.yaml, they are invisible to
   the next unit.
   
   For parallel groups only: write to checkpoint `new_constraints` instead
   (merged by orchestrator after all parallel units complete).

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

## Transparency

Before invoking ralph, report to the user:
```
Building unit-NNN (name).
  Contracts: [list of contract files being read]
  Constraints: N active ([brief list of relevant ones])
  Mode: ralph [--no-prd if applicable]
```

After ralph completes and checkpoint is written, report:
```
Unit-NNN complete.
  Files created: [list]
  Tests: [pass/fail]
  New constraints: [count] ([brief description if any])
  Progress: N/M units done. Next: unit-NNN (name) [or "all complete"]
```

On constraint discovery, call it out explicitly:
```
New constraint: c-NNN "description"
  Added to constraints.yaml (discovered_by: unit_review)
```

## Principles

- **One unit per invocation.** The orchestrator manages the loop.
- **Hybrid injection.** Contract summaries + file paths, not full files.
- **Self-resolve.** Derive answers from codebase, STACK.md, constraints.
- **Persist everything.** Checkpoints, constraints — files survive.
