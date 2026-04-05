# Real-World Validation: Multi-Session Autonomous Build

Research conducted 2026-04-05. Based on a real app built by Opus across
multiple sessions in phases — the first concrete test of our theorized
challenges.

## Context

The user built a multi-component app (gateway, otel-collector, audit-sink,
workflow tools) using Opus as the implementation agent. The build was done
in phases across different Claude Code sessions. Five bugs were found when
the first end-to-end test ran. The bug analysis and root-cause tracing were
done collaboratively between the user and the agent.

## The bugs

| Bug | Component boundary | Root cause |
|---|---|---|
| Workflow tool missing from gateway allowlist | workflow service -> gateway config | Constraint in config.go not read by later session |
| gzip compression mismatch | otel-collector -> audit-sink | Exporter configured gzip; receiver had no decompressor |
| `${VAR:-default}` syntax in OTel config | otel-collector internals | OTel collector uses custom env expansion, not POSIX |
| Gateway `http://` endpoint format | gateway -> otel SDK | Undocumented agentgateway Rust OTel SDK behavior |
| otlpEndpoint format wrong | gateway config | Same category as above |

## Bug taxonomy by discoverability

This is the actionable finding. Bugs fall into two categories based on
where the information needed to prevent them lives:

### Category 1 — In-codebase (preventable by investigation)

The allowlist bug and gzip mismatch. The constraint was sitting in a file
in this repository. An agent that read the right files before implementing
would have found it.

**What catches these:** Pre-implementation codebase investigation.
Bildhauer's bozzetto data-flow trace ("trace upstream: what produces;
downstream: what consumes") forces reading both ends of a connection.
Clippy's investigation phase reads actual files before changing anything.

### Category 2 — External (preventable only by running or reading upstream docs)

The OTel syntax and gateway endpoint format bugs. Nothing in this repository
reveals the constraint. It lives in OTel collector internals or the
agentgateway Rust SDK — external to the project.

**What catches these:** Integration tests that exercise the actual
components. No amount of codebase reading helps because the information
isn't in the codebase.

## Validated predictions from challenges.md

### "Tests will be insufficient for integration" — Confirmed exactly

The e2e test was the first time all integration hops were exercised in
sequence. Each component had been tested in isolation. The 3-hop path
(gateway -> otel-collector -> audit-sink -> DB) had no intermediate health
checks or integration tests.

### "Parallel agents make conflicting assumptions" — Confirmed in variant form

The build was sequential (phases across sessions), not parallel. But the
same problem occurred: each session built to spec without knowledge of
constraints established in prior sessions. **This problem doesn't require
parallelism — any multi-session build has it.**

### "Resuming after interruption loses velocity" — Reclassified

We framed this as a velocity problem (slow restarts). In practice, it's
a **correctness** problem. The next session doesn't just start slow — it
makes integration bugs because it lacks cross-component constraint
knowledge from prior sessions. The allowlist bug is the clearest example:
`workflow.get_contract` was added in one session; the config.go allowlist
was written in a much earlier session; the link between them died at the
session boundary.

### "Write design decisions to disk" mitigation — Confirmed

The allowlist invariant ("every new MCP tool must also be added to the
hardcoded allowlist in config.go") was never written to any file. It was
implicit knowledge that existed only in the session that wrote config.go.
If this had been persisted as a constraint file, the later session would
have found it.

## New insights (not in prior research)

### 1. Bildhauer's bozzetto is specifically effective for cross-component bugs

The bozzetto step demands: "trace the data flow in both directions —
upstream: what produces the data; downstream: what consumes it." For the
gzip mismatch, this would have required reading both the otel-collector
exporter config AND the audit-sink gRPC server registration. The bug is
visible at the boundary — neither file is wrong alone, but reading both
reveals the mismatch.

This is the first concrete evidence for WHERE Bildhauer fits in the
pipeline: as a **pre-phase gate during implementation**, not a
post-implementation review.

### 2. Clippy's investigation catches "embarrassing in hindsight" bugs

The allowlist bug is the canonical example. Before implementing
`workflow.get_contract`, a Clippy investigation phase would have read
config.go as part of mapping "how do tools get exposed through the
gateway?" The answer was in a file that was never read.

These are the bugs where the constraint was already in the codebase
and the agent just didn't look.

### 3. Integration tests must be per-connection, not per-phase

Our roadmap has integration as step 4 (separate from implementation).
The evidence says: write the integration test when you create the
cross-component connection, not after all components are done. If the
otel-collector -> audit-sink connection had been tested when it was
built, the gzip bug would have been caught immediately.

### 4. The meta-pattern

The agent is good at implementing components to spec in isolation. It is
bad at maintaining integration contracts across sessions when:
- the constraint lives in a different file/component from where the change
  is made
- the constraint is only discoverable by running the full stack
- continuous memory of "side effects of adding X" is required

## Implications for clawdance

### Principle placement (answers roadmap open question 3)

The approach is to absorb Bildhauer/Clippy principles into our own
pipeline, not plug them in as external tools. External integration remains
a noted alternative.

| Principle | Source | Where it fits | What it catches |
|---|---|---|---|
| Data-flow boundary trace | Bildhauer bozzetto | Pre-phase gate in step 3 | Cross-component data flow mismatches (Category 1) |
| Pre-implementation investigation | Clippy V1 | Pre-phase investigation in step 3 | Existing constraints the agent would otherwise miss (Category 1) |
| Per-connection integration tests | This analysis | During step 3, when connection is created | Runtime/external behavior bugs (Category 2) |
| Convergent audit loop | clawdance research | Post-integration in step 4 | Cross-codebase issues that survive individual component testing |

### Roadmap adjustments needed

1. Step 3 (implementation) should include per-connection integration
   testing, not defer all integration to step 4.
2. Step 4 (integration) remains for full-codebase integration testing and
   semantic conflict detection, but is no longer the first time integration
   is tested.
3. Bildhauer/Clippy principles built directly into step 3 as pre-phase
   gates. Moved from "deferred" (roadmap item D) to core pipeline (item A).

### Contract files are necessary but not sufficient

Our mitigation table says "Define contracts as actual files BEFORE spawning
parallel workers." The real-world data confirms this prevents semantic
conflicts. But it also shows that implicit invariants (like "every tool
needs an allowlist entry") are just as dangerous as missing API contracts.
Contract files need to include operational invariants, not just API schemas.

## Scoring

Roughly half the bugs (2 of 4-5) were catchable by pre-implementation
investigation. The other half required running the actual stack. This
suggests equal investment in both approaches — neither alone is sufficient.
