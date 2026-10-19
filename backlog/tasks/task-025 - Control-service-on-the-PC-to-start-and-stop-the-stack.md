---
id: TASK-025
title: Control service on the PC to start and stop the stack
status: To Do
assignee: []
created_date: '2026-10-19 14:31'
labels: []
milestone: m-3
dependencies:
  - TASK-022
references:
  - scripts/ai-up.ps1
  - scripts/ai-down.ps1
  - scripts/lib/stack.ps1
priority: high
ordinal: 25000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
When the user is away the stack is usually down, and ai-up can only be run on the PC. A small HTTP service reachable over the tailnet lets the user start and stop it remotely. It must only run ai-up and ai-down on request, so the AI stack still never runs unless asked (PRD F4, user decision 2026-10-19), and it uses the same identity check as the router. In this task it is started by hand; starting it at logon is a separate task.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 status, up and down endpoints on a loopback port: status reports whether the stack is up and the VRAM in use, up runs ai-up (game guard included) and returns its message, down runs ai-down
- [ ] #2 Requests from a login not on the allowlist or without identity get 401, and nothing else is exposed: no other commands and no parameters passed through to the scripts
- [ ] #3 Overlapping up and down requests are serialised: a request that arrives while another runs gets a clear busy answer
- [ ] #4 The service holds no GPU memory, and every request is logged with its login and outcome under D:\local-ai\logs
- [ ] #5 Tested from the Mac through the tailnet: up from a stopped stack, status, down with VRAM back at idle, and up refused by the game guard (stand-in process)
<!-- AC:END -->
