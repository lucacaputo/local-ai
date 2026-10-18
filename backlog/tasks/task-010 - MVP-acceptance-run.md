---
id: TASK-010
title: MVP acceptance run
status: To Do
assignee: []
created_date: '2026-10-18 14:13'
labels: []
milestone: m-0
dependencies:
  - TASK-004
  - TASK-009
documentation:
  - backlog/docs/doc-0001-PRD.md
priority: medium
type: task
ordinal: 10000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Milestone m-0 is done only when its "Done when" criteria hold on the real stack started by the scripts, not on the hand-built spike setup.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 Stack started with `ai-up` is healthy in under 2 minutes, and `ai-down` leaves VRAM near idle
- [ ] #2 `/model` on the PC lists Claude and local models, and each one completes a request
- [ ] #3 A multi-step edit task completes with `local-coder` with tool calls succeeding
- [ ] #4 Model unloads after the idle `ttl`
- [ ] #5 No secrets are present in the repo or in plaintext config
- [ ] #6 Pinned versions that passed are recorded (O10)
<!-- AC:END -->
