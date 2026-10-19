---
id: TASK-027
title: ai-remote command on the Mac
status: To Do
assignee: []
created_date: '2026-10-19 14:31'
labels: []
milestone: m-3
dependencies:
  - TASK-025
references:
  - scripts/mac/setup-client.sh
  - docs/remote-client-macos.md
priority: medium
ordinal: 27000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
The user needs one command on the Mac to check, start and stop the stack through the control service instead of being at the PC. Letting claude-local.sh start the stack by itself is a separate follow-up (user decision 2026-10-19).
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 scripts/mac/ai-remote.sh status|up|down calls the control service without a key and prints its answer
- [ ] #2 Clear messages for: stack already up, game guard refusal, not authorised, and PC unreachable (Tailscale off on either side, PC asleep or off, control service not running)
- [ ] #3 The control address comes from the configuration written by setup-client.sh, not from editing the script
- [ ] #4 Usage is documented in docs/remote-client-macos.md
<!-- AC:END -->
