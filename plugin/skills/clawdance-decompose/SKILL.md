---
name: clawdance-decompose
description: Decompose design artifacts into a task graph. Reads .clawdance/design/, produces .clawdance/ with task-graph.yaml, state.yaml, constraints.yaml. Called by the orchestrator after design is complete.
argument-hint: "[path to .clawdance/design/ directory, default: .clawdance/design/]"
---

# clawdance-decompose — Decomposition Phase

Read design artifacts, produce a task graph for autonomous implementation.
Called once by the orchestrator after the design phase is complete.

## Steps

### 1. Read design artifacts

Read `.clawdance/design/DESIGN.md`, `.clawdance/design/STACK.md`, and all files in
`.clawdance/design/contracts/`. Understand components, connections, tech stack, and
testing approach.

### 2. Identify units

Each component/service/module is a candidate unit. A unit should be:
- Implementable and testable independently
- One component or feature
- Completable in one session (~30-50% of context)

### 3. Map dependencies and parallelism

- `depends_on`: which units must complete first (data model before API, etc.)
- `parallel_group`: units with same dependencies and no inter-dependency
  get the same group name (executed via OMC team mode)

### 4. Map contracts

For each unit:
- `contracts_read`: contract files to read before implementing
- `contracts_produced`: files this unit creates that others need

### 5. Validate

- Every inter-component interface has a contract in `.clawdance/design/contracts/`.
  **If missing: STOP and report the gap.** Do not guess.
- Unit size heuristics: >10 files? >2 component boundaries? Multiple
  independent features? → split.
- No circular dependencies.

### 6. Produce .clawdance/

Create `.clawdance/` with:

**task-graph.yaml** — units with all fields (id, name, description,
depends_on, contracts_read, contracts_produced, parallel_group).

**state.yaml** — status: pending, all units in units_remaining.

**constraints.yaml** — seed with design-phase constraints if visible
(things like "all services must use the same auth scheme"). Use
`discovered_by: design`.

**checkpoints/** — empty directory.

Validate: re-read task-graph.yaml, verify all fields, verify contracts
exist on disk, verify no circular dependencies.

### 7. Report

Present the task graph summary: N units, M parallel groups, dependency
chain depth, any concerns about sizing. Recommend proceeding or
adjustments needed.
