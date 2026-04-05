# clawdance

Autonomous app development with cross-session constraint persistence.
A Claude Code plugin that takes you from idea to working product.

## Prerequisites

**Required:**
- [Claude Code](https://claude.ai/code)
- [oh-my-claudecode (OMC)](https://github.com/Yeachan-Heo/oh-my-claudecode)
  plugin — install globally so it's available in all projects:
  `/plugin marketplace add Yeachan-Heo/oh-my-claudecode`
  then `/plugin install oh-my-claudecode@oh-my-claudecode --scope user`

**For the session loop (unattended builds):**
- `tmux`
- `yq` (YAML processor)

**Optional (richer Telegram monitoring):**
- [clawhip](https://github.com/Gunther-Schulz/clawhip) — our fork with
  native Telegram sink. Not needed for basic Telegram (session loop has
  built-in curl-based notifications).

## Install

First time (inside Claude Code):

```
/plugin marketplace add Gunther-Schulz/clawdance
/plugin install clawdance@clawdance-marketplace
/reload-plugins
```

After pushing changes (from terminal):

```bash
cd ~/dev/Gunther-Schulz/clawdance
./update-plugin.sh
# then /reload-plugins in Claude Code
```

## Usage

### New project

```
/clawdance "Build me a task management app with real-time collaboration"
```

clawdance detects no code and no state — walks you through:

1. **Design** — clarifies your idea, proposes architecture, produces
   design artifacts (DESIGN.md, STACK.md, contracts). You review and
   approve.
2. **Decompose** — breaks design into implementable units with
   dependencies and parallelism. You review the task graph.
3. **Build** — executes units autonomously via OMC (ralph for single
   units, team for parallel groups). Writes checkpoints, discovers
   constraints.

### Existing project

```
/clawdance "Add real-time collaboration to this app"
```

clawdance detects existing source code — analyzes the codebase first:

1. **Analyze** — reads project structure, identifies components, discovers
   constraints from code patterns
2. **Human checkpoint** — "Here's what I see. Correct or redirect."
3. **Design the change** — what's new, what's modified, updated contracts
4. **Decompose + Build** — same as new project from here

### Resume after session death

```
/clawdance resume
```

Reads `.clawdance/` state and continues from where it left off. Sessions
can die at any point — rate limits, crashes, context exhaustion. No work
is lost.

### Check progress

```
/clawdance status
```

### Undo a unit

```
/clawdance rollback unit-003
```

### Automated loop (unattended)

```bash
./plugin/bin/clawdance-loop.sh /path/to/project
```

Spawns tmux sessions, monitors for death, restarts automatically. Backs
off after consecutive unproductive sessions.

## Commands

| Command | What it does |
|---|---|
| `/clawdance "Build me X"` | Start from idea — design, decompose, build |
| `/clawdance resume` | Continue after session death |
| `/clawdance status` | Read-only progress report |
| `/clawdance rollback unit-NNN` | Undo a unit, reset checkpoint |

## How it works

clawdance uses an orchestrator + phase skills architecture:

```
/clawdance "Build me X"
  → Orchestrator detects state, invokes phase skills:
    → Design skill (iterative: architecture → stack → contracts → validate)
    → Decompose skill (design → task graph)
    → Build skill (one unit per invocation, called repeatedly)
```

Each phase skill gets a fresh context per invocation. The orchestrator
manages the loop and transitions. State-driven:

| State | Mode |
|---|---|
| No code, no .clawdance/ | **New build** — design from scratch |
| Code exists, no .clawdance/ | **Init existing** — analyze codebase, then design the change |
| .clawdance/ exists | **Resume** — continue from current phase |

Across all phases, clawdance orchestrates four elements:

1. **Find problems** — pre-phase investigation, post-unit constraint
   review, data-flow tracing
2. **Resolve problems** — delegates to OMC for implementation and
   verification
3. **Persist what's learned** — constraints.yaml, checkpoints, state.yaml
   survive session death
4. **Human redirects** — review design and task graph at checkpoints,
   monitor progress, intervene when needed

## Telegram notifications

### Via session loop (built-in)

```bash
export CLAWDANCE_TELEGRAM_TOKEN="your-bot-token"
export CLAWDANCE_TELEGRAM_CHAT="your-chat-id"
./plugin/bin/clawdance-loop.sh /path/to/project
```

### Via clawhip (richer monitoring)

Our clawhip fork adds native Telegram support:

```toml
[providers.telegram]
bot_token = "your-bot-token"
default_chat_id = "your-chat-id"

[[routes]]
event = "session.*"
sink = "telegram"
```

## State files

All state lives in `.clawdance/` in your project:

| File | Purpose |
|---|---|
| `task-graph.yaml` | Units, dependencies, parallelism groups |
| `state.yaml` | Build progress, failure count |
| `constraints.yaml` | Cross-component invariants |
| `checkpoints/unit-NNN.yaml` | Per-unit completion records |

Everything lives under `.clawdance/` — one hidden directory, clean
project root. All files are human-readable and git-trackable.

## License

MIT
