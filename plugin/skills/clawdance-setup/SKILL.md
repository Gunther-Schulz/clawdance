---
name: clawdance-setup
description: Set up a project for clawdance autonomous builds. Creates the design/ directory structure, scaffolds templates, and verifies prerequisites. Run this once per project before using /clawdance-decompose.
argument-hint: "[--check]"
---

# clawdance-setup — Project Setup

Set up this project for autonomous builds with clawdance. Creates the
design artifact structure and verifies everything is ready.

If `--check` is passed, only verify prerequisites without creating files.

## Steps

### 1. Verify prerequisites

Check that the following are available:

- **OMC plugin loaded:** Try to confirm oh-my-claudecode is available
  (check if `/oh-my-claudecode:omc-help` is a recognized skill, or check
  for `.omc/` or OMC-related CLAUDE.md content). If not found, report:
  "OMC plugin not detected. Install oh-my-claudecode first."

- **PreCompact hook:** Read the project's `.claude/settings.json` or the
  global settings for a PreCompact hook that runs
  `touch .clawdance/compact-signal`. If not found, report:
  "PreCompact hook not configured. Run update-plugin.sh or add manually."

If `--check` was passed, report status and stop.

### 2. Create design directory

If `design/` doesn't exist, create it with template files:

**design/DESIGN.md:**
```markdown
# Architecture

## Components

<!-- List the components/services/modules of your application -->
<!-- For each: what it does, what it depends on, what interface it exposes -->

## Data flow

<!-- How does data move through the system? -->
<!-- Which component produces data, which consumes it? -->

## Deployment

<!-- How is this deployed? Single binary? Docker compose? Kubernetes? -->
```

**design/STACK.md:**
```markdown
# Tech Stack

## Languages and frameworks

<!-- What languages, frameworks, and libraries does this project use? -->

## Database

<!-- What database(s)? Schema management approach? -->

## Testing

### Unit tests
<!-- How to run unit tests -->

### Integration tests
<!-- How to run integration tests -->
<!-- Docker compose? In-process? Contract testing? -->

## Build and run

<!-- How to build and run the project -->
```

**design/contracts/** — create the directory with a README:

```markdown
# Contracts

One file per inter-component interface. Format is flexible:
YAML, JSON Schema, OpenAPI, or markdown.

Every interface between components must have a contract here.
The decomposer will verify this before producing a task graph.

Example:
- api-auth.yaml — Authentication API contract
- data-model.yaml — Shared database schema
- event-bus.yaml — Event/message format between services
```

### 3. Check for existing state

If `.clawdance/` already exists, report its status:
- Read `state.yaml` — is there an in-progress or completed build?
- Report: "Existing clawdance state found. Status: [status]. Use
  `/clawdance resume` to continue or delete `.clawdance/` to start fresh."

### 4. Report

Summarize what was created and what to do next:

```
clawdance setup complete.

Created:
  design/DESIGN.md      — fill in your architecture
  design/STACK.md       — fill in your tech stack and testing approach
  design/contracts/     — add one file per inter-component interface

Next steps:
  1. Fill in the design artifacts
  2. Run /clawdance-decompose design/
  3. Review .clawdance/task-graph.yaml
  4. Run /clawdance resume
```

Present as a recommendation. If design/ already existed, note which files
were skipped (don't overwrite existing work).
