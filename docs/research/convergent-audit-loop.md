# Convergent Audit Loop

Research conducted 2026-04-05. Pattern for autonomous iterative code auditing
with diminishing returns detection.

## Problem

A single AI audit pass never finds everything. The AI has attention limits,
context constraints, and biases toward certain kinds of findings. With a
human in the loop (e.g., Clippy's menu system), the human forces successive
passes by saying "look again." Each pass finds more.

For autonomous operation, we need to replace the human forcing function with
an orchestrator that decides when to push for more and when to stop.

## Architecture: Orchestrator + Worker

The orchestrator spawns a worker agent and drives it through successive
audit passes. From the worker's perspective, this is indistinguishable from
a human prompting it — it receives messages and continues working.

### Flow

1. Orchestrator spawns worker: "audit this codebase"
2. Worker does a pass, reports findings, thinks it's done
3. Orchestrator receives findings, analyzes them, uses SendMessage to
   continue the same session: "These areas were underexplored: [X, Y].
   Do another pass focusing there. Don't repeat these known findings: [...]"
4. Worker continues in the same session — full context of what it already
   found, plus new direction
5. Orchestrator compares new findings against previous. Still novel?
   SendMessage again. Diminishing returns? Stop.

### Why SendMessage in the same session

- Worker accumulates understanding of the codebase across passes
- Won't rediscover the same things (it remembers)
- Orchestrator's "focus on X next" is informed by gaps
- From the worker's perspective, identical to a human saying "look again"

### When to use same session vs fresh session

**Same session (depth — building cumulative understanding):**
- Targeted narrowing: "now check error handling," "now check API contracts"
- Agent builds connections between findings across passes
- Following up on something suspicious from a previous pass
- Context window has room

**Fresh session (breadth — new eyes):**
- Current session's perspective is exhausted (same-session passes finding
  nothing new)
- Context window is getting full
- Want to eliminate anchoring bias — a fresh agent notices things the
  first agent walked past because it was focused elsewhere
- Different audit angle (security vs performance vs correctness)

The orchestrator decides which based on:
- Context window usage (getting full → fresh session)
- Finding novelty (stale → try fresh eyes before giving up)
- Phase transition (see audit strategy progression below)

## Audit strategy progression

### Phase A — Broad/flexible (fresh sessions)

"Audit this codebase." No constraints. Let the AI find whatever it finds.
Run 2-3 passes with fresh sessions so each has independent perspective.
Catches obvious stuff and reveals which areas have problems.

### Phase B — Targeted (same session, directed by orchestrator)

Based on Phase A findings, focus on specific areas via SendMessage:
- Performance hotspots
- Specific bug classes (null handling, error propagation, race conditions)
- Security patterns
- API contract consistency
- Cross-component data flow

Multiple directed passes within the same session. The agent's growing
familiarity with the codebase is an asset here.

### Phase C — Depth probes (same session or fresh, depends)

Things that targeted audits flagged as suspicious but didn't fully trace.
"This error handling pattern looks wrong in 3 places — check ALL call
sites." This is where Clippy's V1 evidence standard applies — grep to find
all instances, read to verify, 2-3+ components to confirm systemic.

Same session if the agent already has context. Fresh session if the
current context is saturated.

### Phase D — Test writing and test auditing

Two separate activities:

**Test writing:** Write tests for what the audit found. Regression
prevention. Each finding gets a test that would have caught it.

**Test auditing:** Audit the tests themselves for effectiveness:
- Do they actually test what they claim?
- Do they cover edge cases?
- Are mocks masking real problems? (e.g., mocked API doesn't match real
  API — this is the integration testing gap from challenges.md)
- Are assertions meaningful or just "does not throw"?

## Diminishing returns detection

The orchestrator tracks findings across passes:
- Each pass produces a structured list: file, line, category, severity
- Deduplicator compares against all previous findings
- Metrics: novel findings per pass, severity distribution of novel findings
- Stop conditions:
  - A pass produces 0 novel findings
  - A pass produces only LOW severity novel findings
  - N consecutive passes below threshold

Minimum passes before early exit is configurable (default: 3). No early
exit before the minimum — the agent doesn't get to decide it's done after
one pass.

## Integration with product workflow

- **During implementation (step 3):** Light version. Per-component audit as
  each component is built. 2-3 passes. Catches issues before integration.
- **After integration (step 4):** Thorough version. Full codebase audit with
  the complete progression (broad → targeted → depth probes). Catches
  cross-component issues.
- **During validation (step 5):** Requirements-focused audit. "Does the code
  actually implement what was specified?" Different audit angle.

## Escalation

Some audit findings require design changes, not implementation fixes. The
orchestrator must recognize when a finding loops back to product workflow
step 2 (design) rather than being fixable in step 3 (implementation).

Heuristic: if a finding affects the contract files, data model, or
component boundaries, it's a design issue. Flag for human review rather
than attempting autonomous fix.

## Open questions

1. How does the orchestrator agent itself get spawned? Is it a skill that
   the user invokes, or part of OMC's pipeline?

2. Should findings accumulate in a single file or one file per pass?
   Single file is easier to deduplicate but harder to track which pass
   found what. Suggest: one file per pass + a consolidated summary.

3. How does this interact with OMC's existing review agents (code-reviewer,
   security-reviewer, verifier)? Is this a replacement or a complement?
   Likely complement — OMC's reviewers run per-task during implementation,
   this runs across the whole codebase after integration.
