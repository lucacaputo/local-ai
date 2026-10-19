---
id: TASK-024
title: Mac client without the router key
status: In Progress
assignee:
  - '@claude'
created_date: '2026-10-19 14:31'
updated_date: '2026-10-19 15:21'
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

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
1. scripts/mac/setup-client.sh: takes only the router URL, refuses an IP host (HTTP-mode serve answers on the MagicDNS name only), saves the URL, deletes every local-ai/router-key Keychain item left by the key-based setup, and checks the router with the marker header (200 accepted, 401 login not allowlisted, 000/404/502 not reachable or stack down).
2. scripts/mac/claude-local.sh: no Keychain read; sends x-litellm-api-key: tailscale-identity (non-secret marker, TASK-023) and keeps unsetting ANTHROPIC_API_KEY/AUTH_TOKEN.
3. docs/remote-client-macos.md: key-free one-time setup, troubleshooting by status code, rotation section reduced to the PC steps (the Mac no longer holds the key).
4. Tests: bash -n; both scripts from WSL as a stand-in client (stub security command, temporary HOME; WSL reaches the tailnet through Windows); then the user on the Mac: git pull, setup-client.sh with the MagicDNS URL (removes the Keychain item), claude-local.sh with /model, a local and a Claude model; claude-local.ps1 on the PC with the key.
<!-- SECTION:PLAN:END -->
