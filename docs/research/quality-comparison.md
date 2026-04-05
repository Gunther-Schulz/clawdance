# Quality Enforcement Comparison

Research conducted 2026-04-05. Compared OMC's quality enforcement against
our Bildhauer and Clippy plugins.

## Summary

OMC, Bildhauer, and Clippy solve different quality problems:

- **OMC** — Output quality at scale. Many agents reviewing from different
  angles (security, code quality, completion). Strength: parallel coverage.
- **Bildhauer** — Thinking quality through coherence. Forces the developer
  (human or AI) to step back and check that all parts relate to the whole.
  Strength: catches structural problems before they're built.
- **Clippy** — Evidence quality through investigation. Forces proof that the
  AI actually understands the codebase before it changes anything.
  Strength: prevents wrong assumptions from becoming code.

## Comparison table

| Dimension | Bildhauer | Clippy | OMC |
|---|---|---|---|
| What it enforces | Thinking quality, coherence | Evidence quality, completeness | Output quality, coverage |
| How it enforces | Checkpoints at transitions | Structural gates with blocking logic | Agent role separation |
| When problems caught | Before starting (bozzetto) | During investigation (V1) | After implementation (review) |
| User control | At transitions | Every cycle | Minimal (ralph runs autonomously) |
| Evidence standard | Verification block (3 items) | V1: 2-3+ components, 8-item lifecycle | Fresh test output + LSP |
| Scalability | 1 agent | 1 agent (4 skills) | 19 agents in parallel |

## What OMC has that we don't

- 19-agent parallelism with role separation (no self-approval)
- Autonomous execution (ralph runs for hours without human)
- Team mode (concurrent agents in worktrees)
- Notification routing (clawhip integration)
- Systematic anti-slop cleanup (4-pass ai-slop-cleaner)
- Severity calibration with realist pressure-testing

## What we have that OMC doesn't

### From Bildhauer
- **Verification block:** 3 unverified assumptions, the most structurally
  different unexplored alternative, what the output looks like if the
  framing is wrong. Forces genuine self-challenge, not just review.
- **Coarse-to-fine discipline:** Cover the whole piece at each resolution
  level before going deeper on any part.
- **Bump vs jaw distinction:** Is this a local fix or a structural problem?
  Check before acting.
- **Living documentation with maintained dependencies** between 5 docs.

### From Clippy
- **V1 evidence standard:** grep = discovery (where to look), read_file =
  verification (actual proof), 2-3+ components to prove a pattern is
  systemic. Prevents conclusions from insufficient evidence.
- **8-item lifecycle checklist** per implementation step: invocation
  pattern, required data, component access, execution sequence, success
  response, failure response, state changes, data organization.
- **Structural gates with menu-based forcing functions** that block
  advancement until criteria are met (not advisory — blocking).
- **12 documented AI behavioral failure modes** with specific compensating
  mechanisms (P1-P12).
- **Investigation before implementation** with expected 2-5+ cycles.

## Complementary, not competing

OMC coordinates many agents working simultaneously. Bildhauer/Clippy make
each agent think better. The ideal flow uses OMC's orchestration with
Bildhauer/Clippy's quality discipline embedded in the agents.

Integration approaches (not yet decided):
- A) Replace OMC's reviewer agents with enhanced versions
- B) Add quality checkpoints as additional pipeline stages
- C) Run alongside OMC as separate plugins (loose coupling)
