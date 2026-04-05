# checkpoints/unit-NNN.yaml Schema

Version 1. Development reference for `.clawdance/checkpoints/` files.

## Purpose

One file per completed (or failed/partial) unit. Records what happened,
what was produced, and what constraints were discovered. The session skill
reads these to determine progress; the session loop infers productivity
from timestamps.

## Schema

```yaml
unit_id: unit-001                    # Required. Matches task-graph unit ID.
status: completed                    # Required. completed | failed | partial.
completed_at: 2026-04-05T14:30:00Z   # Required. ISO-8601 timestamp.
session_id: "abc123"                 # Required. Claude Code session ID.
branch: "unit-001/db-schema"         # Optional. Git branch for this unit's work.
tests_passing: true                  # Required. Did per-component tests pass?
integration_tests:                   # Optional. Cross-component tests written.
  - "test/integration/db-api.test.ts"
new_constraints:                     # Optional. Constraints discovered during
  - id: c-003                        # this unit. Merged into constraints.yaml
    description: "..."               # by the session skill after unit completion
    affects: [component-a]           # (or after parallel group completion).
    discovered_by: unit_review
notes: "Added migration for users"   # Optional. Summary of what was done.
errors: []                           # Optional. Error details if failed/partial.
```

## Status values

- **completed** — unit finished, tests pass, checkpoint is final.
  Session skill resets consecutive_failures to 0 in state.yaml.
- **failed** — unit failed after ralph retries. Errors field has details.
  Session skill increments consecutive_failures.
- **partial** — session died mid-unit. Ralph's prd.json may have sub-unit
  progress. Next session retries — ralph reads existing prd.json and
  resumes from last completed story.

## new_constraints

How parallel agents report constraint discoveries without conflicting on
constraints.yaml. Each agent writes to its own checkpoint. After parallel
units complete, the session skill:
1. Reads new_constraints from all checkpoints in the group
2. Deduplicates by description
3. Merges into constraints.yaml
4. Assigns IDs (next available c-NNN)
