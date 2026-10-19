---
id: TASK-028
title: 'Docs, decisions and exposure check for m-3'
status: To Do
assignee: []
created_date: '2026-10-19 14:31'
labels: []
milestone: m-3
dependencies:
  - TASK-023
  - TASK-024
  - TASK-025
  - TASK-026
  - TASK-027
references:
  - README.md
  - docs/remote-client-macos.md
documentation:
  - backlog/docs/doc-002 - PRD-changes-and-implementation-log.md
priority: medium
ordinal: 28000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
m-3 changes two recorded decisions: decision-005 (one shared key for the router and every client) and decision-006 (router published with tailscale serve in TCP mode, everything bound to loopback). The README security notes, the Mac guide and doc-002 describe the old model, and the tailnet gains a second port. The backlog CLI (1.54.0) can only set a decision title and status, not its body.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 A new decision records identity-based auth and the control service, and the statuses of decision-005 and decision-006 point to it
- [ ] #2 The README (usage, security notes, troubleshooting) and doc-002 describe the final m-3 setup
- [ ] #3 Listener check with the stack up and down: only the router and control ports are reachable on the tailnet, and nothing new listens on the LAN address (as in TASK-014)
- [ ] #4 Secret scan of the worktree and git history is clean
<!-- AC:END -->
