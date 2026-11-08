---
id: TASK-043
title: 'Spike: Google tools for OpenClaw and the per-install Google app'
status: To Do
assignee: []
created_date: '2026-11-08 17:43'
labels: []
milestone: m-5
dependencies:
  - TASK-041
references:
  - 'https://github.com/taylorwilsdon/google_workspace_mcp'
  - 'https://support.google.com/cloud/answer/7454865'
documentation:
  - backlog/docs/doc-003 - PRD-Local-agent-for-non-coders.md
  - backlog/docs/doc-004 - Agent-stack-changes-and-decisions.md
priority: medium
type: spike
ordinal: 43000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
B1, B2 and B4 need Gmail, Calendar, Drive, Docs and Sheets through the user's own consent (doc-003 AF4). OpenClaw's docs do not mention MCP; the candidates are an OpenClaw plugin or skill, or the workspace-mcp server (multi-user OAuth 2.1), which needs MCP support. D1 also rests on secondary sources (doc-003 P4): that an External Google app, in production and unverified, keeps working past 7 days with restricted Gmail scopes. This spike picks the tool route and tests D1 with the owner's account.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 The ways to give OpenClaw Google tools are listed with how each handles per-user OAuth, scopes and stored tokens, and at least two are tried
- [ ] #2 A Google Cloud project with an External, unverified OAuth app in production exists for the home install, and its setup steps are written down for the install docs
- [ ] #3 With the owner's consent the agent reads mail, creates a draft, reads the calendar, and edits a Sheet and a Doc through the chosen route
- [ ] #4 The token still works more than 7 days after consent, or the failure and the fallback (non-domain users use Google through the sandbox browser) are recorded
- [ ] #5 The choice is recorded in doc-004 with a decision record, including whether users consent twice (sign-in in m-6, and the tools)
<!-- AC:END -->
