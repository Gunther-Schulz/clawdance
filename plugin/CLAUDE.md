# clawdance — Cross-component constraint persistence

## Cross-component constraints

This project may track cross-component invariants in
`.clawdance/constraints.yaml`. If this file exists:

- **Before starting any unit of work:** read `.clawdance/constraints.yaml`.
  Check if any constraints affect the components you're about to modify.
  Each constraint lists which components it `affects` — if the current work
  touches any of those components, the constraint applies to you.

- **After completing a unit of work:** review `.clawdance/constraints.yaml`.
  Are any existing constraints affected by what was just built? Were
  discover new cross-component invariants — things that would break if
  another component doesn't know about them? Add new constraints with
  `discovered_by: unit_review`.

- **When an integration test reveals a missing constraint:** add it with
  `discovered_by: integration_test`. This tracks which discovery mechanism
  catches which constraints, allowing the process to self-improve over time.

- **When modifying a component:** check all constraints where that component
  appears in the `affects` list. If a change would violate a constraint,
  either respect it or update the constraint with reasoning.

## Constraint format

```yaml
constraints:
  - id: c-NNN
    description: "Human-readable description of the invariant"
    affects: [component-a, component-b]
    added_by: unit-NNN        # or "design" or "init"
    discovered_by: unit_review # design | init | unit_review | integration_test
    confidence: verified       # inferred (from analysis) | verified (confirmed by implementation)
    created_at: YYYY-MM-DD
```
