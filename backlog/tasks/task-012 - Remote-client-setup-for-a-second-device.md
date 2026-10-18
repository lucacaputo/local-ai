---
id: TASK-012
title: Remote client setup for a second device
status: To Do
assignee: []
created_date: '2026-10-18 21:00'
labels: []
milestone: m-1
dependencies: []
priority: high
ordinal: 12000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
F1 and F3 require the same /model list on the users other devices, not just the PC. The PC setup relies on scripts that read the router key from Windows Credential Manager, which a laptop does not have, so the remote path needs its own client config and a safe place for the key (F6).
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 Documented and scripted client setup for a second device: ANTHROPIC_BASE_URL on the tailnet address, x-litellm-api-key header, Claude Code settings with the same Local Coder and Local Light rows, no ANTHROPIC_AUTH_TOKEN or ANTHROPIC_API_KEY
- [ ] #2 The router key on the device lives in an OS secret store, not in a plaintext file or the repo
- [ ] #3 The setup works on the device types the user actually has (confirmed with the user at start)
<!-- AC:END -->
