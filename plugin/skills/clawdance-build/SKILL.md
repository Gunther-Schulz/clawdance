---
name: clawdance-build
description: Full autonomous build — decompose design artifacts and build without human checkpoint. Combines /clawdance-decompose and /clawdance resume in one shot.
argument-hint: "[path to design/ directory, default: design/]"
---

# clawdance-build — Full Auto Mode

Decompose design artifacts into a task graph AND start building immediately.
No human review of the task graph. Use this when you trust the decomposer
and want fully autonomous execution.

For the step-by-step flow with a human checkpoint, use `/clawdance-decompose`
followed by `/clawdance resume` after reviewing the task graph.

## Steps

1. Run `/clawdance-decompose` on the specified design directory.
   If the decomposer reports gaps (missing contracts, concerns), stop and
   report them. Do not proceed with an incomplete task graph.

2. If decomposition succeeded, immediately run `/clawdance resume` to start
   building.
