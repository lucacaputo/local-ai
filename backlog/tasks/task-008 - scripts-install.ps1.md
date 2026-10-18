---
id: TASK-008
title: scripts/install.ps1
status: To Do
assignee: []
created_date: '2026-10-18 14:13'
labels: []
milestone: m-0
dependencies:
  - TASK-005
  - TASK-003
documentation:
  - backlog/docs/doc-0001-PRD.md
priority: medium
type: task
ordinal: 8000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Setting up the stack by hand is error-prone and must be repeatable at the versions pinned in the inventory task (PRD deliverable 1, O10).
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 Script checks the NVIDIA driver/CUDA support and that Tailscale is installed, failing with a clear message otherwise
- [ ] #2 Script downloads the pinned llama.cpp CUDA build and llama-swap into a git-ignored location
- [ ] #3 Script creates the LiteLLM venv with `uv` at the pinned version
- [ ] #4 A second run is safe and makes no changes when everything is present
<!-- AC:END -->
