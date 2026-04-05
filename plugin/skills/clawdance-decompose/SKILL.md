---
name: clawdance-decompose
description: Decompose design artifacts into a task graph for autonomous implementation. Reads design/ directory, produces .clawdance/ state. Validates contracts exist and unit sizes are reasonable.
argument-hint: "[path to design/ directory, default: design/]"
---

# clawdance-decompose — Task Graph Decomposer

You read design artifacts and produce a task graph that the clawdance
session skill can execute autonomously. Your job is decomposition, not
implementation.

## Required input

The design directory must contain:

```
design/
├── DESIGN.md      # Required: architecture overview, component breakdown
├── STACK.md       # Required: tech stack, testing approach, integration
│                  #   test strategy
└── contracts/     # Required: one file per inter-component interface
    ├── *.yaml     # API schemas, data models, protocols
    └── ...        # Format flexible (YAML, JSON, OpenAPI, markdown)
```

If any required file is missing, report what's missing and stop. Do not
guess.

## Steps

### 1. Read design artifacts

Read `design/DESIGN.md`, `design/STACK.md`, and all files in
`design/contracts/`. Understand:
- What components/services/modules make up the system
- How they connect (which interfaces exist between them)
- What tech stack is used (languages, frameworks, databases)
- How integration tests should be run

### 2. Identify units

From DESIGN.md, identify the distinct implementable components. Each
component is a candidate unit. A unit should be:
- Implementable and testable independently
- Focused on one component or feature
- Completable in one session (~30-50% of context window)

### 3. Map dependencies

For each unit, determine what must be built before it:
- Data model/schema before API endpoints
- Backend before frontend (if frontend consumes backend API)
- Shared libraries before consumers
- Infrastructure (database, auth) before application logic

Dependencies must be explicit unit IDs in `depends_on`. No implicit
ordering.

### 4. Map contracts

For each unit:
- `contracts_read`: which contract files must be read before implementing.
  Every inter-component interface the unit touches must have a contract.
- `contracts_produced`: files this unit creates that other units need.
  Typically only infrastructure units produce contracts (e.g., database
  schema that API units read).

### 5. Identify parallel groups

Units that have the same dependencies and no dependencies on each other
can run in parallel. Assign them the same `parallel_group` name. Common
patterns:
- Multiple independent API endpoints → group "api"
- Frontend + backend when both depend on shared schema → group "app"
- Independent microservices → group "services"

Units with `null` parallel_group run individually when their dependencies
are met.

### 6. Validate

**Contract completeness:** Every inter-component interface must have a
contract file in `design/contracts/`. For each pair of units that have
a dependency relationship, verify a contract exists that defines their
interface. If a contract is missing: **STOP and report the gap.** List
exactly which interface between which components lacks a contract. Do
not produce a task graph with gaps.

**Unit size heuristics:** Review each unit:
- Likely touches more than ~10 files? Consider splitting.
- Crosses more than 2 component boundaries? Consider splitting.
- Description contains multiple independent features? Must split.

If splitting, create sub-units with appropriate dependencies.

### 7. Produce .clawdance/ state

Create the `.clawdance/` directory with:

**task-graph.yaml:**
```yaml
version: 1
units:
  - id: unit-001
    name: "..."
    description: "..."
    depends_on: []
    contracts_read: [...]
    contracts_produced: [...]
    parallel_group: null
  # ... more units
```

**state.yaml:**
```yaml
version: 1
status: pending
current_unit: null
units_completed: []
units_failed: []
units_remaining: [unit-001, unit-002, ...]  # All unit IDs
last_session_id: null
last_checkpoint_at: null
consecutive_failures: 0
error: null
```

**constraints.yaml** — preserve if it already exists (may contain
design-phase constraints). Create empty if not:
```yaml
version: 1
constraints: []
```

**checkpoints/** — create empty directory.

**Validate:** Re-read task-graph.yaml. Verify all units have required
fields. Verify all `contracts_read` files exist on disk. Verify all
`depends_on` reference valid unit IDs. Verify no circular dependencies.

### 8. Seed design-phase constraints

Read through the design artifacts one more time. Are there cross-component
invariants already visible in the design? Examples:
- "Service A and B must use the same authentication scheme"
- "All API endpoints must return paginated results per the pagination contract"
- "The database schema uses UUIDs — all services must generate UUIDs, not integers"

Add any found to constraints.yaml with `added_by: design` and
`discovered_by: design`.

### 9. Report

Present a summary for human review:
- N units, M parallel groups, dependency chain depth
- Unit list with estimated complexity (small/medium/large)
- Constraints seeded from design (if any)
- Any concerns: thin contracts, potentially oversized units, unusual
  dependency patterns
- Recommendation: "This looks ready for `/clawdance resume`" or
  "These issues should be addressed first: [specific]"

Present as a recommendation, not a question. The human approves or
redirects.
