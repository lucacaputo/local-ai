---
id: TASK-027
title: ai-remote command on the Mac
status: In Progress
assignee:
  - '@claude'
created_date: '2026-10-19 14:31'
updated_date: '2026-10-19 22:00'
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

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
1. scripts/mac/ai-remote.sh status|up|down: curl to <router-url>/control/<cmd> (URL from LOCAL_AI_ROUTER or ~/.config/local-ai/router-url, as claude-local.sh), no key. The JSON answer is rendered as text by osascript -l JavaScript (on every Mac; no jq or python needed). bash 3.2 compatible.
2. Messages: transport errors by curl exit code (6: Tailscale off on the Mac; connect timeout: PC asleep/off or Tailscale off there; 7: cannot connect), tailscale serve answers (404: /control not published; 502: control service not running), service answers (401 not authorised plus advice, 409 busy, 422 with the ai-up/ai-down message, e.g. the game guard; 200 up already running: the PC's 'Nothing started' line). The PC-side usage hint 'Use: scripts\claude-local.ps1' is not shown; a successful up points to claude-local.sh. Exit status: 0 done, 1 refused or failed, 2 usage/config, 3 PC unreachable.
3. ai-up.ps1 guard message: drop 'use -Force' as the only way out (not available remotely); say to free the GPU, and that -Force works at the PC.
4. setup-client.sh: when the router does not answer, point to ai-remote.sh up.
5. docs/remote-client-macos.md: usage, prerequisites (PC on, user logged in, install-control.ps1 once), message meanings.
6. Tests from WSL through the tailnet name (same identity as the Mac), osascript replaced by a node stand-in: status/up/up again/down, game guard, 409, 401 via allowed-logins.txt, 502 with the service stopped, 404 with /control removed, transport errors (unresolvable name, closed port, unroutable address); then the user on the Mac.
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
Built scripts/mac/ai-remote.sh status|up|down (bash 3.2 compatible; JSON rendered by osascript -l JavaScript; URL from LOCAL_AI_ROUTER or ~/.config/local-ai/router-url). Found while testing: the control service took only the first stderr line of a failed script, and powershell -File prints a throw as an error record wrapped at the console width (120 columns), so the longer guard message came back cut ('... -Force starts'); the old one fit by luck. control-service.py now runs the scripts through a try/catch wrapper that writes the exception message as one line (last stderr line kept). ai-up guard message: 'Close the game or free the GPU, then try again (at the PC, -Force starts anyway).' setup-client.sh points to ai-remote.sh when the router does not answer. Tests from WSL through the tailnet name (same identity as the Mac), osascript replaced by a node stand-in: status down; up (Stack healthy in 13.6 s, PC hint line hidden, claude-local.sh hint shown); up again (already running, Nothing started); status up; down; game guard with the fake game: 422 with the whole message, also in control.log; second up during an up: busy, and status meanwhile showed partly running, Running now: ai-up; ai-up refusing with a port taken: whole message; service stopped: 502 message; /control removed with the stack up: 404 message; /control removed with the stack down: connection times out (firewall drop), same as a PC that is off, so that message names the missing install too; allowed-logins.txt with another login: 401 after 20 s, file removed: 200 within 60 s; unresolvable name: exit 3 (rc 6 message); closed port: rc 7 message; unroutable address: timeout message after 10 s; no URL and bad command: exit 2. State after tests: stack down, service running, /control published, no allowed-logins.txt, fake game and port holder stopped. Pending: run on the Mac (real osascript and bash 3.2).
<!-- SECTION:NOTES:END -->
