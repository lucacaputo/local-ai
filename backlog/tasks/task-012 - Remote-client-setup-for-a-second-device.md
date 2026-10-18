---
id: TASK-012
title: Remote client setup for a second device
status: In Progress
assignee:
  - '@claude'
created_date: '2026-10-18 21:00'
updated_date: '2026-10-18 21:09'
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
- [x] #1 Documented and scripted client setup for a second device: ANTHROPIC_BASE_URL on the tailnet address, x-litellm-api-key header, Claude Code settings with the same Local Coder and Local Light rows, no ANTHROPIC_AUTH_TOKEN or ANTHROPIC_API_KEY
- [ ] #2 The router key on the device lives in an OS secret store, not in a plaintext file or the repo
- [ ] #3 The setup works on the device types the user actually has (confirmed with the user at start)
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
Device: Mac laptop (user confirmed), Claude Code installed with the same subscription, Tailscale not yet installed.
1. scripts/mac/setup-client.sh: stores the router URL (non-secret, ~/.config/local-ai/router-url) and the router key in the macOS Keychain; the key is entered at security's own hidden prompt, never as an argument or file.
2. scripts/mac/claude-local.sh: reads URL and key, sets ANTHROPIC_BASE_URL and ANTHROPIC_CUSTOM_HEADERS for the claude child only, unsets ANTHROPIC_API_KEY/ANTHROPIC_AUTH_TOKEN for it, passes --settings config/claude-settings.json (same Local Coder / Local Light rows and 128K window as the PC).
3. scripts/copy-router-key.ps1 on the PC: puts the key on the clipboard without printing it and clears it after 60 s, so it can be pasted into the Keychain prompt.
4. docs/remote-client-macos.md: Tailscale on the Mac, finding the PC address, key transfer, setup, launch, troubleshooting.
5. Verify scripts here with bash -n and stubbed security/claude; the real run on the Mac is the user's step (AC 3), after which TASK-013 does the acceptance run.
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
Built for a Mac (user confirmed; Claude Code installed with the subscription, Tailscale not yet installed). Files: scripts/mac/setup-client.sh, scripts/mac/claude-local.sh, scripts/copy-router-key.ps1 (PC), docs/remote-client-macos.md. Checked here: bash -n; both Mac scripts against stubbed security/claude (bad URL rejected with rc 2, URL file written, key requested through security's own prompt not as an argument, launcher sets ANTHROPIC_BASE_URL and the x-litellm-api-key header and removes ANTHROPIC_API_KEY/ANTHROPIC_AUTH_TOKEN for the child, missing URL gives rc 1); copy-router-key.ps1 on the PC (clipboard held the 57-char key, then 0 chars after 60 s, key never printed). Not yet checked: the real Keychain and Tailscale on the Mac. AC 2 and 3 wait for the user to run the setup on the Mac.
<!-- SECTION:NOTES:END -->
