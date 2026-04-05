---
name: clawdance-design
description: Design phase skill — handles one aspect of design per invocation (architecture, stack, contracts, or validation). Called by the orchestrator iteratively at increasing resolution.
argument-hint: "<idea or focus area>"
---

# clawdance-design — Design Phase

You handle one focused aspect of design per invocation. Read what exists,
do your focused work, write results to `design/`. The orchestrator calls
you multiple times at increasing resolution.

## Detect focus

Based on what exists and what the orchestrator asked for:

| State | Focus |
|---|---|
| No `design/` at all + user idea provided | Architecture — full initial design |
| `design/DESIGN.md` exists, no `STACK.md` | Stack — tech stack and testing |
| `design/DESIGN.md` + `STACK.md` exist, contracts incomplete | Contracts — specific interface |
| All artifacts exist | Validate — coherence check |
| Orchestrator specified a focus | That specific focus |

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

Produce `design/DESIGN.md`:
- Components/services/modules and their responsibilities
- How components connect (which calls which, data flow direction)
- Dependencies between components (what must exist before what)
- Key architectural decisions with rationale

Present as a recommendation: "Here's the architecture I'd use. [reasoning]"
The user approves or redirects.

## Stack focus

Produce `design/STACK.md`:
- Languages, frameworks, libraries (with rationale)
- Database and schema management approach
- How to run unit tests
- How to run integration tests (docker compose, in-process, etc.)
- How to build and run the project

Read `design/DESIGN.md` first — the stack must serve the architecture.

## Contracts focus

For a specific inter-component interface, produce a contract file in
`design/contracts/`:
- API contracts: endpoints, methods, request/response shapes, error codes
- Data model contracts: schemas, shared types, field definitions
- Event contracts: message formats, topics, delivery guarantees

Read `design/DESIGN.md` to understand the interface. The contract must be
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
  orchestrator calls you multiple times.
- **Read before writing.** Always read existing artifacts first. Build on
  what's there, don't contradict it.
- **Recommendation-first.** Present your design with reasoning. The user
  approves or redirects.
- **Write to disk.** Every decision goes into a design artifact. The
  conversation dies; the files survive.
- **Contracts must be specific.** "The API returns user data" is not a
  contract. "GET /users/{id} returns {id: string, name: string, email:
  string}" is a contract.
