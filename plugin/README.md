# clawdance

Autonomous app development with cross-session constraint persistence.
A Claude Code plugin that takes you from idea to working product.

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

The install script registers the marketplace and installs the plugin
(including hooks). Then in Claude Code: `/reload-plugins`

## Usage

### Start a new build

```
/clawdance "Build me a task management app with real-time collaboration"
```

clawdance detects that no design exists and walks you through:

1. **Design** — clarifies your idea, proposes architecture, produces
   design artifacts (DESIGN.md, STACK.md, contracts). You review and
   approve.
2. **Decompose** — breaks design into implementable units with
   dependencies and parallelism. You review the task graph.
3. **Build** — executes units autonomously via OMC (ralph for single
   units, team for parallel groups). Writes checkpoints, discovers
   constraints.

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

| State | Phase |
|---|---|
| No design, no build state | Design — iterative, increasing resolution |
| Design exists, no build state | Decompose — design → task graph |
| Task graph pending | Review task graph, start building |
| Build in progress | Resume from last checkpoint |
| Build completed | Report done |

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

Design artifacts live in `design/`:

| File | Purpose |
|---|---|
| `DESIGN.md` | Architecture, components, data flow |
| `STACK.md` | Tech stack, testing approach |
| `contracts/` | One file per inter-component interface |

All files are human-readable and git-trackable.

## License

MIT
