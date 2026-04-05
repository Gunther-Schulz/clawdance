# state.yaml Schema

Version 1. Development reference for `.clawdance/state.yaml`.

## Purpose

High-level build progress. Read by the session loop to decide whether to
spawn a new session. Read by the session skill to determine what's done
and what's next. Read by `/clawdance status` for progress reporting.

## Schema

```yaml
version: 1                           # Required. Schema version.
status: in_progress                  # Required. pending | in_progress |
                                     # completed | failed.
current_unit: unit-002               # Optional. Unit currently being worked on.
                                     # null when between units or not started.
units_completed:                     # Required. List of completed unit IDs.
  - unit-001
units_failed: []                     # Required. List of failed unit IDs.
units_remaining:                     # Required. List of units not yet attempted.
  - unit-002
  - unit-003
last_session_id: "abc123"            # Optional. Most recent session ID.
last_checkpoint_at:                  # Optional. Timestamp of last checkpoint.
  2026-04-05T14:30:00Z               # Used by session loop to detect
                                     # productive vs unproductive sessions.
consecutive_failures: 0              # Required. Incremented by session loop
                                     # when a session produces no checkpoint.
                                     # Reset to 0 by session skill when a
                                     # checkpoint IS written.
error: null                          # Optional. Error description when
                                     # status is failed.
```

## Status transitions

```
pending ──► in_progress ──► completed
                │
                ├──► failed (after max retries or unrecoverable error)
                │
                └──► in_progress (continues after session restart)
```

- `pending` → `in_progress`: session skill sets this on first run
- `in_progress` → `completed`: session skill sets when all units complete
  and full-stack integration tests pass
- `in_progress` → `failed`: session skill sets when a unit fails and
  no forward progress is possible (all remaining units depend on the
  failed one, or consecutive_failures exceeds threshold)

## consecutive_failures

Tracks unproductive sessions for the rate-limit-aware session loop:

- **Session loop increments** when a session ends and `last_checkpoint_at`
  hasn't changed (no new checkpoint = unproductive session)
- **Session skill resets to 0** when writing a checkpoint (productive work)
- **Session loop backs off** when consecutive_failures >= MAX_FAILURES
  (default 3). Delay between retries: 30s x failure count.

This handles rate limits, crashes, and context exhaustion uniformly —
all look like "unproductive session" from the loop's perspective.
