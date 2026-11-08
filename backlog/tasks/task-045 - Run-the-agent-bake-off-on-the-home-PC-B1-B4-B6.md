---
id: TASK-045
title: 'Run the agent bake-off on the home PC (B1-B4, B6)'
status: To Do
assignee: []
created_date: '2026-11-08 17:43'
labels: []
milestone: m-5
dependencies:
  - TASK-039
  - TASK-040
  - TASK-041
  - TASK-042
  - TASK-043
  - TASK-044
references:
  - 'https://docs.openclaw.ai/gateway/local-models'
documentation:
  - backlog/docs/doc-003 - PRD-Local-agent-for-non-coders.md
  - backlog/docs/doc-004 - Agent-stack-changes-and-decisions.md
priority: high
type: task
ordinal: 45000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
The acceptance of m-5: the local model completes the non-coder tasks inside OpenClaw. OpenClaw's docs warn that a model that answers short prompts can still fail agent turns, and advise narrow agents and compaction with local models, so tuning (tool list, lean mode, effort, window) happens here.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 B1-B4 and B6 run twice each in Italian and in English, in a fresh and in a used sandbox, on the 32 GB entry chosen in the vision spike
- [ ] #2 Every task passes and every run finishes in under 10 minutes; failures are analysed and the configuration changes that fixed them are recorded
- [ ] #3 Failed tool calls stay under 5% (the R4 gate of the coding stack)
- [ ] #4 Results, timings and the final OpenClaw configuration are recorded in doc-004
<!-- AC:END -->
