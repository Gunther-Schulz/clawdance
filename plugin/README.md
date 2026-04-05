# clawdance

Autonomous app development with cross-session constraint persistence.
A Claude Code plugin that orchestrates multi-session builds from design
artifacts to working product.

## Prerequisites

- [Claude Code](https://claude.ai/code)
- [oh-my-claudecode (OMC)](https://github.com/Yeachan-Heo/oh-my-claudecode) plugin installed
- `tmux` (for the session loop)
- `yq` (for the session loop to read YAML state)

## Install

```bash
git clone https://github.com/Gunther-Schulz/clawdance.git
cd clawdance
./update-plugin.sh
```

Then in Claude Code: `/reload-plugins`

### PreCompact hook

Add to your Claude Code `settings.json` (or the project's
`.claude/settings.json`):

```json
{
  "hooks": {
    "PreCompact": [{
      "type": "command",
      "command": "touch .clawdance/compact-signal"
    }]
  }
}
```

This lets the session skill detect when context is getting full and stop
gracefully.

## Quick start

### 1. Create design artifacts

In your project, create a `design/` directory:

```
design/
├── DESIGN.md      # Architecture overview, components, how they connect
├── STACK.md       # Tech stack, frameworks, testing approach
└── contracts/     # One file per inter-component interface
    ├── api-auth.yaml
    └── data-model.yaml
```

`DESIGN.md` — describe the components/services/modules and how they
connect. What depends on what.

`STACK.md` — tech stack choices, how to run tests, how to run integration
tests (docker compose, etc.).

`contracts/` — one file per interface between components. Format is
flexible (YAML, JSON, OpenAPI, markdown). Every inter-component interface
must have a contract.

### 2. Decompose

In Claude Code:

```
/clawdance-decompose design/
```

This reads your design artifacts and produces `.clawdance/`:
- `task-graph.yaml` — units of work with dependencies and parallelism
- `state.yaml` — build progress
- `constraints.yaml` — cross-component invariants (starts empty or seeded
  from design)
- `checkpoints/` — completion records per unit

### 3. Review

Read `.clawdance/task-graph.yaml`. Check:
- Are the units right? Too big? Too small?
- Are dependencies correct?
- Are parallel groups sensible?
- Did the decomposer flag any missing contracts?

Optionally seed `.clawdance/constraints.yaml` with invariants you already
know about.

### 4. Build

**Manual (step-by-step):**
```
/clawdance resume
```
Re-run after each session ends. The skill reads state and continues from
where it left off.

**Full auto (no review step):**
```
/clawdance-build design/
```
Decomposes and builds in one shot.

**Automated loop (unattended):**
```bash
./plugin/bin/clawdance-loop.sh /path/to/project
```
Spawns tmux sessions, monitors for death, restarts automatically. Backs
off after consecutive unproductive sessions.

### 5. Monitor

- `/clawdance status` — progress report in Claude Code
- `cat .clawdance/state.yaml` — raw state
- Telegram notifications (see below)

## Commands

| Command | What it does |
|---|---|
| `/clawdance resume` | Continue the build from where it left off |
| `/clawdance status` | Read-only progress report |
| `/clawdance rollback unit-NNN` | Undo a unit, reset checkpoint |
| `/clawdance-decompose [dir]` | Design artifacts → task graph |
| `/clawdance-build [dir]` | Decompose + build in one shot |

## How it works

clawdance orchestrates four elements across session boundaries:

1. **Find problems** — pre-phase investigation, post-unit constraint
   review, data-flow tracing
2. **Resolve problems** — delegates to OMC (ralph for single units, team
   for parallel groups) for implementation and verification
3. **Persist what's learned** — constraints.yaml, checkpoints, state.yaml
   survive session death
4. **Human redirects** — review task graph after decomposition, monitor
   progress, intervene when needed

Sessions can die at any point (rate limits, crashes, context exhaustion).
The next session reads `.clawdance/` state and continues. No work is lost.

## Telegram notifications

### Via session loop (built-in)

Set environment variables before running the loop:

```bash
export CLAWDANCE_TELEGRAM_TOKEN="your-bot-token"
export CLAWDANCE_TELEGRAM_CHAT="your-chat-id"
./plugin/bin/clawdance-loop.sh /path/to/project
```

### Via clawhip (richer monitoring)

Our clawhip fork adds native Telegram support. Configure in
`clawhip.toml`:

```toml
[providers.telegram]
bot_token = "your-bot-token"
default_chat_id = "your-chat-id"

[[routes]]
event = "session.*"
sink = "telegram"
```

This gives you clawhip's keyword scanning, stale detection, and event
filtering for Telegram alongside Discord/Slack.

## Cross-component constraints

clawdance tracks cross-component invariants in `.clawdance/constraints.yaml`.
The plugin injects this convention into every Claude Code session:

- Before starting work: read constraints that affect your components
- After completing work: check for new cross-component invariants
- When integration tests fail: add the missing constraint

This prevents the validated failure mode where session boundaries cause
integration bugs through lost constraints.

## State files

All state lives in `.clawdance/` in your project:

| File | Purpose |
|---|---|
| `task-graph.yaml` | Units, dependencies, parallelism groups |
| `state.yaml` | Build progress, failure count |
| `constraints.yaml` | Cross-component invariants |
| `checkpoints/unit-NNN.yaml` | Per-unit completion records |

These files are human-readable and git-trackable. They persist across
sessions, crashes, and rate limits.

## License

MIT
