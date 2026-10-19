---
id: TASK-017
title: Test router key rotation on the PC and the Mac
status: Done
assignee:
  - '@claude'
created_date: '2026-10-18 22:01'
updated_date: '2026-10-19 14:15'
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
- [x] #1 init-secrets -Rotate on the PC plus an ai-up makes the old key return 401 and the new one 200
- [x] #2 setup-client.sh on the Mac updates the Keychain item and claude-local.sh works again with no leftover old key
- [x] #3 The exact steps that worked are written in docs/remote-client-macos.md or the README
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
1. PC, one PowerShell process (D:\local-ai\scratch\rot\rotate.ps1, outside the repo): ai-up; old key gives 200; init-secrets -Rotate; the running router still takes the old key until restarted; ai-down + ai-up; old key gives 401 and new key 200 on loopback and on the tailnet address; claude-local.ps1 -p on local-coder answers. Keys stay in memory; only status codes and an 8-character SHA-256 prefix are printed. Credential Manager still holds one local-ai/router-key item.
2. Mac, by the user: git pull (also brings the TASK-020 picker row); claude-local.sh fails with the old key (401); copy-router-key.ps1 on the PC, setup-client.sh on the Mac; claude-local.sh works (Local Coder and Local Coder Q6 answer); exactly one local-ai/router-key Keychain item.
3. Write the steps that worked into docs/remote-client-macos.md (rotation section) and point the README at it.
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
PC (D:\local-ai\scratch\rot\rotate.ps1, keys only in memory, printed as SHA-256 prefixes): old 54fc3c6c gave 200 loopback and tailnet; after init-secrets -Rotate the new key 46b1b607 (57 chars) was stored, the running router still took the old key (200) and refused the new one (401); after ai-down + ai-up old 401 and new 200 on both addresses; claude-local.ps1 answered on local-coder and local-coder-q6; one Credential Manager item. My test script stopped at the claude-local step because it set ErrorActionPreference Stop (Claude Code stderr notice), rerun without it. Mac (user): git pull, claude-local.sh failed with 401 before the update, setup-client.sh with the key from copy-router-key.ps1, claude-local.sh works and /model lists Local Coder Q6 which answers; Keychain: one item, account lucacaputo (the first check, grep -c on dump-keychain, printed 2 because label and service both match one item; the procedure now uses a per-item awk check).
<!-- SECTION:NOTES:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
Key rotation tested end to end. On the PC, init-secrets -Rotate plus an ai-down/ai-up makes the old key get 401 and the new one 200 on loopback and on the tailnet; a router that is not restarted keeps accepting the old key, which the procedure now says. On the Mac, the old key fails with 401 until setup-client.sh stores the new one; then claude-local.sh works and the Keychain holds a single item. The exact steps, with a correct duplicate check (grep -c counts one item twice), are in docs/remote-client-macos.md under Rotating the key; the README security notes point there and list the rotation as tested; doc-002 has the record. Keys never appeared on screen or in a file during the test.
<!-- SECTION:FINAL_SUMMARY:END -->
