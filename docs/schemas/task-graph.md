# task-graph.yaml Schema

Version 1. Development reference for `.clawdance/task-graph.yaml`.

## Purpose

Defines the units of work, their dependencies, contract references, and
parallelism groups. Produced by the decomposer, consumed by the session
skill.

## Schema

```yaml
version: 1

units:
  - id: unit-001                     # Required. Format: unit-NNN.
    name: "Database schema"          # Required. Human-readable name.
    description: "Create Postgres    # Required. What to implement.
      schema per DESIGN.md"
    depends_on: []                   # Required. List of unit IDs.
                                     # Empty = no dependencies.
    contracts_read:                   # Required. Files to read before
      - design/contracts/data.yaml   # implementing. Can be empty.
    contracts_produced:              # Optional. Files this unit creates
      - design/contracts/db.sql      # that other units depend on.
    parallel_group: null             # Optional. Units with the same
                                     # group name can run concurrently.
                                     # null = no grouping constraint.
```

## Field details

### id

Format: `unit-NNN` (zero-padded three digits). Assigned by the decomposer.
IDs determine checkpoint filenames (`checkpoints/unit-NNN.yaml`).

### depends_on

List of unit IDs that must complete before this unit can start. The session
skill resolves dependencies by checking which units have checkpoints with
`status: completed`. A unit is ready when all its depends_on entries have
completed checkpoints.

### contracts_read

Files the agent MUST read before implementing this unit. The session skill
reads these files, extracts key interface definitions, and inlines
summaries into the ralph prompt (hybrid injection — summaries + file paths).

### contracts_produced

Files this unit creates that other units may reference in their
contracts_read. Used by the decomposer to order dependencies correctly.

### parallel_group

Units with the same parallel_group value can run concurrently via OMC team
mode. The session skill collects all ready units in a group and invokes
team mode with N agents. Units with `null` have no grouping constraint and
run when their dependencies are met.

## Dependency resolution

The session skill picks the next unit(s) to execute:

1. Read all checkpoints — build set of completed unit IDs
2. For each unit in task-graph: check if all depends_on are in completed set
3. If a parallel_group has all its units ready: execute as a group (team mode)
4. Otherwise: pick the single next ready unit (ralph)
5. If no units are ready and some are remaining: blocked (dependency not met — error)
