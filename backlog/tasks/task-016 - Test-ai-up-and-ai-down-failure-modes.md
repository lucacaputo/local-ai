---
id: TASK-016
title: Test ai-up and ai-down failure modes
status: To Do
assignee: []
created_date: '2026-10-18 22:01'
labels: []
milestone: m-2
dependencies: []
priority: medium
ordinal: 16000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
ai-up and ai-down were only exercised on clean starts and stops. A crashed router, a stale run\stack.json with dead pids, a port already taken or a second ai-up should leave the machine in a state the next ai-up or ai-down can fix, with no orphaned llama-server holding 23 GB of VRAM.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 ai-down after a killed router, a killed llama-swap, and a stale state file each ends with no stack process left and VRAM near idle
- [ ] #2 A second ai-up while the stack runs, and ai-up after a crash, either work or fail with a clear message and leave nothing half-started
- [ ] #3 Any script fix is made, and the cases and outcomes are recorded in doc-002
<!-- AC:END -->
