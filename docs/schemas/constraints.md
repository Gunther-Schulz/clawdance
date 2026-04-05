# constraints.yaml Schema

Version 1. The authoritative format for `.clawdance/constraints.yaml`.

## Purpose

Tracks cross-component invariants that must be maintained across sessions.
Prevents the validated failure mode where session boundaries cause
integration bugs through lost constraints (see research/real-world-validation.md).

## Schema

```yaml
version: 1

constraints:
  - id: c-001                       # Required. Unique, auto-incrementing.
    description: "..."               # Required. Human-readable invariant.
    affects: [component-a, ...]      # Required. Components that must respect this.
    added_by: unit-001               # Required. Unit that discovered it, or "design".
    discovered_by: unit_review       # Required. One of:
                                     #   design — identified during design phase
                                     #   unit_review — found by post-unit review
                                     #   integration_test — found by integration test failure
    created_at: 2026-04-05           # Required. ISO date.
```

## Field details

### id

Format: `c-NNN` where NNN is auto-incrementing. The session skill assigns
the next available ID when adding a constraint. IDs are never reused.

### description

A human-readable description of the invariant. Should be specific enough
that an agent reading it knows exactly what to do. Examples:

- Good: "Every new MCP tool must be added to the allowlist in gateway/config.go"
- Good: "audit-sink gRPC server has no compression — exporters must not enable gzip"
- Bad: "Be careful with the gateway config"
- Bad: "Check compression settings"

### affects

List of component names that must respect this constraint. When an agent
modifies any component in this list, it must check this constraint.
Component names should match the unit names or component names used in
the task graph.

### added_by

Which unit discovered this constraint, or "design" if it was identified
during the design phase (step 2 of the product workflow). Used for
traceability — knowing which unit introduced a constraint helps when
debugging or when the constraint needs updating.

### discovered_by

How the constraint was discovered. Tracks effectiveness of the discovery
mechanisms:

- `design` — identified during design phase, before implementation began
- `unit_review` — found by the post-unit constraint review step ("what
  constraints does this impose on other components?")
- `integration_test` — found when an integration test failed and the
  missing constraint was identified as the root cause

Over time, the ratio of `unit_review` to `integration_test` discoveries
shows whether the review step is effective. If integration tests keep
catching things the review misses, the review prompt needs refinement.

### created_at

ISO date when the constraint was added. Used for temporal context — older
constraints may need re-evaluation as the codebase evolves.

## Empty file

A project with no constraints yet:

```yaml
version: 1
constraints: []
```

## Deduplication

When adding a constraint, check if one with the same description already
exists. Duplicate descriptions indicate the same invariant was discovered
twice (e.g., from progress.txt mining and from the post-unit review).
Skip the duplicate.

## Lifecycle

- Created by the decomposer (empty or seeded with design-phase constraints)
- Read by the session skill before each unit
- Updated by the session skill after each unit (post-unit review)
- Updated after integration test failures
- Survives build completion — useful for ongoing maintenance
- Future sessions in the same project read it for constraint awareness
  (via plugin CLAUDE.md)
