---
id: TASK-005
title: 'llama-swap with local-coder, local-light and idle unload'
status: To Do
assignee: []
created_date: '2026-10-18 14:13'
labels: []
milestone: m-0
dependencies:
  - TASK-003
documentation:
  - backlog/docs/doc-0001-PRD.md
priority: high
type: task
ordinal: 5000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
The GPU is shared with gaming, so model weights must load only when needed and leave VRAM after idle (PRD F5, N3). llama-swap also lets `local-light` exist as its own name, initially aliasing the coder, so a smaller model can be added later without client changes (O3).
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 `config/llama-swap.yaml` defines `local-coder` with the launch flags proven in the S3 spike, and `local-light` as an alias
- [ ] #2 llama-swap and llama-server bind to loopback only
- [ ] #3 LiteLLM routes `local-coder` and `local-light` through llama-swap, and both work from Claude Code
- [ ] #4 Model loads on first request and VRAM is released after the configured `ttl`; the measured unload is recorded
<!-- AC:END -->
