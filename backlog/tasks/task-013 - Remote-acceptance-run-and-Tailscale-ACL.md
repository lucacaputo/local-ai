---
id: TASK-013
title: Remote acceptance run and Tailscale ACL
status: To Do
assignee: []
created_date: '2026-10-18 21:00'
labels: []
milestone: m-1
dependencies:
  - TASK-011
  - TASK-012
priority: high
ordinal: 13000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
The MVP only tested from the PC itself. The PRD acceptance criteria require /model and both model families to work from a remote tailnet device, and the Tailscale ACL should limit the router port to the users own devices (carry-over from the MVP run).
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 From the second device, /model lists Claude models plus Local Coder and Local Light, and a prompt works on local-coder and on a Claude model with the subscription login
- [ ] #2 A multi-step edit task completes from the second device with local-coder
- [ ] #3 Tailscale ACL restricts port 4000 on the PC to the users own devices, and the policy is recorded in doc-002
- [ ] #4 ai-down makes the router unreachable from the second device
<!-- AC:END -->
