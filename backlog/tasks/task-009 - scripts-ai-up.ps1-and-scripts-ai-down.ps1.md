---
id: TASK-009
title: scripts/ai-up.ps1 and scripts/ai-down.ps1
status: To Do
assignee: []
created_date: '2026-10-18 14:13'
labels: []
milestone: m-0
dependencies:
  - TASK-005
  - TASK-006
  - TASK-007
  - TASK-008
documentation:
  - backlog/docs/doc-0001-PRD.md
priority: high
type: task
ordinal: 9000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
The user games on the same PC and wants the stack running only when started on purpose: one command up, one down, no boot auto-start (PRD F4, N3, deliverable 4). Optional extras (game-detection guard, GPU power limit) are decided while writing these (O8).
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 `ai-up` starts llama-swap and LiteLLM with secrets injected and waits for health checks
- [ ] #2 `ai-up` reports healthy in under 2 minutes; the measured time is recorded
- [ ] #3 `ai-up` run while the stack is already up does not start duplicates
- [ ] #4 `ai-down` stops all stack processes and VRAM is near idle within seconds per `nvidia-smi`; before/after numbers are recorded
- [ ] #5 Nothing in the stack starts at boot
- [ ] #6 Decision on the game guard and power limit is recorded (O8)
<!-- AC:END -->
