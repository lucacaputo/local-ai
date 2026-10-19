---
id: TASK-030
title: claude-local.sh offers to start the stack when it is down
status: To Do
assignee: []
created_date: '2026-10-19 14:32'
labels: []
dependencies:
  - TASK-027
references:
  - scripts/mac/claude-local.sh
priority: low
ordinal: 30000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
With ai-remote, starting a session away from home takes two commands. claude-local.sh could notice that the router does not answer and offer to start the stack. Deferred by the user on 2026-10-19 until after m-3, to be built only if the two-step flow turns out to be a nuisance.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 When the router does not answer, claude-local.sh says so and asks before starting the stack, and never starts it without a yes
- [ ] #2 When the stack is up, claude-local.sh behaves as before
<!-- AC:END -->
