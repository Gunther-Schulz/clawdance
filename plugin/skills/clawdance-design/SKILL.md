---
name: clawdance-design
description: This skill should be used when the orchestrator needs to "design architecture", "create contracts", "define tech stack", or "validate design". Handles one aspect of design per invocation at increasing resolution.
argument-hint: "<idea or focus area>"
---

# clawdance-design — Design Phase

Handle one focused aspect of design per invocation. Read what exists,
do focused work, write results to `.clawdance/design/`. The orchestrator calls
you multiple times at increasing resolution.

## Detect focus

Based on what exists and what the orchestrator asked for:

| State | Focus |
|---|---|
| Orchestrator says "analyze" + source code exists | Analyze — reverse-engineer existing codebase |
| No `.clawdance/design/` at all + user idea provided | Architecture — full initial design |
| `.clawdance/design/DESIGN.md` exists, no `STACK.md` | Stack — tech stack and testing |
| `.clawdance/design/DESIGN.md` + `STACK.md` exist, contracts incomplete | Contracts — specific interface |
| All artifacts exist | Validate — coherence check |
| Orchestrator specified a focus | That specific focus |

## Analyze focus (existing projects)

When the orchestrator invokes this skill in analyze mode, the project already has
source code. The job: understand what exists and produce design artifacts
that describe the CURRENT system, not a new design.

### Read the codebase (targeted, not exhaustive)

- Read project structure: directory layout, package files (package.json,
  go.mod, Cargo.toml, pyproject.toml, etc.), entry points
- Identify components: what are the distinct modules/services/packages?
- Identify connections: how do components talk to each other? (imports,
  API calls, shared databases, message queues)
- Identify tech stack: languages, frameworks, databases, testing tools

Don't read every file. Read structure + key files (entry points, config,
main modules). For a specific feature request, focus on the area that
feature will touch.

### Produce design artifacts

Write `.clawdance/design/DESIGN.md` describing what EXISTS:
- Components and their responsibilities (as they ARE, not as you'd design)
- How they connect (actual data flow, not ideal)
- Dependencies between them

Write `.clawdance/design/STACK.md` from actual tech stack:
- Actual languages, frameworks, libraries in use
- How tests are actually run (read package.json scripts, Makefile, etc.)
- How the project is actually built and run

Write `.clawdance/design/contracts/` for existing inter-component
interfaces. These may be implicit — extract them from actual code
(API routes, shared types, database schemas).

### Seed constraints

Read codebase patterns and seed `.clawdance/constraints.yaml` with
discovered invariants. Examples:
- "All API routes use the auth middleware"
- "Database queries go through the ORM, never raw SQL"
- "Frontend expects paginated responses from all list endpoints"

These get `discovered_by: init` and `confidence: inferred`. The build
skill upgrades to `verified` when it confirms them during implementation.

### Report

Present the findings: "Here's the architecture I see. [summary].
[N] constraints discovered." The human corrects or approves.

## Architecture focus

When creating the initial design from a user's idea:

### Understand the idea

If the user's idea is vague, ask clarifying questions:
- What is the core product/feature?
- Who uses it?
- What are the key user-facing behaviors?
- What's MVP vs future?

Keep it conversational. 2-4 rounds of clarification is typical. Don't ask
all questions at once.

### Propose and write

Produce `.clawdance/design/DESIGN.md`:
- Components/services/modules and their responsibilities
- How components connect (which calls which, data flow direction)
- Dependencies between components (what must exist before what)
- Key architectural decisions with rationale

Present as a recommendation: "Here's the architecture I'd use. [reasoning]"
The user approves or redirects.

## Stack focus

Produce `.clawdance/design/STACK.md`:
- Languages, frameworks, libraries (with rationale)
- Database and schema management approach
- How to run unit tests
- How to run integration tests (docker compose, in-process, etc.)
- How to build and run the project

Read `.clawdance/design/DESIGN.md` first — the stack must serve the architecture.

## Contracts focus

For a specific inter-component interface, produce a contract file in
`.clawdance/design/contracts/`:
- API contracts: endpoints, methods, request/response shapes, error codes
- Data model contracts: schemas, shared types, field definitions
- Event contracts: message formats, topics, delivery guarantees

Read `.clawdance/design/DESIGN.md` to understand the interface. The contract must be
specific enough that two agents implementing each side independently would
produce compatible code.

Format is flexible (YAML, JSON Schema, OpenAPI, markdown). Name the file
after the interface it describes.

## Validate focus

Read ALL design artifacts: DESIGN.md, STACK.md, all contracts. Check:

- Does every component-to-component connection in DESIGN.md have a
  corresponding contract file?
- Does STACK.md align with the architecture (right tools for the job)?
- Do contracts reference entities that exist in the data model?
- Trace data flow through the system: can data get from producer to
  consumer through the documented interfaces?

If gaps found: report them specifically. The orchestrator will invoke
another design pass to fix them.

If coherent: report "Design is complete and coherent. Ready for
decomposition."

## Principles

- **One focus per invocation.** Don't try to do everything at once. The
  orchestrator calls this skill multiple times.
- **Read before writing.** Always read existing artifacts first. Build on
  what's there, don't contradict it. Analyze mode produces the baseline.
  Subsequent passes AMEND existing artifacts — add new components,
  update contracts — don't replace the whole document.
- **Recommendation-first.** Present the design with reasoning. The user
  approves or redirects.
- **Write to disk.** Every decision goes into a design artifact. The
  conversation dies; the files survive.
- **Contracts must be specific.** "The API returns user data" is not a
  contract. "GET /users/{id} returns {id: string, name: string, email:
  string}" is a contract.
