---
id: TASK-044
title: 'Spike: enforce confirmations before risky actions'
status: To Do
assignee: []
created_date: '2026-11-08 17:43'
labels: []
milestone: m-5
dependencies:
  - TASK-040
  - TASK-041
  - TASK-043
documentation:
  - backlog/docs/doc-003 - PRD-Local-agent-for-non-coders.md
  - backlog/docs/doc-004 - Agent-stack-changes-and-decisions.md
priority: high
type: spike
ordinal: 44000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
doc-003 AF5 and AN8: sending, posting, buying, submitting forms, deleting, overwriting, sharing, changing account settings and logging in with stored credentials wait for the user's click, and text the agent read must not be able to skip that. OpenClaw documents exec approvals for host commands and ask_user for user decisions, but no hard gate for these actions (decision-010). The gate can live in OpenClaw's tool policy, in the Google tool layer, or on the browser path.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 OpenClaw exec approvals, ask_user and tool policy are tried, and for each risky action in AF5 it is recorded whether the model can skip the confirmation
- [ ] #2 Sending, deleting and sharing through the Google tools cannot happen without the user's click in the web interface, even when the model is told otherwise
- [ ] #3 A form submit and a purchase-style button on the fixture sites wait for the user's click, or the remaining gap is recorded with its risk
- [ ] #4 B6 passes
- [ ] #5 The design is recorded in doc-004 with a decision record
<!-- AC:END -->
