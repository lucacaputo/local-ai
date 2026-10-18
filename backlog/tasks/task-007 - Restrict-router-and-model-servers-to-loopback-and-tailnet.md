---
id: TASK-007
title: Restrict router and model servers to loopback and tailnet
status: To Do
assignee: []
created_date: '2026-10-18 14:13'
labels: []
milestone: m-0
dependencies:
  - TASK-005
documentation:
  - backlog/docs/doc-0001-PRD.md
priority: high
type: task
ordinal: 7000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Nothing may be reachable from the LAN or the internet (PRD N2, R5). The router must still be reachable over Tailscale for remote devices in a later milestone, so it binds to the Tailscale interface address and loopback, while llama-swap and llama-server stay loopback-only.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 LiteLLM listens only on 127.0.0.1 and the Tailscale interface address
- [ ] #2 llama-swap and llama-server listen only on 127.0.0.1
- [ ] #3 A Windows Firewall inbound rule for the router port is scoped to the Tailscale interface
- [ ] #4 `netstat` output confirming the listeners is recorded
<!-- AC:END -->
