---
id: TASK-006
title: Secret storage and injection for the router
status: To Do
assignee: []
created_date: '2026-10-18 14:13'
labels: []
milestone: m-0
dependencies:
  - TASK-001
  - TASK-003
documentation:
  - backlog/docs/doc-0001-PRD.md
priority: high
type: task
ordinal: 6000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
The router master key and the client local key must never sit in plaintext in the repo or on disk (PRD F6, R7). They are injected into process environments at start from the secret store chosen in the inventory task.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 Router master key and client local key live only in the chosen secret store
- [ ] #2 A helper starts LiteLLM with secrets injected into its environment
- [ ] #3 Claude Code on the PC gets the local key from the secret store, not from a plaintext file
- [ ] #4 A search of the repo and config files finds no secret values
<!-- AC:END -->
