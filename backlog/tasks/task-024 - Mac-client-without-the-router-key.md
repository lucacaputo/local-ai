---
id: TASK-024
title: Mac client without the router key
status: To Do
assignee: []
created_date: '2026-10-19 14:31'
labels: []
milestone: m-3
dependencies:
  - TASK-023
references:
  - scripts/mac/setup-client.sh
  - scripts/mac/claude-local.sh
  - docs/remote-client-macos.md
priority: medium
ordinal: 24000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
With identity-based auth, the Mac no longer needs the router key in its Keychain, so a new or wiped Mac can be set up away from home with only Tailscale and the router URL. Today setup-client.sh stores the URL and the key, and claude-local.sh sends the key in ANTHROPIC_CUSTOM_HEADERS. The PC launcher keeps using the key, because calls made on the PC carry no identity.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 setup-client.sh asks only for the router URL and removes a leftover local-ai/router-key Keychain item if one exists
- [ ] #2 claude-local.sh works on the Mac with no key stored: /model lists the Claude models and the local entries, and a local and a Claude model answer
- [ ] #3 claude-local.ps1 on the PC still works with the key
- [ ] #4 docs/remote-client-macos.md describes the key-free setup, and copying the key is no longer part of it
<!-- AC:END -->
