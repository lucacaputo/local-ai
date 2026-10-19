---
id: TASK-024
title: Mac client without the router key
status: Done
assignee:
  - '@claude'
created_date: '2026-10-19 14:31'
updated_date: '2026-10-19 15:47'
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
- [x] #1 setup-client.sh asks only for the router URL and removes a leftover local-ai/router-key Keychain item if one exists
- [x] #2 claude-local.sh works on the Mac with no key stored: /model lists the Claude models and the local entries, and a local and a Claude model answer
- [x] #3 claude-local.ps1 on the PC still works with the key
- [x] #4 docs/remote-client-macos.md describes the key-free setup, and copying the key is no longer part of it
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
1. scripts/mac/setup-client.sh: takes only the router URL, refuses an IP host (HTTP-mode serve answers on the MagicDNS name only), saves the URL, deletes every local-ai/router-key Keychain item left by the key-based setup, and checks the router with the marker header (200 accepted, 401 login not allowlisted, 000/404/502 not reachable or stack down).
2. scripts/mac/claude-local.sh: no Keychain read; sends x-litellm-api-key: tailscale-identity (non-secret marker, TASK-023) and keeps unsetting ANTHROPIC_API_KEY/AUTH_TOKEN.
3. docs/remote-client-macos.md: key-free one-time setup, troubleshooting by status code, rotation section reduced to the PC steps (the Mac no longer holds the key).
4. Tests: bash -n; both scripts from WSL as a stand-in client (stub security command, temporary HOME; WSL reaches the tailnet through Windows); then the user on the Mac: git pull, setup-client.sh with the MagicDNS URL (removes the Keychain item), claude-local.sh with /model, a local and a Claude model; claude-local.ps1 on the PC with the key.
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
Tests. WSL as a stand-in client (stub security command, XDG_CONFIG_HOME in the scratchpad): IP URL refused (exit 2), malformed URL shows usage, stack down gives the no-answer message and still saves the URL and removes the Keychain item, stack up gives accepted; claude-local.sh with no key answered on local-coder, sonnet and local-coder-q6. PC: claude-local.ps1 with the key answered on local-coder and sonnet. Mac (user, after git pull of 5f3347f): setup-client.sh with the MagicDNS URL removed 1 Keychain item and reported the login accepted; the dump-keychain check prints nothing; claude-local.sh lists Local Coder, Local Light and Local Coder Q6 in /model, and a local and a Claude model answer. Both Mac scripts are now 100755 in git. scripts\copy-router-key.ps1 is no longer needed by any client; the README still mentions it (TASK-028).
<!-- SECTION:NOTES:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
The Mac now needs no router key. setup-client.sh takes only the router URL (it refuses an IP, since HTTP-mode serve answers on the MagicDNS name only), removes any key left in the Keychain by the old setup, and reports at once whether the router accepts the Mac Tailscale login or the stack is down. claude-local.sh sends the non-secret marker header instead of the key. The PC keeps using the key. docs/remote-client-macos.md describes the key-free setup (nothing to do on the PC, so it works away from home), troubleshooting by status code, and key rotation as a PC-only job. Verified from WSL as a stand-in client and by the user on the Mac: old Keychain item removed, none left, all local entries listed and both a local and a Claude model answer. Follow-up for TASK-028: copy-router-key.ps1 is unused now and the README still describes the key on the Mac.
<!-- SECTION:FINAL_SUMMARY:END -->
