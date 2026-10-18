---
id: TASK-004
title: 'Spike S2: single /model list and PC client config'
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
type: spike
ordinal: 4000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
The user switches models through `/model` and wants Claude and local models in one list with friendly names (PRD F1, F2, R2). Claude Code must also know the real local context window (64K) or auto-compaction will fire too late and requests will fail. The working client setup becomes the committed PC config, so it must not hold secrets. Fallback F2: `ANTHROPIC_CUSTOM_MODEL_OPTION` plus an explicit compaction threshold.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 `/model` on the PC lists real Claude models plus `local-coder` and `local-light` with readable labels
- [ ] #2 Selecting each listed model works, including session-only switching
- [ ] #3 Context window Claude Code assumes for local models matches the server (64K), and auto-compaction triggers before the limit in a long session
- [ ] #4 Chosen mechanism (discovery vs custom entries) and labels are recorded (O5); if F2 was needed, that is recorded
- [ ] #5 A secret-free PC client config template (`settings.json` / env) is committed, with the local key referenced from the secret store
<!-- AC:END -->
