---
id: TASK-017
title: Test router key rotation on the PC and the Mac
status: To Do
assignee: []
created_date: '2026-10-18 22:01'
labels: []
milestone: m-2
dependencies: []
priority: medium
ordinal: 17000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
The key is shared between the router and every client (decision-005), so a leaked key means rotating it on the PC and each device. The procedure is written down in docs/remote-client-macos.md but has never been run.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 init-secrets -Rotate on the PC plus an ai-up makes the old key return 401 and the new one 200
- [ ] #2 setup-client.sh on the Mac updates the Keychain item and claude-local.sh works again with no leftover old key
- [ ] #3 The exact steps that worked are written in docs/remote-client-macos.md or the README
<!-- AC:END -->
