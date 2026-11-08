---
id: TASK-042
title: Sandbox network isolation and a router credential limited to the local models
status: To Do
assignee: []
created_date: '2026-11-08 17:43'
labels: []
milestone: m-5
dependencies:
  - TASK-041
documentation:
  - backlog/docs/doc-003 - PRD-Local-agent-for-non-coders.md
  - backlog/docs/doc-004 - Agent-stack-changes-and-decisions.md
priority: high
type: task
ordinal: 42000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Anything inside a sandbox can be read or run by the agent, and a web page or an email can try to steer it (doc-003 AN4, AN8). Docker Desktop exposes the host to containers as host.docker.internal, so by default a sandbox can reach the control service, llama-swap and devices on the LAN. If it held the router key it could also call Claude models, which the agent must never do (local only, and they cost money). decision-011 leaves the design open: an internal network plus an egress proxy, or firewall rules.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 From inside a sandbox the internet and the router are reachable, and llama-swap, the control service, other host ports and LAN addresses are not; tests show both
- [ ] #2 A sandbox holds its own router credential, not the router key; with it the local models answer and Claude models are refused
- [ ] #3 Revoking a sandbox credential stops that sandbox only, and no credential is written to the repo or logged in plain text
- [ ] #4 The design and its tests are recorded in doc-004, with a decision record
<!-- AC:END -->
