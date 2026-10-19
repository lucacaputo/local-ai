---
id: TASK-023
title: Router accepts allowlisted Tailscale identities instead of the key
status: To Do
assignee: []
created_date: '2026-10-19 14:31'
labels: []
milestone: m-3
dependencies:
  - TASK-022
references:
  - config/custom_auth.py
  - config/litellm.yaml
  - scripts/ai-up.ps1
  - scripts/ai-down.ps1
priority: high
ordinal: 23000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
m-3 replaces the shared router key for remote devices with the Tailscale identity (user decision 2026-10-19: the Tailscale login is the credential for remote devices). The router authenticates in config/custom_auth.py (TASK-011: constant-time key comparison, 401 otherwise). Programs on the PC can reach the loopback port and could set identity headers themselves; the user accepted that, since a program running as the user can already read the key from Credential Manager. Port and HTTP/HTTPS choices come from the spike.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 A request forwarded by tailscale serve from an allowlisted login is accepted without a router key, on a local and a Claude model
- [ ] #2 A request from a login not on the allowlist, or with neither identity nor key, gets 401; the key still works for calls made on the PC (claude-local.ps1)
- [ ] #3 The allowlist is configuration, not code, and holds no secret
- [ ] #4 ai-up publishes the router in the mode chosen in the spike and ai-down removes it; a second ai-up and ai-down after a killed router still behave as in TASK-016
<!-- AC:END -->
