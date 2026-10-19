---
id: TASK-029
title: Acceptance run away from home
status: To Do
assignee: []
created_date: '2026-10-19 14:32'
labels: []
milestone: m-3
dependencies:
  - TASK-028
documentation:
  - backlog/docs/doc-002 - PRD-changes-and-implementation-log.md
priority: medium
ordinal: 29000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
The point of m-3 is that the user can set up and use the stack without being at the PC. This runs the whole flow from the Mac on a different network, as the milestone done-when describes.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 From the Mac on another network (for example a phone hotspot), with the PC on and the user logged in, a fresh client setup without a key succeeds without touching the PC
- [ ] #2 ai-remote up starts the stack; in Claude Code /model lists Claude and local models, a local and a Claude model answer, and the ts-demo multi-step edit completes with local-coder
- [ ] #3 ai-remote down stops the stack, and status then shows it down with VRAM near idle
- [ ] #4 Results are recorded in doc-002, and m-3 is ready for archiving with the user approval
<!-- AC:END -->
