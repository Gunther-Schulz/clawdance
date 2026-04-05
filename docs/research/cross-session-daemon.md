# Cross-Session Daemon

Research conducted 2026-04-05. Analysis of the need for and design of a
daemon that operates above individual Claude Code sessions.

## The problem

OMC operates inside a Claude Code session. It's a plugin — it loads when a
session starts and dies when the session dies. It orchestrates brilliantly
within a session but cannot:

- Spawn new Claude Code sessions (it IS a session)
- Survive a session crash (it crashes with it)
- Coordinate between independent sessions (no shared state)
- Manage a work backlog that outlives any single session

clawhip monitors sessions and routes notifications but does not make
decisions or spawn sessions. It's plumbing, not a brain.

## When multiple sessions are needed

Sessions have finite lives due to:
- **Context window exhaustion** — even with compaction, complex builds fill
  the context. After compaction, agents lose earlier design decisions.
- **Rate limits** — 5-hour usage caps on API plans. Session is dead until
  reset.
- **Crashes** — network drops, OOM, terminal closed, auth expiry.
- **Time** — a real app build may take longer than one session can sustain.

For small apps built in one session, this may not matter. For anything
larger, sessions will end before the work is done.

## What a daemon would do

A process that runs above Claude Code sessions:

**Work backlog → session dispatch:**
Pulls from a queue (GitHub issues, YAML backlog, directives) and spawns
Claude Code sessions (with OMC loaded) to work on them.

**Session health monitoring:**
Subscribes to clawhip's event stream. Session died? Spawns a replacement
with the same task context.

**Multi-session coordination:**
Knows which sessions are working on what. Holds a session if its work
depends on another session finishing first. Manages merge order.

**Concurrency management:**
Manages a session pool. Too many running? Queue the next one. Rate
limited? Back off. Session finished? Pull next item from backlog.

## Architecture

```
[User / GitHub Issues / Backlog]
         |
[Cross-session daemon]          <-- we build this
  - Manages work queue
  - Spawns Claude Code sessions
  - Monitors health via clawhip events
  - Restarts failed sessions
  - Manages concurrency
         |                    ^
[Claude Code + OMC]        [clawhip]
  - In-session orchestration   - Event routing
  - Task decomposition         - Notifications
  - Parallel agents            - Session lifecycle events
  - Review pipeline
```

## Open questions

1. **Is this actually needed?** For small-to-medium apps, a single session
   with OMC might suffice. The daemon becomes relevant only when builds
   exceed one session. This should be validated by trying OMC on a real
   project first.

2. **Session resumption mechanism.** When a session dies and a replacement
   is spawned, how does the new session know where the old one left off?
   Options: structured checkpoint files on disk, .omc/ project state,
   or a combination. See challenges.md mitigations.

3. **Scope.** Should the daemon be a full job queue system, or just a
   lightweight "restart on failure" watcher? Start minimal.

4. **Integration with clawhip.** clawhip provides the event stream. The
   daemon subscribes and reacts. Does it also emit events back to
   clawhip (daemon.spawned_session, daemon.restarted_session)?

## Current assessment

We're not sure this is needed yet. The goal (app idea → product) might
be achievable within single sessions for the project sizes we care about.
This is deferred until we validate OMC on a real project and find out
whether session boundaries are actually a problem in practice.
